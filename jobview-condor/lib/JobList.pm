package JobList;

use strict;
use warnings;
use Carp;
use Storable;
use POSIX qw/strftime/;
use Data::Dumper;
use List::Util qw/min/;

use ConfigReader;
use JobInfo;
use Util qw/trim 
            show_message
            commandFH
            getCommandOutput 
            readFile 
            storeInfo
            restoreInfo
            findGroup/;

$JobList::VERSION = q|0.1|;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = bless {
   _list => {}
  }, $class;

  $self->_initialize($attr);
  my $dict = $self->list;
  unless (scalar keys %$dict) {
    # Read the values from last iteration
    my $reader = ConfigReader->instance();
    my $config = $reader->config;
    my $dbfile = $config->{db}{jobinfo} || qq|$config->{baseDir}/db/jobinfo.db|;
    show_message qq|>>> condor_q [-l] failed! retrieve information from $dbfile|;
    $self->list(restoreInfo($dbfile));
  }
  $self;
}

sub list
{
  my $self = shift;
  if (@_) {
    return $self->{_list} = shift;
  } 
  else {
    return $self->{_list};
  }
}
sub show
{
  my $self = shift;
  my $stream = shift || *STDOUT;
  my $joblist = $self->list; # returns a hash reference
  for my $job (values %$joblist) {
    $job->show($stream);
  }
}

sub toString
{
  my $self = shift;
  my $output = q||;
  my $joblist = $self->list; # returns a hash reference
  for my $job (values %$joblist) {
    $output .= $job->toString;
  }
  $output;
}
sub _initialize
{
  my ($self, $attr) = @_;

  my $dict = {};
  $self->list($dict);

  # Read the config in any case
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $collector  = $config->{collector};
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist = qq| -name $_| for (@$scheddList);
  my $verbose    = $config->{verbose} || 0;
  my $time_cmd   = $config->{time_cmd} || 0;
  my $show_error = $config->{show_cmd_error} || 0;
  my $run_offline = $config->{run_offline} || 0;

  # time the Condor command execution
  # We should call condor_q -l only for running jobs
  my $time_a = time();
  my $nRun = 0;
  my $ugDict = {};
  my $command;
  if ($run_offline) {
    my $file = $config->{db}{dump}{condorq_r} || qq|$config->{baseDir}/db/condorq_r.list|;
    $command = qq|cat $file|;
  }
  else {
    $command = JobInfo->runningJobs;
  } 
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      my $job = JobInfo->new;
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
  if ($run_offline) {
    my $file = $config->{db}{dump}{condor_status_r} || qq|$config->{baseDir}/db/condor_status_r.list|;
    $command = qq|cat $file|;
  }
  else {
    $command = <<"END";
condor_status -pool $collector \\
       -format "%s!" GlobalJobId \\
       -format "%V!" TotalJobRunTime \\
       -format "%V\\n" TotalCondorLoadAvg \\
END
    $command .=  q| -constraint 'State=="Claimed" && Activity=="Busy"'|;
    $command .= qq| -constraint '$config->{constraint}{condor_status}'| 
      if defined $config->{constraint}{condor_status};
  }
  print $command, "\n";

  $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      next if $line =~ /^$/;
      my ($jid, $walltime, $avgload) = (split /!/, trim $line);

      $jid = join '_', (split /#/, $jid);
      next unless defined $dict->{$jid};

      my $job = $dict->{$jid};

      $walltime eq 'undefined' and $walltime = 0;
      if ($job->NCORE == 1) {
        my $cputime = min $walltime, ($job->CPUTIME || 0);
        $job->CPUTIME($cputime);
      }
      my $cpuload = ($walltime > 0) ? $job->CPUTIME*1.0/$walltime : 0.0;
      $cpuload /= $job->NCORE;
      $cpuload = sprintf "%.3f", $cpuload;
      printf qq|JID=%s,status=%s,ncore=%d,cputime=%d,walltime=%d,cpuload=%.3f\n|,
         $jid, $job->STATUS, 
               $job->NCORE,
               $job->CPUTIME,
               $walltime,
               $cpuload if $verbose>1;
      $job->CPULOAD($cpuload);
      $job->WALLTIME($walltime);

      $job->dump if $verbose>1;
    }
    $fh->close;
  }
  show_message q|>>> JobList::condor_status: elapsed time = |. (time() - $time_a) . q| second(s)|
    if $time_cmd;

  # Now queued and held jobs
  my $nJobs = $nRun;
  $time_a = time();
  if ($run_offline) {
    my $file = $config->{db}{dump}{condorq_p} || qq|$config->{baseDir}/db/condorq_p.list|;
    $command = qq|cat $file|;
  }
  else {
    $command = JobInfo->pendingJobs;
  } 
  $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      my $job = JobInfo->new;
      $job->parse({ text => $line, parse_running => 0, ugdict => $ugDict });
      $dict->{$job->JID} = $job;
      $job->dump if $verbose>1;

      ++$nJobs;
    }
    $fh->close;
  }
  show_message q|>>> JobList::condor_q: elapsed time = |. (time() - $time_a) . q| second(s)|
    if $time_cmd;
  show_message qq|>>> Processed nJobs=$nJobs,nRun=$nRun|;

  # save in a storable
  my $dbfile = $config->{db}{jobinfo} || qq|$config->{baseDir}/db/jobinfo.db|;
  storeInfo($dbfile, $dict);

  print Data::Dumper->Dump([$ugDict], [qw/ugDict/]) if $verbose;
}

1;
__END__
package main;
my $job = JobList->new;
$job->show;
