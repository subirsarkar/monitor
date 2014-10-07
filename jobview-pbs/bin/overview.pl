#!/usr/bin/env perl

use strict;
use warnings;

use POSIX qw/strftime/;
use List::Util qw/min max/;
use Template::Alloy;

use Collector::Util qw/trim
                       createHTML
                       createXML
                       createHappyFaceXML
                       createJSON/;
use Collector::ConfigReader;
use Collector::JobView;
use Collector::RRDsys;

$| = 1;

sub create_global_rrd
{
  my $rrdH = shift;
  my $list = ['totalCPU', 'freeCPU', 'runningJobs', 'pendingJobs', 'cpuEfficiency'];
  $rrdH->create($list);
}
sub create_vo_rrd
{
  my $rrdH = shift;
  my $list = ['runningJobs', 'pendingJobs', 'cpuEfficiency'];
  $rrdH->create($list);
}
sub vo_graph
{
  my ($rrdH, $vo) = @_;
  $rrdH->rrdFile(qq|$vo.rrd|);
  my $attr = {
     fields => ['runningJobs', 'pendingJobs'],
     colors => ['#0000ff', '#ff0000'],
    options => ['LINE2', 'LINE2'],
     titles => ['Running', 'Pending'],
     vlabel => qq|$vo Jobs|,
       gtag => qq|jobwtime_$vo|
  };
  $rrdH->graph($attr);
}

