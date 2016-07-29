#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Copy;
use POSIX qw/strftime/;
use List::Util qw/min max/;
use Template::Alloy;

use XML::Writer;
use XML::Simple qw/:strict/;
use JSON;

use Util qw/trim/;
use ConfigReader;
use Overview;
use RRDsys qw/create_rrd update_rrd create_graph/;

# auto-flush
$| = 1;

sub writeData
{
  my ($writer, $href) = @_;
  for my $k (sort keys %$href) {
    $writer->startTag($k);
    $writer->characters((exists $href->{$k} ? $href->{$k} : '-'));
    $writer->endTag($k);
  }
}
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
                               KeyAttr => {ce => 'name', dn => 'name', group => 'name'},
                              RootName => 'jobview',
                            OutputFile => $fh);
  $fh->close;
}
sub createHappyFaceXML
{
  my ($dict, $joblist) = @_;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  # Open the output XML file
  my $file = $config->{xml_hf}{file} || qq|$config->{baseDir}/html/jobview.xml|;
  my $fh = IO::File->new($file, 'w');
  die qq|Failed to open output file $file, $!, stopped| unless defined $fh;

  # Create a XML writer object
  my $writer = XML::Writer->new(OUTPUT => $fh, 
                                DATA_MODE => 'true', 
                                CHECK_PRINT => 1,
		                DATA_INDENT => 2);
  $writer->xmlDecl;  #('UTF-8')

  $writer->startTag(q|jobinfo|);

  # header
  $writer->startTag(q|header|);
  writeData($writer, $dict->{header});
  $writer->endTag(q|header|);
   
  $writer->startTag(q|summaries|);

  # Overall Summary
  $writer->startTag(q|summary|, group => q|all|);
  my $jobinfo = $dict->{jobs};
  writeData($writer, $jobinfo);
  $writer->endTag(q|summary|);
 
  # Group Summary    
  my $groupinfo = $dict->{grouplist}{group};  
  print Data::Dumper->Dump([$groupinfo], [qw/groupinfo/]) if $verbose>1;
  for my $group (sort keys %$groupinfo) {
    $writer->startTag(q|summary|, group => $groupinfo->{$group}{name}, parent => q|all|);
    delete $groupinfo->{$group}{name};
    writeData($writer, $groupinfo->{$group});
    $writer->endTag(q|summary|);
  }
  $writer->endTag(q|summaries|);

  # optionally individual jobs
  my $showJobs = $config->{xml_hf}{show_joblist} || 0;
  if ($showJobs) {
    my $showDN = $config->{xml_hf}{show_dn} || 0;
    $writer->startTag(q|jobs|);
    while ( my ($jid, $job) = each %$joblist ) {
      my $group  = $job->GROUP;
      my $status = $job->STATUS;
      warn q|either group or job status undefined| 
        and next unless (defined $group and defined $status);
      $writer->startTag(q|job|, group => $group, status => $status);
      my $cputime  = $job->CPUTIME  || 0;
      my $walltime = $job->WALLTIME || 0;
      my $ratio = min 1, (($walltime > 0) ? $cputime/$walltime : 0);

      #<state>[running|pending|held|waiting|suspended|exited]</state>
      my $ce = $job->GRID_CE;
      defined $ce and $ce = (split m#/#, $ce)[0];
      my $jobinfo = 
      {
              id => $jid,
           state => $job->LSTATUS,
          status => $job->STATUS,
           group => $group,
         created => ($job->QTIME || undef),  
           queue => ($job->QUEUE || undef),
            user => ($job->USER || undef),
              ce => $ce,
             end => ($job->END || 'n/a')
      };
      $jobinfo->{dn} = $job->SUBJECT || 'local' if $showDN;
      if ($status eq 'R') {
        my $host = $job->EXEC_HOST;
        $host = (defined $host) ? (split /\@/, $host)[-1] : '?';
	$jobinfo->{cpueff}     = trim(sprintf(qq|%7.2f|, 100 * $ratio));
        $jobinfo->{cputime}    = int($cputime);
        $jobinfo->{cpupercent} = trim(sprintf(qq|%7.2f|, 100 * $ratio));
        $jobinfo->{exec_host}  = $host;
        $jobinfo->{walltime}   = $walltime;
        $jobinfo->{start}      = $job->START || undef;
      }
      writeData($writer, $jobinfo);
      $writer->endTag(q|job|);
    }
    $writer->endTag(q|jobs|);
  }

  # finally everything else under <additional>
  $writer->startTag(q|additional|);

  # slots
  $writer->startTag(q|slots|);
  writeData($writer, $dict->{slots});
  $writer->endTag(q|slots|);

  # CE info    
  my $ceinfo = $dict->{celist}{ce};  
  print Data::Dumper->Dump([$ceinfo], [qw/ceinfo/]) if $verbose>1;
  $writer->startTag(q|celist|);
  for my $ce (sort keys %$ceinfo) {
    $writer->startTag(q|ce|, name => $ceinfo->{$ce}{name});
    delete $ceinfo->{$ce}{name};
    writeData($writer, $ceinfo->{$ce});
    $writer->endTag(q|ce|);
  }
  $writer->endTag(q|celist|);

  # User Info
  my $userinfo = $dict->{dnlist}{dn};  
  print Data::Dumper->Dump([$userinfo], [qw/userinfo/]) if $verbose>1;
  $writer->startTag(q|users|);
  for my $dn (sort keys %$userinfo) {
    $writer->startTag(q|dn|, name => $userinfo->{$dn}{name});
    delete $userinfo->{$dn}{name}; 
    writeData($writer, $userinfo->{$dn});
    $writer->endTag(q|dn|);
  }
  $writer->endTag(q|users|);
  $writer->endTag(q|additional|);
  $writer->endTag(q|jobinfo|);

  # close the writer and the filehandle
  $writer->end;
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
  my $rrdH = RRDsys->new;
  my $jview = {};

  my $reader   = ConfigReader->instance();
  my $config   = $reader->config;
  my $site     = $config->{site};
  my $batch    = $config->{batch};
  my $verbose  = $config->{verbose} || 0;
  my $tmplFile = $config->{template} || qq|$config->{baseDir}/tmpl/overview.html.tmpl|;

  # Template::Alloy
  my $tt = Template::Alloy->new(
    EXPOSE_BLOCKS => 1,
    ABSOLUTE      => 1,
    INCLUDE_PATH  => qq|$config->{baseDir}/tmpl|,
    OUTPUT_PATH   => qq|$config->{baseDir}/html|
  );
  my $output = q||;
  my $outref = \$output;

  my $timestamp = time();
  my $str = strftime qq|%Y-%m-%d %H:%M:%S GMT|, gmtime($timestamp);
  my $data = 
  {
     site => $site,
    batch => $batch,
     date => $str
  };
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;
  $data->{date} = $timestamp;
  $jview->{header} = $data;

  # Resources
  $tt->process_simple(qq|$tmplFile/cpuslots_header|, {title => q|CPU Slots|}, $outref)
    or die $tt->error;
  my $slots = $fo->{slots};
  my $s_available = $slots->{available};
  my $s_free      = $slots->{free};
  my $row = 
  {
          max => $slots->{max},
    available => $s_available,
      running => $slots->{running},
         free => $s_free
  };
  $jview->{slots} = $row;
  $tt->process_simple(qq|$tmplFile/cpuslots_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/cpuslots_footer|, {}, $outref) or die $tt->error;

  # Overall Jobs
  $tt->process_simple(qq|$tmplFile/jobs_header|, {title => q|Jobs|}, $outref) 
    or die $tt->error;
  my $jobinfo = $fo->{jobinfo};
  my $njobs = $jobinfo->{njobs};
  my $nrun  = $jobinfo->{nrun};
  my $npend = $jobinfo->{npend};
  my $nheld = $jobinfo->{nheld};
  my $ncore = $jobinfo->{ncore};
  my $cputime = $jobinfo->{cputime};
  my $cputime_core = $jobinfo->{cputime_core};
  my $walltime_t = $jobinfo->{walltime};  # total walltime, used for walltime share calculation
  my $cpueff = ($walltime_t > 0)  
       ? sprintf ("%-6.2f", max(0.0, 100*$cputime_core/$walltime_t))
       : (($nrun>0) ? '0.0' : '-');
  my $jobs_leff = $jobinfo->{ratio10};
  $row = 
  {
        jobs => $njobs,
     running => $nrun,
     pending => $npend,
        held => $nheld,
       ncore => $ncore,
     cputime => $cputime,
    walltime => $walltime_t,
      cpueff => trim($cpueff),
     ratio10 => $jobs_leff
  };
  $jview->{jobs} = $row;
  $tt->process_simple(qq|$tmplFile/jobs_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/jobs_footer|, {}, $outref) or die $tt->error;

  my $nusers = 0;
  if ($njobs > 0) {
    my $userinfo = $fo->{userinfo};
    my @users = keys %$userinfo;
    $nusers = scalar @users;
  }  
  # update RRD
  my $file = $config->{rrd}{db} || q|filen.rrd|;
  warn qq|$file not found, will create now ...| and create_rrd($rrdH, {filename => $file, global => 1}) 
    unless -r $rrdH->filepath($file);
  update_rrd($rrdH, {filename => $file, 
    data => 
    [
      $timestamp,
      $s_available,
      $s_free,
      $njobs,
      $nrun,
      $npend,
      $nheld,
      (($cpueff eq '-') ? 0 : trim($cpueff)),
      $jobs_leff,
      $nusers
    ]
  });
  # Now prepare the RRD graphs
  # resources
  $rrdH->rrdFile($config->{rrd}{db});
  my $attr = 
  {
     fields => ['totalCPU', 'freeCPU'],
     colors => ['#003399', '#009900'],
    options => ['LINE2', 'LINE2'],
     titles => ['  Total', '   Free'],
     vlabel => q|CPU Availability|,
       gtag => q|cpuwtime|
  };
  $rrdH->graph($attr);

  # Overall jobs
  create_graph($rrdH);

  # Graph display option tag
  my $display_options = [q|All Jobs#jobwtime|, 
                         q|Overall CPU Eff#cpueffwtime|, 
                         q|Jobs(Eff<10%)#leffwtime|];

  if ($jobinfo->{njobs}) {
    # Group Jobs
    my $location = $config->{rrd}{location};

    $tt->process_simple(qq|$tmplFile/group_header|, {title => q|Group|}, $outref) 
      or die $tt->error;
    my $groupinfo = $fo->{groupinfo};
    for my $group (sort { $groupinfo->{$b}{nrun} <=> $groupinfo->{$a}{nrun} } keys %$groupinfo) {
      my $njobs  = $groupinfo->{$group}{njobs};
      my $nrun  = $groupinfo->{$group}{nrun};
      my $npend = $groupinfo->{$group}{npend};
      my $nheld = $groupinfo->{$group}{nheld};
      my $ncore = $groupinfo->{$group}{ncore};
      my $cputime  = $groupinfo->{$group}{cputime};
      my $cputime_core  = $groupinfo->{$group}{cputime_core};
      my $walltime = $groupinfo->{$group}{walltime};
      my $cpueff = ($walltime > 0)
         ? sprintf ("%-6.2f", max(0.0, 100*$cputime_core/$walltime))
         : (($nrun>0) ? '0.0' : '-');
      my $walltime_share = ($walltime_t > 0 and $walltime > 0)
         ? sprintf ("%-6.2f", $walltime*100.0/$walltime_t)
         : '-';
      my $jobs_leff = $groupinfo->{$group}{ratio10};

      # update group specific RRDs now
      my $file = qq|$group.rrd|;
      warn qq|$file not found, will create now ...| and create_rrd($rrdH, {filename => $file, global => 0}) 
        unless -r $rrdH->filepath($file);
      update_rrd($rrdH, {filename => $file, 
        data => 
        [
          $timestamp,
          $njobs,
          $nrun,
          $npend,
          $nheld,
          (($cpueff eq '-') ? 0 : trim($cpueff)),
          $jobs_leff
        ]
      });
      create_graph($rrdH, $group);
      push @$display_options, (qq|Group $group Jobs#jobwtime_$group|,
                               qq|Group $group Eff#cpueffwtime_$group|,
                               qq|Group $group Jobs(eff<10%)#leffwtime_$group|);
      my $row = 
      {
                  group => $group,  
                   jobs => $njobs,
                running => $nrun,
                pending => $npend,
                   held => $nheld,
                  ncore => $ncore,
                cputime => $cputime,
               walltime => $walltime,
                 cpueff => trim($cpueff),
                ratio10 => $jobs_leff,
         walltime_share => trim($walltime_share)
      };
      $tt->process_simple(qq|$tmplFile/group_row|, $row, $outref) or die $tt->error;
      my $group = delete $row->{group};
      if (defined $group) {
	$row->{name} = $group;
	$jview->{grouplist}{group}{$group} = $row;
      }
    }
    $tt->process_simple(qq|$tmplFile/group_footer|, {}, $outref) or die $tt->error;
    
    # CE Jobs
    my $show_ce = (exists $config->{show_table}{ce}) ? $config->{show_table}{ce} : 1;
    if ($show_ce) {
      $tt->process_simple(qq|$tmplFile/ce_header|, {title => q|Computing Element|}, $outref) 
        or die $tt->error;
      my $ceinfo = $fo->{ceinfo};
      for my $ce (sort { $ceinfo->{$b}{nrun} <=> $ceinfo->{$a}{nrun} } keys %$ceinfo) {
        my $njobs    = $ceinfo->{$ce}{njobs};
        my $nrun     = $ceinfo->{$ce}{nrun};
        my $npend    = $ceinfo->{$ce}{npend};
        my $nheld    = $ceinfo->{$ce}{nheld};
        my $ncore    = $ceinfo->{$ce}{ncore};
        my $cputime  = $ceinfo->{$ce}{cputime};
        my $cputime_core  = $ceinfo->{$ce}{cputime_core};
        my $walltime = $ceinfo->{$ce}{walltime};
        my $cpueff = ($walltime > 0)
           ? sprintf ("%-6.2f", max(0.0, 100*$cputime_core/$walltime))
           : (($nrun>0) ? '0.0' : '-');
        my $jobs_leff = $ceinfo->{$ce}{ratio10};

        # update CE specific RRDs now
        my $ceshort = (split /\./, $ce)[0];
        my $file = qq|$ceshort.rrd|;
        warn qq|$file not found, will create now ...| and create_rrd($rrdH, {filename => $file, global => 0}) 
          unless -r $rrdH->filepath($file);
        update_rrd($rrdH, {filename => $file, 
          data => 
          [
            $timestamp,
            $njobs,
            $nrun,
            $npend,
            $nheld,
            (($cpueff eq '-') ? 0 : trim($cpueff)),
            $jobs_leff
          ]
        });
        create_graph($rrdH, $ceshort);
        push @$display_options, (qq|CE $ceshort Jobs#jobwtime_$ceshort|,
                                 qq|CE $ceshort Eff#cpueffwtime_$ceshort|,
                                 qq|CE $ceshort Jobs(eff<10%)#leffwtime_$ceshort|);
        my $row = 
        {
                 ce => $ce,
               jobs => $njobs,
            running => $nrun,
            pending => $npend,
               held => $nheld,
              ncore => $ncore,
            cputime => $cputime,
           walltime => $walltime,
             cpueff => trim($cpueff),
            ratio10 => $jobs_leff
        };
        $tt->process_simple(qq|$tmplFile/ce_row|, $row, $outref) or die $tt->error;
        $ce = delete $row->{ce};
        if (defined $ce) {
          $row->{name} = $ce;
          $jview->{celist}{ce}{$ce} = $row;
        }
      } 
      $tt->process_simple(qq|$tmplFile/ce_footer|, {}, $outref) or die $tt->error;
    }
  }  
  # image panel
  my $options;
  for my $item (@$display_options) {
    my ($key, $val) = (split /#/, $item);
    $options .= qq|<option value="$val">$key</option>\n|;
  }
  $tt->process_simple(qq|$tmplFile/image_block|, {options => $options}, $outref) or die $tt->error;

  if ($jobinfo->{njobs}) {
    # Now User jobs
    my $show_user = $config->{show_table}{user} || 0;
    if ($show_user) {
      my $privacy_enforced = (exists $config->{privacy_enforced}) ? $config->{privacy_enforced} : 1;
      my $groups_dnshown = $config->{groups_dnshown} || ['cms'];
      
      my $userinfo = $fo->{userinfo};
      my @users = keys %$userinfo;
      $tt->process_simple(qq|$tmplFile/dn_header|, {title => q|User DN|}, $outref) 
        or die $tt->error;
      for my $dn (sort { $userinfo->{$b}{nrun} <=> $userinfo->{$a}{nrun} } @users) {
        my $group = $userinfo->{$dn}{group};
        next if ($privacy_enforced and not grep { $_ eq $group } @$groups_dnshown);
        my $nrun = $userinfo->{$dn}{nrun};
        my $cputime = $userinfo->{$dn}{cputime};
        my $cputime_core = $userinfo->{$dn}{cputime_core};
        my $walltime = $userinfo->{$dn}{walltime};
        my $cpueff = ($walltime > 0)
           ? sprintf ("%-6.2f", max(0.0, 100*$cputime_core/$walltime))
           : (($nrun>0) ? '0.0' : '-');
        my $jobs_leff = $userinfo->{$dn}{ratio10};
        my $row = 
        {
          localuser => $userinfo->{$dn}{user},
              group => $group,
               jobs => $userinfo->{$dn}{njobs},
            running => $nrun,
            pending => $userinfo->{$dn}{npend},
               held => $userinfo->{$dn}{nheld},
              ncore => $userinfo->{$dn}{ncore},
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
    }
  }
  # Priority
  my $show_priority = (exists $config->{show_table}{priority})
     ? $config->{show_table}{priority} : 1;
  if ($show_priority) {
    my $priority = $fo->getPriority;
    $tt->process_simple(qq|$tmplFile/priority|, {priority => $priority}, $outref)
      or die $tt->error;
    $jview->{priority} = {share => $priority};
  }
  # finally the page footer
  my $app_v = $config->{jobview_version} || q|1.4.0|;
  my $link = $config->{doc} || q|http://sarkar.web.cern.ch/sarkar/doc/condor_jobview.html|;
  $tt->process_simple(qq|$tmplFile/page_footer|, 
    { jobview_version => $app_v, doc => $link }, $outref) or die $tt->error;

  # Dump the html content in a file 
  createHTML $output;

  # Dump the overall collection
  print Data::Dumper->Dump([$jview], [qw/jview/]) if $verbose;

  # prepare an XML file
  my $saveXML = $config->{xml}{save} || 0;
  $saveXML and createXML $jview;

  # prepare the HappyFace compatible XML file
  $saveXML = $config->{xml_hf}{save} || 0;
  $saveXML and createHappyFaceXML $jview, $fo->{joblist};

  # JSON
  my $saveJSON = $config->{json}{save} || 0;
  $saveJSON and createJSON $jview;
}
# Execute
main;
__END__
