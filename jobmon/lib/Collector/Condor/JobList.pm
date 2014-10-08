package Collector::Condor::JobList;

use strict;
use warnings;
use Carp;
use POSIX qw(strftime);

use Collector::ConfigReader;
use Collector::JobList;
use Collector::Condor::JobInfo;
use Collector::Util qw/trim getHostname getCommandOutput readFile findGroup/;

use base 'Collector::JobList';
our $VERSION = qq|0.1|;

use constant MINUTE => 60;
our $period = 30 * MINUTE;

sub new($$)
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize($$) 
{
  my ($self, $attr) = @_;

  my $dict = {};
  $self->joblist($dict);

  my $user  = (exists $attr->{user}  && $attr->{user}  !~ /^all$/) ? "-submitter $attr->{user}"    : qq||;
  my $state = (exists $attr->{state} && $attr->{state} !~ /^$/ )   ? "State == $attr->{state} && " : qq||;

  # Read the config in any case
  my $reader = new Collector::ConfigReader;
  my $config = $reader->config;
  my $domain = $config->{domain};

  # Hostname is needed in order to select jobs only for this CE 
  my $host = getHostname();

  # Collect the jobids
  # Running and Pending jobs
  my $rid = [];
  if (exists $attr->{idlist}) {
    $rid = $attr->{idlist};
  }
  else {
    my $command = qq|condor_q -global $user -constraint|;
    $command   .= qq| "$state substr(RemoteHost,6) == \\"$host.$domain\\"" -format "%d." ClusterID -format "%d\\n" ProcID|;
    chomp(my @jobList = getCommandOutput($command));

    # Now find only those jobs that belong to this CE
    my @jidList = [ map {(split)[0]} 
                      grep {//} @jobList ];
    $rid = \@jidList;
  }

  my $command = qq|condor_q -global $user -constraint "$state substr(RemoteHost,6) == \\"$host.$domain\\"" -l|;
  $command   .= qq| @$rid| if defined $rid;
  print STDERR $command, "\n" if $config->{verbose};
  
  chop(my $text = getCommandOutput($command));
  my $sep = 'MyType = "Job"';
  my @jobList = split /$sep/, $text; 
 
  my $ugDict = {};
  for my $jInfo (@jobList) {
    # We already have the long listing on the job at our disposal
    my $job = new Collector::Condor::JobInfo({user => $user, jobid => undef, text => \$jInfo});
    my $userL = $job->USER;    
    unless (exists $ugDict->{$userL}) {
      my $group = findGroup($userL);
      $ugDict->{$userL} = $group;
    }
    $job->GROUP($ugDict->{$userL});
    $dict->{$job->JID} = $job;
  }

  # Finished Jobs
  my @content = {};
  my $now  = localtime ();
  my $then = localtime(time() - $period);
  my $userH = (exists $attr->{user})  ? "Owner == \"$attr->{user}\" && " : qq||;
  $command  = qq|condor_history -global -constraint|;
  $command .= qq| "$userH $state CompletionDate >= $then && substr(RemoteHost,6) == \\"$host.$domain\\"" -l |;
  print STDERR $command, "\n" if $config->{verbose};
  chop(my $textH = getCommandOutput($command));
  my @jobListH = split /$sep/, $textH;

  for my $jInfoL (@jobListH) {
    # We already have the long listing on the job at our disposal
    my $jobL = new Collector::Condor::JobInfo({user => $user, jobid => undef, text => \$jInfoL});
    my $userL = $jobL->USER;
    unless (exists $ugDict->{$userL}) {
      my $groupL = findGroup($userL);
      $ugDict->{$userL} = $groupL;
    }
    $jobL->GROUP($ugDict->{$userL});
    $dict->{$jobL->JID} = $jobL;
  }
}

1;
__END__
package main;
my $job = new Collector::Condor::JobList;
$job->show;
