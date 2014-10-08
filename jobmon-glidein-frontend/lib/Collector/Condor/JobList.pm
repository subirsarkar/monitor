package Collector::Condor::JobList;

use strict;
use warnings;
use Carp;
use Storable;
use POSIX qw/strftime/;
use Data::Dumper;
use List::Util qw/min/;

use Collector::ConfigReader;
use Collector::Condor::JobInfo;
use Collector::Util qw/trim 
                       show_message
                       commandFH
                       getCommandOutput 
                       readFile 
                       storeInfo
                       restoreInfo
                       findGroup/;

use base 'Collector::JobList';
$Collector::Condor::JobList::VERSION = qq|0.1|;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = $class->SUPER::new;
  bless $self, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize
{
  my ($self, $attr) = @_;
  my $dict = {};

  # Read the config in any case
  my $config = Collector::ConfigReader->instance()->config;
  my $collector  = $config->{collector};
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist = qq| -name $_| for (@$scheddList);

  my $verbose    = $config->{verbose} || 0;
  my $time_cmd   = $config->{time_cmd} || 0;
  my $show_error = $config->{show_cmd_error} || 0;
  my $remove_role = $config->{remove_role} || 0;

  # Running jobs

  # time the Condor command execution
  my $time_a = time();
  my $ugDict = {};
  my $nRun = 0;
  my $command = Collector::Condor::JobInfo->runningJobs;
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      my $job = Collector::Condor::JobInfo->new;
      $job->parse({ text => $line, parse_running => 1, ugdict => $ugDict });
      $dict->{$job->JID} = $job;
      ++$nRun;
    }
    $fh->close;
  }
  show_message q|>>> JobList::condor_q -r: elapsed time = |. (time() - $time_a) . q| second(s)|
    if $time_cmd;

  # Add missing information using condor_status 
  $time_a = time();
  $command = <<"END"; 
condor_status -pool $collector \\
      -format "%s!" GlobalJobId \\
      -format "%V!" TotalJobRunTime \\
      -format "%V!" GLIDEIN_Gatekeeper \\
      -format "%V!" GLIDEIN_CMSSite \\
      -format "%V\\n" TotalCondorLoadAvg \\
END
  $command .=  q| -constraint 'State=="Claimed"'|;
  $command .= qq| -constraint '$config->{constraint}{condor_status}'| 
      if defined $config->{constraint}{condor_status};
  print $command, "\n";

  $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      next if $line =~ /^$/;
      $line =~ s/"//g;

      my ($jid, $walltime, $gatekeeper, $cms_site, $load) 
        = (split /!/, trim $line);
      #carp qq|INFO. $jid not found!| and next unless defined $dict->{$jid};
      next unless defined $dict->{$jid};

      my $job = $dict->{$jid};
      $walltime eq 'undefined' and $walltime = 0;
      my $cputime = min $walltime, $job->CPUTIME;
      $job->CPUTIME($cputime);

      my $cpuload = ($walltime > 0) ? $job->CPUTIME*1.0/$walltime : 0.0;
      $cpuload = sprintf "%.3f", $cpuload;
      printf qq|JID=%s,status=%s,cputime=%d,walltime=%d,cpuload=%s,gw=%s,site=%s\n|,
         $jid, $job->STATUS,
               $job->CPUTIME,
               $walltime,
               $cpuload, 
               $gatekeeper,
               $cms_site if $verbose>1;
      $job->CPULOAD($cpuload);
      $job->WALLTIME($walltime);
      $job->GATEKEEPER($gatekeeper);
      $job->GRID_SITE($cms_site);
      $job->GRID_CE($gatekeeper);

      # We cannot really add the gcb here. we must find a new field
      $job->dump if $verbose>1;
    }
    $fh->close;
  }
  show_message qq|>>> JobList::condor_status: elapsed time = |. (time() - $time_a) . qq| second(s)|
    if $time_cmd;

  # Now look for pending, Held jobs
  my $nJobs = $nRun;
  $time_a = time();
  $command = Collector::Condor::JobInfo->pendingJobs;
  $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      my $job = Collector::Condor::JobInfo->new;
      $job->parse({ text => $line, parse_running => 0, ugdict => $ugDict });
      $dict->{$job->JID} = $job;
      $job->dump if $verbose>1;

      ++$nJobs;
    }
    $fh->close;
  }
  show_message qq|>>> JobList::condor_q: elapsed time = |. (time() - $time_a) . qq| second(s)|
    if $time_cmd;
  show_message qq|>>> Processed nJobs=$nJobs, nRun=$nRun|;

  if (scalar keys %$dict) {
    # save in a storable
    my $dbfile = $config->{db}{jobinfo} || qq|$config->{baseDir}/jobmon/data/jobinfo.db|;
    storeInfo($dbfile, $dict);
  }
  else {
    # Read the values from last iteration
    my $reader = Collector::ConfigReader->instance();
    my $config = $reader->config;
    my $dbfile = $config->{db}{jobinfo} || qq|$config->{baseDir}/jobmon/data/jobinfo.db|;
    show_message qq|>>> condor_q [-l] failed! retrieve information from $dbfile|;
    $dict = restoreInfo($dbfile);
  }
  $self->joblist($dict);
}

1;
__END__