sub main
{
  my $jv = new Collector::JobView;
  my $rrdH = new Collector::RRDsys;
  my $jview = {};

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $site  = $config->{site};
  my $batch = $config->{batch};
  my $tmplFile         = $config->{template} || 
                           qq|$config->{baseDir}/tmpl/overview.html.tmpl|;
  my $privacy_enforced = (exists $config->{privacy_enforced}) ? $config->{privacy_enforced} : 1;
  my $groups_dnshown   = $config->{groups_dnshown} || ['cms'];
  my $verbose          = $config->{verbose} || 0;

  my $tt = new Template::Alloy(
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
    batch => uc ($batch),
     date => $str
  };
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;
  $data->{date} = $timestamp;
  $jview->{header} = $data;

  # Resources
  $tt->process_simple(qq|$tmplFile/cpuslots_header|, {title => q|CPU Slots|}, $outref)
    or die $tt->error;
  my $slots = $jv->slotinfo;
  my $slots_av = $slots->{available};
  my $slots_fr = $slots->{free};
  my $row = 
  {
      maxever => $slots->{maxever},
          max => $slots->{max},
    available => $slots_av,
      running => $slots->{running},
         free => $slots_fr
  };
  $jview->{slots} = $row;
  $tt->process_simple(qq|$tmplFile/cpuslots_row|, $row, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/cpuslots_footer|, {}, $outref) or die $tt->error;

  # Overall Jobs
  $tt->process_simple(qq|$tmplFile/jobs_header|, {title => q|Jobs|}, $outref) 
    or die $tt->error;
  my $jobinfo = $jv->jobinfo;
  my $nrun  = $jobinfo->{nrun};
  my $npend = $jobinfo->{npend};
  my $cputime_t  = $jobinfo->{cputime};
  my $walltime_t = $jobinfo->{walltime};
  my $cpueff = ($walltime_t > 0)
       ? sprintf ("%-6.2f", max(0.0, $cputime_t*100.0/$walltime_t))
       : '-';
  my $jobs_leff = $jobinfo->{ratio10};
  $row = 
  {
        jobs => $jobinfo->{njobs},
     running => $nrun,
     pending => $npend,
        held => $jobinfo->{nheld},
     cputime => $cputime_t,
    walltime => $walltime_t,
      cpueff => trim($cpueff),
     ratio10 => $jobs_leff
  };
  $jview->{jobs} = $row;
  $tt->process_simple(qq|$tmplFile/jobs_row|, $row, $outref)  or die $tt->error;
  $tt->process_simple(qq|$tmplFile/jobs_footer|, {}, $outref) or die $tt->error;

  # update RRD
  my $path = $rrdH->rrdFile($config->{rrd}{db});
  warn qq|$config->{rrd}{db} not found, will create now| 
    and create_vo_rrd($rrdH) unless -r $path;
  $rrdH->update([
     $timestamp,
     $slots_av,
     $slots_fr,
     $nrun,
     $npend,
     (($cpueff eq '-') ? 0 : trim($cpueff))
  ]);

  if ($jobinfo->{njobs}) {
    # Group Jobs
    # Get the supported groups for RRD
    my %sgroups = map { $_ => 1 } @{$config->{rrd}{supportedGroups}};
    my $location = $config->{rrd}{location};

    $tt->process_simple(qq|$tmplFile/group_header|, {title => q|Group|}, $outref) 
      or die $tt->error;
    my $groupinfo = $jv->groupinfo;
    for my $group (sort { $groupinfo->{$b}{nrun} <=> $groupinfo->{$a}{nrun} } keys %$groupinfo) {
      my $nrun  = $groupinfo->{$group}{nrun};
      my $npend = $groupinfo->{$group}{npend};
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
                   jobs => $groupinfo->{$group}{njobs},
                running => $nrun,
                pending => $npend,
                   held => $groupinfo->{$group}{nheld},
                cputime => $cputime,
               walltime => $walltime,
                 cpueff => trim($cpueff),
                ratio10 => $jobs_leff,
         walltime_share => trim($walltime_share)
      };
      $tt->process_simple(qq|$tmplFile/group_row|, $row, $outref) or die $tt->error;
      my $vo = delete $row->{group};
      if (defined $vo) {
        $row->{name} = $vo;
        $jview->{grouplist}{group}{$group} = $row;
      }
      next unless exists $sgroups{$group};

      # update VO specific RRDs now
      my $path = $rrdH->rrdFile(qq|$group.rrd|);
      warn qq|$group.rrd not found, will create now| 
        and create_vo_rrd($rrdH) unless -r $path;
      $rrdH->update([
         $timestamp,
         $nrun,
         $npend,
        (($cpueff eq '-') ? 0 : trim($cpueff))
      ]);
      delete $sgroups{$group};
    }
    # Fill with zeros the groups that do currently not have any jobs
    while ( my ($group) = each %sgroups ) {
      my $path = $rrdH->rrdFile(qq|$group.rrd|);
      warn qq|$group.rrd not found, will create now| and create_vo_rrd($rrdH) unless -r $path;
      $rrdH->update([$timestamp, 0, 0, 0]);
    }
    $tt->process_simple(qq|$tmplFile/group_footer|, {}, $outref) or die $tt->error;
    
    # CE Jobs
    my $show_ces = (exists $config->{show_table}{ce}) 
       ? $config->{show_table}{ce} : 1;
    if ($show_ces) {
      $tt->process_simple(qq|$tmplFile/ce_header|, {title => q|Computing Element|}, $outref) 
        or die $tt->error;
      my $ceinfo = $jv->ceinfo;
      for my $ce (sort { $ceinfo->{$b}{nrun} <=> $ceinfo->{$a}{nrun} } keys %$ceinfo) {
        my $cputime  = $ceinfo->{$ce}{cputime};
        my $walltime = $ceinfo->{$ce}{walltime};
        my $cpueff = ($walltime > 0)
           ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
           : '-';
        my $jobs_leff = $ceinfo->{$ce}{ratio10};
        my $row = 
        {
                 ce => $ce,
               jobs => $ceinfo->{$ce}{njobs},
            running => $ceinfo->{$ce}{nrun},
            pending => $ceinfo->{$ce}{npend},
               held => $ceinfo->{$ce}{nheld},
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
  # Now for all the supported VOs
  my $options;
  for my $grp ('all', @{$config->{rrd}{supportedGroups}}) {
    $options .= qq|<option value="$grp">$grp</option>\n|;
  }
  $tt->process_simple(qq|$tmplFile/image_block|, 
     {options => $options}, $outref) or die $tt->error;

  if ($jobinfo->{njobs}) {
    # Now User jobs
    my $show_user = $config->{show_table}{user} || 0;
    if ($show_user) {
      my $userinfo = $jv->userinfo;
      my @users = keys %$userinfo;
      $tt->process_simple(qq|$tmplFile/dn_header|, {title => q|User DN|}, $outref) 
        or die $tt->error;
      # Grid users
      for my $dn (sort { $userinfo->{$b}{nrun} <=> $userinfo->{$a}{nrun} } @users) {
        $dn eq $userinfo->{$dn}{user} and next;
        my $group = $userinfo->{$dn}{group};
        next if ($privacy_enforced and not grep { $_ eq $group } @$groups_dnshown);
        my $cputime  = $userinfo->{$dn}{cputime};
        my $walltime = $userinfo->{$dn}{walltime};
        my $cpueff = ($walltime > 0)
           ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
           : '-';
        my $jobs_leff = $userinfo->{$dn}{ratio10};
        my $row = 
        {
          localuser => $userinfo->{$dn}{user},
              group => $userinfo->{$dn}{group},
               jobs => $userinfo->{$dn}{njobs},
            running => $userinfo->{$dn}{nrun},
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
      # local users
      my $show_localusers = $config->{show_table}{localuser} || 0;
      if ($show_localusers) {
        for my $dn (sort { $userinfo->{$b}{nrun} <=> $userinfo->{$a}{nrun} } @users) {
          $dn eq $userinfo->{$dn}{user} or next;
          my $cputime  = $userinfo->{$dn}{cputime};
          my $walltime = $userinfo->{$dn}{walltime};
          my $cpueff = ($walltime > 0)
             ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
             : '-';
          my $jobs_leff = $userinfo->{$dn}{ratio10};
          my $row = {
            localuser => $userinfo->{$dn}{user},
                group => $userinfo->{$dn}{group},
                 jobs => $userinfo->{$dn}{njobs},
              running => $userinfo->{$dn}{nrun},
              pending => $userinfo->{$dn}{npend},
                 held => $userinfo->{$dn}{nheld},
              cputime => $cputime,
             walltime => $walltime,
               cpueff => trim($cpueff),
              ratio10 => $jobs_leff,
                   dn => '-'
          };
          $tt->process_simple(qq|$tmplFile/dn_row|, $row, $outref) or die $tt->error;
        }
      }
      $tt->process_simple(qq|$tmplFile/dn_footer|, {}, $outref) or die $tt->error;
    }
  }
  # Fair Share
  my $priority = $jv->priority;
  if (defined $priority) {
    $tt->process_simple(qq|$tmplFile/priority|, { priority => $priority }, $outref)
      or die $tt->error;
    $jview->{priority} = {share => $priority}; 
  }
  # finally the page footer
  my $app_v = $config->{jobview_version} || q|1.0.0|;
  my $link = $config->{doc} || q|http://sarkar.web.cern.ch/sarkar/doc/pbs_jobview.html|;
  $tt->process_simple(qq|$tmplFile/page_footer|, { jobview_version => $app_v, doc => $link }, $outref)
    or die $tt->error;

  # Dump the html content in a file 
  my $htmlFile = $config->{html} || qq|$config->{baseDir}/html/overview.html|;
  createHTML($htmlFile, $output);

  # Dump the overall collection
  print Data::Dumper->Dump([$jview], [qw/jview/]) if $verbose;

  # prepare an XML file
  my $saveXML = $config->{xml}{save} || 0;
  if ($saveXML) {
    my $file = $config->{xml}{file} || qq|$config->{baseDir}/html/overview.xml|;
    createXML($file, $jview, {ce => 'name', dn => 'name', group => 'name'}, 'jobview');
  }
  $saveXML = $config->{xml_hf}{save} || 0;
  $saveXML and createHappyFaceXML($jview, $config, { joblist => $jv->{_overview}->{_joblist} });

  # JSON
  my $saveJSON = $config->{json}{save} || 0;
  if ($saveJSON) { 
    my $file = $config->{json}{file} || qq|$config->{baseDir}/html/overview.json|;
    createJSON($file, $jview, 'jobview');
  }

  # Now prepare the RRD graphs
  # resources
  $rrdH->rrdFile($config->{rrd}{db});
  my $attr = 
  {
     fields => ['totalCPU', 'freeCPU'],
     colors => ['#0022e9', '#00b871'],
    options => ['LINE2', 'LINE2'],
     titles => ['  Total', '   Free'],
     vlabel => q|CPU Availability|,
       gtag => q|cpuwtime|
  };
  $rrdH->graph($attr);

  # jobs
  $attr = 
  {
     fields => ['runningJobs', 'pendingJobs'],
     colors => ['#0000ff', '#ff0000'],
    options => ['LINE2', 'LINE2'],
     titles => ['Running', 'Pending'],
     vlabel => q|Jobs|,
       gtag => q|jobwtime|
  };
  $rrdH->graph($attr);

  # Now for all the supported GROUPs
  for my $group (@{$config->{rrd}{supportedGroups}}) {
    vo_graph($rrdH, $group);
  }
}

# Execute
main;
__END__
