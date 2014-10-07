#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Copy;
use POSIX qw/strftime/;
use List::Util qw/min max/;

use Template::Alloy;
use XML::Simple qw/:strict/;
use JSON;

use Util qw/trim getCommandOutput/;
use ConfigReader;
use Overview;
use RRDsys;

$| = 1;

sub createHTML
{
  my $content = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $htmlFile = $config->{html} || qq|$config->{baseDir}/html/overview.html|;
  my $tmpFile = qq|$htmlFile.tmp|;
  my $fh = IO::File->new($tmpFile, 'w');
  $fh->opened or die qq|Failed to open $tmpFile, $!, stopped|;
  print $fh $content;
  $fh->close;

  # Atomic step
  # use a temporary file and then copy to the final in an atomic step
  # Slightly irrelavant in this case
  copy $tmpFile, $htmlFile or
    warn qq|Failed to copy $tmpFile to $htmlFile: $!\n|;
  unlink $tmpFile;
}
sub createXML
{
  my $dict = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $file = $config->{xml}{file} || qq|$config->{baseDir}/html/overview.xml|;
  my $xs = XML::Simple->new;
  my $fh = IO::File->new($file, 'w');
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  my $xml = $xs->XMLout($dict, XMLDecl => 1,
                                NoAttr => 1,
                               KeyAttr => {ce => 'name', dn => 'name'},
                              RootName => 'jobview',
                            OutputFile => $fh);
  $fh->close;
}
sub createJSON
{
  my $dict = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $file = $config->{json}{file} || qq|$config->{baseDir}/html/overview.json|;
  my $fh = IO::File->new($file, 'w');
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  my $jsobj = JSON->new(pretty => 1, delimiter => 1, skipinvalid => 1);
  my $json = ($jsobj->can('encode'))
    ? $jsobj->encode({ 'jobview' => $dict })
    : $jsobj->objToJson({ 'jobview' => $dict });
  print $fh $json;
  $fh->close;
}

