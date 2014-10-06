#!/usr/bin/env perl
use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Copy;
use POSIX qw/strftime/;
use Template::Alloy;

use LSF::Util qw/trim
                 createHTML 
                 createXML/;
use LSF::ConfigReader;
use LSF::Accounting;

sub defineColors
{
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $colorDict = $config->{plotcreator}{colorDict} || {};
  my %filter = map { $_ => 1 } values %$colorDict;  # already defined colors

  grep { not exists $filter{$_} }
    map { sprintf "#%s",
       join "", map { sprintf "%02x", rand(255) } (0..2)
    } (0..255);
}
sub main
{
  # Create the accounting object and collect all the information
  my $acctObj = LSF::Accounting->new;
  $acctObj->collect;

  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{accounting}{verbose} || 0;
  my $colorDict = $config->{plotcreator}{colorDict} || {};

  # We should update colorDict and extend to groups that are not defined in config.pl
  my @newColors = defineColors;

  # Create the Templating stuff
  my $tmplPeriodFile = $config->{accounting}{template_period};
  my $tmplFile       = $config->{accounting}{template_full};
  my $tt = Template::Alloy->new(
     EXPOSE_BLOCKS => 1,
     ABSOLUTE      => 1,
     INCLUDE_PATH  => qq|$config->{baseDir}/tmpl|,
     OUTPUT_PATH   => qq|$config->{baseDir}/html|
  );
  my $output_full = qq||;
  my $outref_full = \$output_full;

  my $site  = $config->{site} || 'Unknown';
  my $batch = $config->{batch};

  # Process header
  $tt->process_simple(qq|$tmplFile/header|, 
       {site => $site, batch => $batch}, $outref_full) or die $tt->error;
  $tt->process_simple(qq|$tmplPeriodFile/style|, {}, $outref_full) 
     or die $tt->error;
  $tt->process_simple(qq|$tmplFile/open_tabview|, 
       {site => $site, batch => $batch}, $outref_full) or die $tt->error;

  # Get hold of the configuration
  my $timeSlices = $config->{accounting}{timeSlices} || [];
  my $sortby_field = (defined $config->{accounting}{sortby_field})
         ? lc $config->{accounting}{sortby_field} : q|walltime|;

  # One day I should find a way to validate sortby_field automatically
  my @supportedFields = qw/
    jobs
    sjobs
    success_rate
    cores
    walltime 
    cputime
    cpueff
    walltime_share
    avgwait/;

  unless (grep { $_ eq $sortby_field } @supportedFields) {
    warn qq|Unsupported column $sortby_field! will use 'walltime'\n|;
    $sortby_field = q|walltime|;
  }

  my $lsfmon_version = $config->{lsfmon_version} || '2.0.0';
  my $lsfmon_doc     = $config->{lsfmon_doc} || q|http://sarkar.web.cern.ch/sarkar/doc/lsfmon.html|;
  # now loop over different periods
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    my $period_label = $el->{label}; # Full name

    my $output_period = qq||;
    my $outref_period = \$output_period;

    # header and style for individual periods
    $tt->process_simple(qq|$tmplPeriodFile/header|, 
        {site => $site, batch => $batch}, $outref_period) or die $tt->error;
    $tt->process_simple(qq|$tmplPeriodFile/style|, {}, $outref_period) 
       or die $tt->error;

    # Only for the overall -> start tab
    $tt->process_simple(qq|$tmplFile/open_tab|, 
        {tabid => $ptag}, $outref_full) or die $tt->error;     

    # Now the Table Header for both
    $tt->process_simple(qq|$tmplPeriodFile/table_header|, 
        {period => $period_label}, $outref_full) or die $tt->error;
    $tt->process_simple(qq|$tmplPeriodFile/table_header|, 
        {period => $period_label}, $outref_period) or die $tt->error;
    
    my $groupInfo = $acctObj->{acctinfo}{data}{$ptag};
    my @groupList = sort keys %$groupInfo;
    my $jview = {};
    for my $group ( sort { $groupInfo->{$b}{$sortby_field} 
                    <=> $groupInfo->{$a}{$sortby_field} } @groupList) 
    {
      $groupInfo->{$group}{jobs}>0 or next;
      $colorDict->{$group} = shift @newColors unless defined $colorDict->{$group};
      my $walltime = $groupInfo->{$group}{walltime};
      my $cputime  = $groupInfo->{$group}{cputime};
      my $avgwait  = $groupInfo->{$group}{avgwait};
      $cputime = (defined $cputime and $cputime) ? int($cputime) : 0;
      $avgwait = (defined $avgwait and $avgwait) ? int($avgwait) : 0;
      print join(" ", $ptag, $group, $walltime, $cputime, $groupInfo->{$group}{cpueff}), "\n" if $verbose;
      my ($succRate_fmt, $cpuEff_fmt, $timeShare_fmt) = map { trim $_ } (
        sprintf(qq|%6.2f|, $groupInfo->{$group}{success_rate}*100),
        sprintf(qq|%6.2f|, $groupInfo->{$group}{cpueff}),
        sprintf(qq|%6.2f|, $groupInfo->{$group}{walltime_share})
      );
      my $row = 
      {
                  color => $config->{plotcreator}{colorDict}{$group} || $config->{plotcreator}{defaultColor},
                  group => $group,
                   jobs => $groupInfo->{$group}{jobs},
                  sjobs => $groupInfo->{$group}{sjobs} || 0,
           success_rate => $succRate_fmt,
                  cores => $groupInfo->{$group}{cores},
               walltime => $walltime,
                cputime => $cputime,
                 cpueff => $cpuEff_fmt,
         walltime_share => $timeShare_fmt,
                avgwait => $avgwait
      };
      # Table rows for both
      $tt->process_simple(qq|$tmplPeriodFile/table_row|, $row, $outref_full) 
         or die $tt->error;
      $tt->process_simple(qq|$tmplPeriodFile/table_row|, $row, $outref_period) 
         or die $tt->error;

      delete $row->{color};
      $row->{name} = delete $row->{group};
      $jview->{grouplist}{group}{$group} = $row;
    }

    $acctObj->createPlots($el);

    # images for both
    $tt->process_simple(qq|$tmplPeriodFile/images|, 
       {timespan => $ptag}, $outref_full) or die $tt->error;
    $tt->process_simple(qq|$tmplPeriodFile/images|, 
       {timespan => $ptag}, $outref_period) or die $tt->error;

    # for individual periods
    my $tnow = time();
    my $str = strftime qq|%Y-%m-%d %H:%M:%S GMT|, gmtime($tnow);
    $tt->process_simple(qq|$tmplPeriodFile/footer|, 
                  {date => $str, 
             lsfmon_doc => $lsfmon_doc, 
         lsfmon_version => $lsfmon_version}, $outref_period) or die $tt->error;

    $jview->{header} = 
    { 
       timestamp => $tnow, 
             tag => $ptag, 
          period => $period_label
    };
    createHTML(qq|$config->{baseDir}/html/$ptag.html|, $output_period);
    my $save_xml = $config->{accounting}{save_xml} || 0;
    $save_xml and 
      createXML(qq|$config->{baseDir}/html/$ptag.xml|, $jview, {group => 'name'}, 'accounting');

    # Only for the overall -> close tab
    $tt->process_simple(qq|$tmplFile/close_tab|, {}, $outref_full) or die $tt->error;     
  }
  # for the full html
  # close TabView
  $tt->process_simple(qq|$tmplFile/close_tabview|, {}, $outref_full) or die $tt->error;

  # Footer
  my $str = strftime(qq|%Y-%m-%d %H:%M:%S GMT|, gmtime(time()));
  $tt->process_simple(qq|$tmplPeriodFile/footer|, 
                  {date => $str, 
             lsfmon_doc => $lsfmon_doc, 
         lsfmon_version => $lsfmon_version}, $outref_full) or die $tt->error;
  createHTML($config->{accounting}{htmlFile}, $output_full);
}

# Execute
main;
__END__
