#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use POSIX qw/strftime/;
use List::Util qw/min max/;
use Template::Alloy;

use LSF::Util qw/trim 
                 getCommandOutput
                 createHTML
                 createXML
                 createHappyFaceXML
                 createJSON/;
use LSF::ConfigReader;
use LSF::Overview;
use LSF::JobFlow;
use LSF::RRDsys;

sub jobFlow
{
  my ($sjobs, $djobs, $cjobs) = @_;
  join ('|', $sjobs, $djobs, $cjobs);
}
sub overview
{
  my ($attr) = @_;

  my $farminfo = $attr->{farminfo};
  my $jflow    = $attr->{jobflow};
  my $rrdH     = $attr->{rrdH};

  my $flowinfo = $jflow->{jobinfo};
  my $jview = {};

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{verbose} || 0;
  my $cluster_type = $config->{cluster_type} || q|grid|;
  my $tmplFile = $config->{overview}{template} || 
       ($cluster_type eq q|grid| ? qq|$config->{baseDir}/tmpl/overview.grid.html.tmpl|
                                 : qq|$config->{baseDir}/tmpl/overview.hpc.html.tmpl|);
  my $site     = $config->{site} || q|unknown|;
  my $samname  = $config->{samname} || q|unknown|;
  my $lcgname  = $config->{lcgname} || q|unknown|;
  my $batch    = $config->{batch};
  my $privacy_enforced = $config->{overview}{privacy_enforced} || 0;
  my $groups_dnshown = $config->{overview}{groups_dnshown} || ['cms'];
  
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
     site => $samname, 
    batch => $batch, 
     date => $str
  };
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;
  $data->{date} = $timestamp;
  $jview->{header} = $data;

  # Resources
  $tt->process_simple(qq|$tmplFile/cpuslots_header|, {}, $outref) 
    or die $tt->error;
  my $slots = $farminfo->{slots};
  my $s_available = $slots->{available};
  my $s_free      = $slots->{free};
  my $s_running   = $slots->{running};
  my $row = 
  {
       maxever => $slots->{maxever},
           max => $slots->{max},
     available => $s_available,
       running => $s_running,
          free => $s_free
  };
  $jview->{slots} = $row;
  $tt->process_simple(qq|$tmplFile/cpuslots_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/cpuslots_footer|, {}, $outref) or die $tt->error;

  # Jobs
  $tt->process_simple(qq|$tmplFile/jobs_header|, {}, $outref) 
    or die $tt->error;
  my $flow = jobFlow($flowinfo->{joblist}{submitted}  || 0, 
                     $flowinfo->{joblist}{dispatched} || 0,
                     $flowinfo->{joblist}{completed}  || 0);
  my $jobinfo = $farminfo->{jobs};
  my $njobs  = $jobinfo->{njobs};
  my $nrun  = $jobinfo->{nrun};
  my $npend = $jobinfo->{npend};
  my $nheld = $jobinfo->{nheld};
  my $cputime_t  = $jobinfo->{cputime};
  my $walltime_t = $jobinfo->{walltime};
  my $cpueff = ($walltime_t > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime_t*100.0/$walltime_t)) 
       : '-';
  my $jobs_leff = $jobinfo->{ratio10};
  $row = 
  {
         jobs => $njobs,
      running => $nrun,
      pending => $npend,
         held => $nheld,
        cores => $jobinfo->{ncore},
      cputime => $cputime_t,
     walltime => $walltime_t,
       cpueff => trim($cpueff),
      jobflow => $flow,
      ratio10 => $jobs_leff
  };
  $jview->{jobs} = $row;
  $tt->process_simple(qq|$tmplFile/jobs_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/jobs_footer|, {}, $outref) or die $tt->error;

  my $nusers = 0;
  if ($njobs > 0) {
    my $userinfo = $farminfo->{userinfo};
    my @users = keys %$userinfo;
    $nusers = scalar @users;
  }  
  # update RRD
  my $file = $config->{rrd}{db}{global};
  warn qq|$file not found, will create now ...| and LSF::RRDsys->create_rrd($rrdH, {filename => $file, global => 1}) 
    unless -r $rrdH->filepath($file);
  LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
    data => 
    [
      $timestamp,
      $s_available,
      $s_running,
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
  LSF::RRDsys->create_global_graph($rrdH, 
          {filename => $file, 
             fields => ['totalCPU', 'usedCPU', 'freeCPU'],
             vlabel => q|CPU|, gtag => q|cpuwtime|  
           });

  # Overall jobs
  LSF::RRDsys->create_graph($rrdH, {filename => $file, show_users => 0});

  # Graph display option tag
  my $display_options = [q|All Jobs#jobwtime|, 
                         q|Overall CPU Eff#cpueffwtime|, 
                         q|Jobs(Eff<10%)#leffwtime|];
  # Jobs by VO/Groups
  my $show_groups = (exists $config->{overview}{show_table}{group}) 
    ? $config->{overview}{show_table}{group} : 1;

  my $location = $config->{rrd}{location};
  $tt->process_simple(qq|$tmplFile/group_header|, {}, $outref) 
    or die $tt->error if $show_groups;

  # Build a group map
  my $valid_groups = {};
  my $groupinfo = $farminfo->{groups};
  my $fgrouplist = $flowinfo->{grouplist};
  for my $group (sort { $groupinfo->{$b}{nrun} <=> $groupinfo->{$a}{nrun} } keys %$groupinfo) {
    ++$valid_groups->{$group};
    my $flow = jobFlow($fgrouplist->{$group}{submitted}  || 0, 
                       $fgrouplist->{$group}{dispatched} || 0,
                       $fgrouplist->{$group}{completed}  || 0);
    my $njobs = $groupinfo->{$group}{njobs};
    my $nrun  = $groupinfo->{$group}{nrun};
    my $npend = $groupinfo->{$group}{npend};
    my $nheld = $groupinfo->{$group}{nheld};
    my $cputime  = $groupinfo->{$group}{cputime};
    my $walltime = $groupinfo->{$group}{walltime};
    my $cpueff = ($walltime > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
       : '-';
    my $walltime_share = ($walltime_t > 0 and $walltime > 0) 
       ? sprintf ("%-6.2f", $walltime*100.0/$walltime_t) 
       : '-';
    my $jobs_leff = $groupinfo->{$group}{ratio10};
    my $row = 
    {
                group => $group,
                 jobs => $njobs, 
              running => $nrun,
              pending => $npend,
                 held => $nheld,
                cores => $groupinfo->{$group}{ncore},
              cputime => $cputime,
             walltime => $walltime,
               cpueff => trim($cpueff),
              jobflow => $flow,
              ratio10 => $jobs_leff,
       walltime_share => trim($walltime_share)
    };
    $tt->process_simple(qq|$tmplFile/group_row|, $row, $outref) or die $tt->error if $show_groups;
    my $group = delete $row->{group};
    if (defined $group) {
      $row->{name} = $group;
      $jview->{grouplist}{group}{$group} = $row;
    }

    my $file = qq|$group.rrd|;
    warn qq|$file not found, will create now ...| and LSF::RRDsys->create_rrd($rrdH, {filename => $file, global => 0}) 
      unless -r $rrdH->filepath($file);
    LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
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
    LSF::RRDsys->create_graph($rrdH, {filename => $file, show_users => 0, tag => $group});
    push @$display_options, (qq|Group: &lt;$group&gt; Jobs#jobwtime_$group|,
                             qq|Group: &lt;$group&gt; Eff#cpueffwtime_$group|,
                             qq|Group: &lt;$group&gt; Jobs(eff<10%)#leffwtime_$group|);
  }
  # add queues which do not have any jobs now, but a valid jobflow
  for my $g (keys %$fgrouplist) {
    next if exists $valid_groups->{$g};
    my $flow = jobFlow($fgrouplist->{$g}{submitted}  || 0, 
                       $fgrouplist->{$g}{dispatched} || 0,
                       $fgrouplist->{$g}{completed}  || 0);
    my $row = 
    {
                group => $g,
                 jobs => 0,
              running => 0,
              pending => 0,
                 held => 0,
                cores => 0,
               cpueff => '-',
              ratio10 => 0,
       walltime_share => '-',
              jobflow => $flow
    };
    $tt->process_simple(qq|$tmplFile/group_row|, $row, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/group_footer|, {}, $outref) or die $tt->error if $show_groups;

  # Jobs by UI/Computing Elements
  my $show_uis = (exists $config->{overview}{show_table}{ui}) 
     ? $config->{overview}{show_table}{ui} : 1;
  if ($show_uis) {
    $tt->process_simple(qq|$tmplFile/ui_header|, {}, $outref) 
      or die $tt->error;
    my $uiinfo = $farminfo->{uiinfo};
    my $filter_ui = $config->{overview}{filter_ui} || 0;
    my $ui_whitelist = $config->{overview}{ui_whitelist} || [];
    # Build a ui map
    my $valid_uis = {};
    my $fuilist = $flowinfo->{uilist};
    for my $ui (sort { $uiinfo->{$b}{nrun} <=> $uiinfo->{$a}{nrun} } keys %$uiinfo) {
      next if ($filter_ui and not grep { $_ eq $ui } @$ui_whitelist);
      ++$valid_uis->{$ui};

      my $flow = jobFlow($fuilist->{$ui}{submitted}  || 0, 
                         $fuilist->{$ui}{dispatched} || 0,
                         $fuilist->{$ui}{completed}  || 0);
      my $njobs = $uiinfo->{$ui}{njobs};
      my $nrun = $uiinfo->{$ui}{nrun};
      my $npend = $uiinfo->{$ui}{npend};
      my $nheld = $uiinfo->{$ui}{nheld};
      my $cputime  = $uiinfo->{$ui}{cputime};
      my $walltime = $uiinfo->{$ui}{walltime};
      my $cpueff = ($walltime > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
       : '-';
      my $jobs_leff = $uiinfo->{$ui}{ratio10};

      # update UI specific RRDs now
      my $uishort = (split m#\.#, $ui)[0];
      my $file = qq|$uishort.rrd|;
      warn qq|$file not found, will create now ...| and LSF::RRDsys->create_rrd($rrdH, {filename => $file, global => 0}) 
        unless -r $rrdH->filepath($file);
      LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
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
      LSF::RRDsys->create_graph($rrdH, {filename => $file, show_users => 0, tag => $uishort});
      push @$display_options, (qq|UI: &lt;$uishort&gt; Jobs#jobwtime_$uishort|,
                               qq|UI: &lt;$uishort&gt; Eff#cpueffwtime_$uishort|,
                               qq|UI: &lt;$uishort&gt; Jobs(eff<10%)#leffwtime_$uishort|);
      my $row = 
      {
              ui => $ui,
            jobs => $njobs,
         running => $nrun,
         pending => $npend,
            held => $nheld,
           cores => $uiinfo->{$ui}{ncore},
         cputime => $cputime,
        walltime => $walltime,
          cpueff => trim($cpueff),
         jobflow => $flow,
         ratio10 => $jobs_leff,
      };
      $tt->process_simple(qq|$tmplFile/ui_row|, $row, $outref) or die $tt->error;
      $ui = delete $row->{ui};
      if (defined $ui) {
        $row->{name} = $ui;
        $jview->{uilist}{ui}{$ui} = $row;
      }
    }
    # add ui's which do not have any jobs now, but a valid jobflow
    for my $ui (keys %$fuilist) {
      next if exists $valid_uis->{$ui};
      my $flow = jobFlow($fuilist->{$ui}{submitted}  || 0, 
                         $fuilist->{$ui}{dispatched} || 0,
                         $fuilist->{$ui}{completed}  || 0);
      my $row = 
      {
                     ui => $ui,
                   jobs => 0,
                running => 0,
                pending => 0,
                   held => 0,
                  cores => 0,
                 cpueff => '-',
                ratio10 => 0,
         walltime_share => '-',
                jobflow => $flow
      };
      $tt->process_simple(qq|$tmplFile/ui_row|, $row, $outref) or die $tt->error;
    }
    $tt->process_simple(qq|$tmplFile/ui_footer|, {}, $outref) or die $tt->error;
  }

  # image panel
  my $options;
  for my $item (@$display_options) {
    my ($key, $val) = (split /#/, $item);
    $options .= qq|<option value="$val">$key</option>\n|;
  }
  $tt->process_simple(qq|$tmplFile/image_block|, 
     {options => $options, samname => $samname}, $outref) or die $tt->error;

  # Now User jobs
  my $show_userdn = (exists $config->{overview}{show_table}{userdn}) 
      ? $config->{overview}{show_table}{userdn} : 1;
  if ($show_userdn) {
    $tt->process_simple(qq|$tmplFile/dn_header|, {}, $outref) 
      or die $tt->error;
    my $show_localusers = $config->{overview}{show_table}{localusers} || 0;
    my $show_gridusers  = $config->{overview}{show_table}{gridusers} || 1;
    my $dict = {
         dn => {show => $show_gridusers, 
                privacy_enforced => $privacy_enforced}, 
      local => {show => $show_localusers, 
                privacy_enforced => 0}
    };
    my $dninfo = $farminfo->{dninfo};
    my $fdnlist = $flowinfo->{dnlist};
    while ( my ($tag) = each %$dict) {
      next unless $dict->{$tag}{show};
      # we shall sort jobs within each category (grif, local)
      my @cont = ();
      while ( my ($dn) = each %$dninfo ) {
        next if ($tag eq 'dn'    and $dn =~ /^local-/);
        next if ($tag eq 'local' and not $dn =~ /^local-/);
        my $users = $dninfo->{$dn};
        while ( my ($user) = each %$users ) {
          my $groups = $users->{$user};
          while ( my ($group) = each %$groups ) {
            next if ($dict->{$tag}{privacy_enforced} and not grep { $_ eq $group } @$groups_dnshown);
            my $flow = jobFlow($fdnlist->{$dn}{$user}{$group}{submitted}  || 0, 
                               $fdnlist->{$dn}{$user}{$group}{dispatched} || 0,
                               $fdnlist->{$dn}{$user}{$group}{completed}  || 0);
            my $nrun     = $dninfo->{$dn}{$user}{$group}{nrun};
            my $cputime  = $dninfo->{$dn}{$user}{$group}{cputime};
            my $walltime = $dninfo->{$dn}{$user}{$group}{walltime};
            my $cpueff = ($walltime > 0) 
              ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
              : '-';
            my $jobs_leff = $dninfo->{$dn}{$user}{$group}{ratio10};
            my $row = {
                   user => $user,
                  group => $group,
                   jobs => $dninfo->{$dn}{$user}{$group}{njobs},
                running => $nrun,
                pending => $dninfo->{$dn}{$user}{$group}{npend},
                   held => $dninfo->{$dn}{$user}{$group}{nheld},
                  cores => $dninfo->{$dn}{$user}{$group}{ncore},
                cputime => $cputime,
               walltime => $walltime,
                 cpueff => trim($cpueff),
                jobflow => $flow,
                ratio10 => $jobs_leff
            };
            $row->{dn} = $dn if $cluster_type eq 'grid';
            push @cont, $row;
            print Data::Dumper->Dump([$row], [qw/row/]) if $verbose;
          }
        }
      }
      # add users who do not have any jobs now, but a valid jobflow
      print Data::Dumper->Dump([@cont], [qw/row/]) if $verbose;
      while ( my ($dn) = each %$fdnlist ) {
        next if ($tag eq 'dn'    and $dn =~ /^local-/);
        next if ($tag eq 'local' and not $dn =~ /^local-/);
        my $users = $fdnlist->{$dn};
        while ( my ($user) = each %$users ) {
          next if grep { $_->{user} eq $user } @cont;
          my $groups = $users->{$user};
          while ( my ($group) = each %$groups ) {
            my $flow = jobFlow($fdnlist->{$dn}{$user}{$group}{submitted}  || 0, 
                               $fdnlist->{$dn}{$user}{$group}{dispatched} || 0,
                               $fdnlist->{$dn}{$user}{$group}{completed}  || 0);
            my $row = 
            {
                         user => $user,
                        group => $group,
                         jobs => 0,
                      running => 0,
                      pending => 0,
                         held => 0,
                        cores => 0,
                       cpueff => '-',
                      ratio10 => 0,
                      jobflow => $flow
            };
            $row->{dn} = $dn if $cluster_type eq 'grid';
            push @cont, $row;
          }
        }
      }
      # Now show the sorted content
      for my $row (sort { $b->{running} <=> $a->{running} } @cont) {
        $tt->process_simple(qq|$tmplFile/dn_row|, $row, $outref) or die $tt->error;
        my $dn = delete $row->{dn};
        if (defined $dn) {
          $row->{name} = $dn;
          $jview->{dnlist}{dn}{$dn} = $row;
        }
      }
    }
    $tt->process_simple(qq|$tmplFile/dn_footer|, {}, $outref) or die $tt->error;
  }
  # Jobs by Users/ui combinations
  my $show_users = (exists $config->{overview}{show_table}{user}) 
     ? $config->{overview}{show_table}{user} : 1;
  if ($show_users) {
    $tt->process_simple(qq|$tmplFile/user_header|, {}, $outref) 
       or die $tt->error;
    my $userinfo = $farminfo->{users};
    while ( my ($user) = each %$userinfo ) {
      my $groups = $userinfo->{$user};
      while ( my ($group) = each %$groups ) {
        next if ($privacy_enforced and not grep { $_ eq $group } @$groups_dnshown);
        my $dnlist = $userinfo->{$user}{$group};
        while ( my ($dn) = each %$dnlist ) {
          my $uilist = $userinfo->{$user}{$group}{$dn};
          while ( my ($ui) = each %$uilist ) {
            my $flow = jobFlow($flowinfo->{userlist}{$user}{$group}{$dn}{$ui}{submitted}  || 0, 
                               $flowinfo->{userlist}{$user}{$group}{$dn}{$ui}{dispatched} || 0,
                               $flowinfo->{userlist}{$user}{$group}{$dn}{$ui}{completed}  || 0);
            my $nrun     = $userinfo->{$user}{$group}{$dn}{$ui}{nrun};
            my $cputime  = $userinfo->{$user}{$group}{$dn}{$ui}{cputime};
            my $walltime = $userinfo->{$user}{$group}{$dn}{$ui}{walltime};
            my $cpueff = ($walltime > 0) 
               ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
               : (($nrun>0) ? '0.0' : '-');
            my $row = {
                   user => $user,
                  group => $group,
                   jobs => $userinfo->{$user}{$group}{$dn}{$ui}{njobs},
                running => $nrun,
                pending => $userinfo->{$user}{$group}{$dn}{$ui}{npend},
                   held => $userinfo->{$user}{$group}{$dn}{$ui}{nheld},
                  cores => $userinfo->{$user}{$group}{$dn}{$ui}{ncore},
                 cpueff => trim($cpueff),
                jobflow => $flow,
                ratio10 => $userinfo->{$user}{$group}{$dn}{$ui}{ratio10},
                     ui => $ui
            };
            $row->{dn} = $dn if $cluster_type eq 'grid';
            $tt->process_simple(qq|$tmplFile/user_row|, $row, $outref) or die $tt->error;
          }
        }
      }
    }
    $tt->process_simple(qq|$tmplFile/user_footer|, {}, $outref) or die $tt->error;
  }
  # fair share and footer
  my $show_fairshare = (exists $config->{overview}{show_table}{fairshare}) 
     ? $config->{overview}{show_table}{fairshare} : 1;
  if ($show_fairshare) {
    my $command = q|bhpart -r|;
    my $ecode = 0;
    my $show_error = $config->{show_cmd_error} || 0;
    my $result = getCommandOutput($command, \$ecode, $show_error, $verbose);
    $tt->process_simple(qq|$tmplFile/fairshare|, {groupshare => $result}, $outref)
      or die $tt->error;
    $jview->{fairshare} = {groupshare => $result};
  } 
  $tt->process_simple(qq|$tmplFile/page_footer|, {}, $outref)
    or die $tt->error;

  # Dump the html content in a file 
  my $htmlFile = $config->{overview}{html} || qq|$config->{baseDir}/html/overview.html|;
  createHTML($htmlFile, $output);

  # Dump the overall collection
  print Data::Dumper->Dump([$jview], [qw/jview/]) if $verbose;

  # prepare an XML file
  my $saveXML = $config->{overview}{xml}{save} || 0;
  if ($saveXML) {
    my $xmlFile = $config->{overview}{xml}{file} || qq|$config->{baseDir}/html/overview.xml|;
    createXML($xmlFile, $jview, {ui => 'name', dn => 'name', group => 'name'}, 'jobview');
  }

  # HappyFace XML
  $saveXML = $config->{overview}{xml_hf}{save} || 0;
  $saveXML and createHappyFaceXML($jview, $config, {joblist => $farminfo->{joblist}});

  # JSON
  my $saveJSON = $config->{overview}{json}{save} || 0;
  if ($saveJSON) { 
    my $jsonFile = $config->{overview}{json}{file} || qq|$config->{baseDir}/html/overview.json|;
    createJSON($jsonFile, $jview, 'jobview');
  }
}
sub overview_queue
{
  my ($attr) = @_;

  my $farminfo = $attr->{farminfo};
  my $jflow    = $attr->{jobflow};
  my $rrdH     = $attr->{rrdH};

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{verbose} || 0;
  my $cluster_type = $config->{cluster_type} || q|grid|;
  my $tmplFile = $config->{overview}{template_queue} || 
       ($cluster_type eq q|grid| ? qq|$config->{baseDir}/tmpl/overview.queue.grid.html.tmpl|
                                 : qq|$config->{baseDir}/tmpl/overview.queue.hpc.html.tmpl|);
  my $site     = $config->{site} || q|unknown|;
  my $samname  = $config->{samname} || q|unknown|;
  my $lcgname  = $config->{lcgname} || q|unknown|;
  my $batch    = $config->{batch};
  
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
     site => $samname, 
    batch => $batch, 
     date => $str
  };
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;

  # Resources
  $tt->process_simple(qq|$tmplFile/jobslots_header|, {}, $outref) 
    or die $tt->error;
  my $slots = $farminfo->{slots};
  my $s_available = $slots->{available};
  my $s_used      = $slots->{available} - $slots->{free};
  my $s_free      = $slots->{free};
  my $row = 
  {
           max => $slots->{max},
     available => $s_available,
          used => $s_used,
          free => $s_free
  };
  $tt->process_simple(qq|$tmplFile/jobslots_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/jobslots_footer|, {}, $outref) or die $tt->error;

  # update RRD
  my $file = $config->{rrd}{db}{jobslots};
  my $path = $rrdH->filepath($file);
  -r $path or LSF::RRDsys->create_slot_rrd($rrdH, {filename => $file});
  LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
                                      data => [
                                        $timestamp, 
                                        $s_available, 
                                        $s_used, 
                                        $s_free 
                                      ]});
  LSF::RRDsys->create_global_graph($rrdH, 
          {filename => $file, 
             fields => ['totalSlots', 'usedSlots', 'freeSlots'],
             vlabel => q|Slot|, gtag => q|slotwtime|  
           });

  $tt->process_simple(qq|$tmplFile/jobs_header|, {}, $outref) 
    or die $tt->error;
  my $flowinfo = $jflow->{jobinfo};
  my $flow = jobFlow($flowinfo->{joblist}{submitted}  || 0, 
                     $flowinfo->{joblist}{dispatched} || 0,
                     $flowinfo->{joblist}{completed}  || 0);
  my $jobinfo = $farminfo->{jobs};
  my $njobs = $jobinfo->{njobs};
  my $nrun  = $jobinfo->{nrun};
  my $npend = $jobinfo->{npend};
  my $nheld = $jobinfo->{nheld};
  my $cputime_t  = $jobinfo->{cputime};
  my $walltime_t = $jobinfo->{walltime};
  my $cpueff = ($walltime_t > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime_t*100.0/$walltime_t)) 
       : '-';
  my $jobs_leff = $jobinfo->{ratio10};

  # Calculate total # of queues
  my $valid_queues = {};
  my $queueinfo = $farminfo->{queues};
  for my $queue (keys %$queueinfo) {
    $valid_queues->{$queue}++;
  }
  my $nqueues = scalar keys %$valid_queues;

  my $fqueuelist = $flowinfo->{queuelist};
  for my $q (keys %$fqueuelist) {
    next if exists $valid_queues->{$q};
    ++$nqueues;
  }

  $row = 
  {
       queues => $nqueues,
         jobs => $njobs,
      running => $nrun,
      pending => $npend,
         held => $nheld,
        cores => $jobinfo->{ncore},
      cputime => $cputime_t,
     walltime => $walltime_t,
       cpueff => trim($cpueff),
      jobflow => $flow,
      ratio10 => $jobs_leff
  };
  $tt->process_simple(qq|$tmplFile/jobs_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/jobs_footer|, {}, $outref) or die $tt->error;

  # update RRD
  $file = $config->{rrd}{db}{all_queues};
  warn qq|$file not found, will create now ...| and LSF::RRDsys->create_rrd($rrdH, {filename => $file, global => 0}) 
    unless -r $rrdH->filepath($file);
  LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
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
  # Overall jobs
  LSF::RRDsys->create_graph($rrdH, {filename => $file, show_users => 0});

  # Graph display option tag
  my $display_options = [q|All Jobs#jobwtime|, 
                         q|Overall CPU Eff#cpueffwtime|, 
                         q|Jobs(Eff<10%)#leffwtime|];

  # Jobs by Queues
  my $location = $config->{rrd}{location};
  $tt->process_simple(qq|$tmplFile/queue_header|, {}, $outref) or die $tt->error;
  for my $queue (sort { $queueinfo->{$b}{nrun} <=> $queueinfo->{$a}{nrun} } keys %$queueinfo) {
    my $flow = jobFlow($fqueuelist->{$queue}{submitted}  || 0, 
                       $fqueuelist->{$queue}{dispatched} || 0,
                       $fqueuelist->{$queue}{completed}  || 0);
    my $njobs = $queueinfo->{$queue}{njobs};
    my $nrun  = $queueinfo->{$queue}{nrun};
    my $npend = $queueinfo->{$queue}{npend};
    my $nheld = $queueinfo->{$queue}{nheld};
    my $cputime  = $queueinfo->{$queue}{cputime};
    my $walltime = $queueinfo->{$queue}{walltime};
    my $cpueff = ($walltime > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
       : '-';
    my $walltime_share = ($walltime_t > 0 and $walltime > 0) 
       ? sprintf ("%-6.2f", $walltime*100.0/$walltime_t) 
       : '-';
    my $jobs_leff = $queueinfo->{$queue}{ratio10};
    my $row = 
    {
                queue => $queue,
                 jobs => $njobs,
              running => $nrun,
              pending => $npend,
                 held => $nheld,
                cores => $queueinfo->{$queue}{ncore},
              cputime => $cputime,
             walltime => $walltime,
               cpueff => trim($cpueff),
              jobflow => $flow,
              ratio10 => $jobs_leff,
       walltime_share => trim($walltime_share)
    };
    $tt->process_simple(qq|$tmplFile/queue_row|, $row, $outref) or die $tt->error;

    # update QUEUE specific RRDs now
    $file =  qq|$queue.rrd|;
    warn qq|$queue.rrd not found, will create now| 
      and LSF::RRDsys->create_rrd($rrdH, {filename => $file}) unless -r $rrdH->filepath($file);
    LSF::RRDsys->update_rrd($rrdH, {filename => $file, 
        data => 
        [
          $timestamp,
          $njobs,
          $nrun,
          $npend,
          $nheld,
          (($cpueff eq '-') ? 0 : trim($cpueff)),
          $jobs_leff,
        ]
    });
    LSF::RRDsys->create_graph($rrdH, {filename => $file, show_users => 0, tag => $queue});
    push @$display_options, (qq|Queue: &lt;$queue&gt; Jobs#jobwtime_$queue|,
                             qq|Queue: &lt;$queue&gt; Eff#cpueffwtime_$queue|,
                             qq|Queue: &lt;$queue&gt; Jobs(eff<10%)#leffwtime_$queue|);

  }
  # add queues which do not have any jobs now, but a valid jobflow
  for my $q (keys %$fqueuelist) {
    next if exists $valid_queues->{$q};
    my $flow = jobFlow($fqueuelist->{$q}{submitted}  || 0, 
                       $fqueuelist->{$q}{dispatched} || 0,
                       $fqueuelist->{$q}{completed}  || 0);
    my $row = 
    {
                queue => $q,
                 jobs => 0,
              running => 0,
              pending => 0,
                 held => 0,
                cores => 0,
               cpueff => '-',
              ratio10 => 0,
       walltime_share => '-',
              jobflow => $flow
    };
    $tt->process_simple(qq|$tmplFile/queue_row|, $row, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/queue_footer|, {}, $outref) or die $tt->error;

  # image panel
  my $options;
  for my $item (@$display_options) {
    my ($key, $val) = (split /#/, $item);
    $options .= qq|<option value="$val">$key</option>\n|;
  }
  $tt->process_simple(qq|$tmplFile/image_block|, 
     {options => $options, samname => $samname}, $outref) or die $tt->error;

  $tt->process_simple(qq|$tmplFile/page_footer|, {}, $outref)
    or die $tt->error;

  # Dump the html content in a file 
  my $htmlFile = $config->{overview}{html_queue} || qq|$config->{baseDir}/html/overview.queue.html|;
  createHTML($htmlFile, $output);
}
sub main
{
  my $filemap  = LSF::Overview->filemap;
  my $farminfo = LSF::Overview->new({ filemap => $filemap });
  my $jflow    = LSF::JobFlow->new({ filemap => $filemap });
  my $rrdH     = LSF::RRDsys->new;

  overview({farminfo => $farminfo, jobflow => $jflow, rrdH => $rrdH});
  overview_queue({farminfo => $farminfo, jobflow => $jflow, rrdH => $rrdH});
}

# Execute
main;
__END__