sub main
{
  my $fo = Overview->new;
  my $jview = {};

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $server   = $config->{server} || q|UCSD Crab Server|;
  my $verbose  = $config->{verbose} || 0;
  my $tmplFile = $config->{template} || qq|$config->{baseDir}/tmpl/overview.html.tmpl|;
  my $show_usersite = $config->{show_table}{usersite} || 1;
  my $show_userce   = $config->{show_table}{userce}   || 1;
  my $show_priority = $config->{show_table}{priority} || 1;

  my $tt = Template::Alloy->new(
    EXPOSE_BLOCKS => 1,
         ABSOLUTE => 1,
     INCLUDE_PATH => qq|$config->{baseDir}/tmpl|,
      OUTPUT_PATH => qq|$config->{baseDir}/html|
  );
  my $output = q||;
  my $outref = \$output;

  my $timestamp = time;
  my $str = strftime qq|%Y-%m-%d %H:%M:%S GMT|, gmtime($timestamp);
  my $data = {
    crabserver => $server, 
          date => $str
  };
  $jview->{header} = $data;
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;

  # create tabs
  my $tabList = [
    {label => q|summary|,  name => q|Summary|} ,
    {label => q|ce|,       name => q|Computing Element|},
    {label => q|dn|,       name => q|User|},
    {label => q|usersite|, name => q|User@Site|},
    {label => q|userce|,   name => q|User@CE|},
    {label => q|priority|, name => q|Priority|}
  ];
  for my $el (@$tabList) {
    $tt->process_simple(qq|$tmplFile/tabview_row|, 
      {label => $el->{label}, name => $el->{name}}, $outref) or die $tt->error;
  }
  # Resources
  my $slots = $fo->{slots};
  my $s_available = $slots->{available};
  my $s_free      = $slots->{free}; 
  my $row = {
          max => $slots->{max},
    available => $s_available,
      running => $slots->{running},
         free => $s_free
  };
  $jview->{slots} = $row;
  $data = $row;
  $data->{label} = q|summary|;
  $data->{title} = q|CPU Slots|;
  $tt->process_simple(qq|$tmplFile/cpuslots|, $data, $outref) or die $tt->error;

  # Overall Jobs
  my $jobinfo = $fo->{jobinfo};
  my $njobs = $jobinfo->{njobs};
  my $nrun  = $jobinfo->{nrun};
  my $npend = $jobinfo->{npend};
  my $nheld = $jobinfo->{nheld};
  my $cputime_t  = $jobinfo->{cputime};
  my $walltime_t = $jobinfo->{walltime};
  my $cpueff = ($walltime_t > 0)
    ? sprintf ("%-6.2f", max(0.0, $cputime_t*100.0/$walltime_t))
    : (($nrun>0) ? '0.0' : '-');
  my $jobs_leff = $jobinfo->{ratio10};
  $row = 
  {
       total => $njobs,
     running => $nrun,
     pending => $npend,
        held => $nheld,
     cputime => $cputime_t,
    walltime => $walltime_t,
      cpueff => trim($cpueff),
     ratio10 => $jobs_leff
  };
  $jview->{jobs} = $row;
  $data = $row;
  $data->{title} = q|Jobs|;
  $tt->process_simple(qq|$tmplFile/jobs|, $data, $outref) or die $tt->error;

  # Image block
  $tt->process_simple(qq|$tmplFile/image_block|, {}, $outref) or die $tt->error;

  my $nusers = 0;
  if ($njobs > 0) {
    my $userinfo = $fo->{userinfo};
    my @users = keys %$userinfo;
    $nusers = scalar @users;
  }  
  # update RRD
  my $rrdH = RRDsys->new;
  $rrdH->rrdFile($config->{rrd}{db});
  $rrdH->update([
     $timestamp,
     $s_available,
     $s_free,
     $njobs,
     $nrun,
     $npend,
     $nheld,
     (($cpueff eq '-') ? 0 : trim $cpueff),
     $jobs_leff,
     $nusers
  ]);

  # Now User jobs
  # Jobs by CE/Site
  if ($jobinfo->{njobs} > 0) {
    $tt->process_simple(qq|$tmplFile/ce_header|, {label => q|ce|}, $outref) 
      or die $tt->error;
    my @cont = ();
    my $ceinfo = $fo->{ceinfo};
    for my $ce (keys %$ceinfo) {
      my $sites = $ceinfo->{$ce};
      for my $site (sort keys %$sites) {
        next if $site eq '?'; 
        my $njobs = $ceinfo->{$ce}{$site}{njobs};
        my $nrun  = $ceinfo->{$ce}{$site}{nrun};
        my $npend = $ceinfo->{$ce}{$site}{npend};
        my $nheld = $ceinfo->{$ce}{$site}{nheld};
        my $cputime  = $ceinfo->{$ce}{$site}{cputime};
        my $walltime = $ceinfo->{$ce}{$site}{walltime};
        my $cpueff = ($walltime > 0)
          ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
          : (($nrun>0) ? '0.0' : '-');
        my $jobs_leff = $ceinfo->{$ce}{$site}{ratio10};
        my $row = 
        {
                 ce => $ce,
               site => $site,
               jobs => $njobs,
            running => $nrun,
            pending => $npend,
               held => $nheld,
            cputime => $cputime,
           walltime => $walltime,
             cpueff => trim($cpueff),
            ratio10 => $jobs_leff,
        };
        push @cont, $row;
      }    
    } 
    for my $row (sort { $b->{running} <=> $a->{running} } @cont) {
      $tt->process_simple(qq|$tmplFile/ce_row|, $row, $outref) or die $tt->error;
      my $ce = delete $row->{ce};
      if (defined $ce) {
	$row->{name} = $ce;
	$jview->{celist}{ce}{$ce} = $row;
      }
    }
    $tt->process_simple(qq|$tmplFile/ce_footer|, {}, $outref) or die $tt->error;
  }
  if ($jobinfo->{njobs} > 0) {
    # Now User jobs
    my $userinfo = $fo->{userinfo};
    my @users = keys %$userinfo;
    $tt->process_simple(qq|$tmplFile/dn_header|, {label => q|dn|}, $outref) 
      or die $tt->error;
    for my $dn (sort { $userinfo->{$b}{nrun} <=> $userinfo->{$a}{nrun} } @users) {
      my $nrun = $userinfo->{$dn}{nrun};
      my $cputime  = $userinfo->{$dn}{cputime};
      my $walltime = $userinfo->{$dn}{walltime};
      my $cpueff = ($walltime > 0)
         ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
         : (($nrun>0) ? '0.0' : '-');
      my $jobs_leff = $userinfo->{$dn}{ratio10};
      my $row = 
      {
         localuser => $userinfo->{$dn}{user},
              jobs => $userinfo->{$dn}{njobs},
           running => $nrun,
           pending => $userinfo->{$dn}{npend},
              held => $userinfo->{$dn}{nheld},
           cputime => $cputime,
          walltime => $walltime,
            cpueff => trim($cpueff),
           ratio10 => $jobs_leff,
                dn => $dn
      };
      $tt->process_simple(qq|$tmplFile/dn_row|, $row, $outref) or die $tt->error;
      $dn = delete $row->{dn};
      if (defined $dn) {
        $row->{name} = $dn;
        $jview->{dnlist}{dn}{$dn} = $row;
      }
    }
    $tt->process_simple(qq|$tmplFile/dn_footer|, {}, $outref) or die $tt->error;

    # (User,CMSSite) combination
    if ($show_usersite) {
      $tt->process_simple(qq|$tmplFile/usersite_header|, {label => q|usersite|}, $outref) 
        or die $tt->error;
      my $uinfo = $fo->{usersiteinfo};
      while (my $dn = each %$uinfo) {
        my $siteinfo = $uinfo->{$dn};
        for my $site (sort { $uinfo->{$dn}{$b}{nrun} <=> $uinfo->{$dn}{$a}{nrun} } keys %$siteinfo) {
          my $nrun     = $uinfo->{$dn}{$site}{nrun};
          my $cputime  = $uinfo->{$dn}{$site}{cputime};
          my $walltime = $uinfo->{$dn}{$site}{walltime};
          my $cpueff = ($walltime > 0)
            ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
            : (($nrun>0) ? '0.0' : '-');
          my $jobs_leff = $uinfo->{$dn}{$site}{ratio10};
          my $row = {
            localuser => $uinfo->{$dn}{$site}{user},
                 jobs => $uinfo->{$dn}{$site}{njobs},
              running => $nrun,
              pending => $uinfo->{$dn}{$site}{npend},
                 held => $uinfo->{$dn}{$site}{nheld},
              cputime => $cputime,
             walltime => $walltime,
               cpueff => trim($cpueff),
              ratio10 => $jobs_leff,
                 site => $site,
                   dn => $dn
          };
          $tt->process_simple(qq|$tmplFile/usersite_row|, $row, $outref) or die $tt->error;
          $dn = delete $row->{dn};
          if (defined $dn) {
            $row->{name} = $dn;
            $jview->{usersitelist}{dn}{$dn} = $row;
          }
        }    
      } 
      $tt->process_simple(qq|$tmplFile/usersite_footer|, {}, $outref) or die $tt->error;
    }
    # (User,CE) combination
    if ($show_userce) {
      $tt->process_simple(qq|$tmplFile/userce_header|, {label => q|userce|}, $outref) 
        or die $tt->error;
      my $userceinfo = $fo->{userceinfo};
      while (my $dn = each %$userceinfo) {
        my $ceinfo = $userceinfo->{$dn};
        for my $ce (sort { $userceinfo->{$dn}{$b}{nrun} <=> $userceinfo->{$dn}{$a}{nrun} } keys %$ceinfo) {
          my $nrun     = $userceinfo->{$dn}{$ce}{nrun};
          my $cputime  = $userceinfo->{$dn}{$ce}{cputime};
          my $walltime = $userceinfo->{$dn}{$ce}{walltime};
          my $cpueff = ($walltime > 0)
            ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
            : (($nrun>0) ? '0.0' : '-');
          my $jobs_leff = $userceinfo->{$dn}{$ce}{ratio10};
          my $row = {
            localuser => $userceinfo->{$dn}{$ce}{user},
                 jobs => $userceinfo->{$dn}{$ce}{njobs},
              running => $nrun,
              pending => $userceinfo->{$dn}{$ce}{npend},
                 held => $userceinfo->{$dn}{$ce}{nheld},
              cputime => $cputime,
             walltime => $walltime,
               cpueff => trim($cpueff),
              ratio10 => $jobs_leff,
                   ce => $ce,
                   dn => $dn
          };
          $tt->process_simple(qq|$tmplFile/userce_row|, $row, $outref) or die $tt->error;
          $dn = delete $row->{dn};
          if (defined $dn) {
            $row->{name} = $dn;
            $jview->{usercelist}{dn}{$dn} = $row;
          }
        }    
      } 
      $tt->process_simple(qq|$tmplFile/userce_footer|, {}, $outref) or die $tt->error;
    }
  }
  # Priority
  if ($show_priority) {
    my $priority = $fo->getPriority;
    $tt->process_simple(qq|$tmplFile/priority|, { label => q|priority|, priority => $priority }, $outref)
      or die $tt->error;
    $jview->{priority} = {share => $priority};
  }
  # finally the page footer
  $tt->process_simple(qq|$tmplFile/page_footer|, { timestamp => $str }, $outref)
    or die $tt->error;

  # Dump the html content in a file 
  createHTML $output;

  # Dump the overall collection
  print Data::Dumper->Dump([$jview], [qw/jview/]) if $verbose;

  # prepare an XML file
  my $saveXML = $config->{xml}{save} || 0;
  $saveXML and createXML $jview;

  # JSON
  my $saveJSON = $config->{json}{save} || 0;
  $saveJSON and createJSON $jview;

  # Now prepare the RRD graphs
  # resources
  $rrdH->rrdFile($config->{rrd}{db});
  my $attr = {
     fields => ['totalCPU', 'freeCPU'],
     colors => ['#003399', '#009900'],
    options => ['LINE2', 'LINE2'],
     titles => ['   Total', '    Free'],
     vlabel => q|CPU Availability|,
       gtag => q|cpuwtime|
  };
  $rrdH->graph($attr);

  # jobs
  $attr = {
     fields => ['totalJobs', 'runningJobs', 'pendingJobs', 'heldJobs'],
     colors => ['#003399', '#009900', '#ff3300', '#CC9900'],
    options => ['LINE2', 'LINE2', 'LINE2', 'LINE2'],
     titles => ['   Total', ' Running', ' Pending', '    Held'],
     vlabel => q|Jobs|,
       gtag => q|jobwtime|
  };
  $rrdH->graph($attr);
}

# Execute
main;
__END__
