package LSF::AccountingBase;

use strict;
use warnings;
use Carp;

use Time::Local;
use Math::BigInt;
use File::stat;
use List::Util qw/max min sum/;
use Data::Dumper;

use LSF::Accounting;
use LSF::Groups;
use LSF::CompletedJobInfo;
use LSF::ConfigReader;
use LSF::Util qw/filereadFH findGroup getCommandOutput/;

use constant aMonth => 30 * 24	* 3600;
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  # By default accounting for the last 30 days from now
  my $timenow = time;
  $attr->{start} = $attr->{start} || $timenow - aMonth;
  $attr->{end}   = $attr->{end}   || $timenow;
  croak q|Wrong time window! start=|.$attr->{start}.q|, end=|.$attr->{end}
    unless  $attr->{end} - $attr->{start};

  my $config = LSF::ConfigReader->instance()->config;
  my $use_bugroup = $config->{use_bugroup} || 0;

  my $self = bless { 
    ugDict => ($use_bugroup) ? LSF::Groups->instance({ verbose => 0 })->info : {}
  }, $class;
  $self->{window}{start} = $attr->{start};
  $self->{window}{end}   = $attr->{end}; 

  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  my $config = LSF::ConfigReader->instance()->config;

  croak q|ERROR. acctDir cannot be accessed, stopped| 
     unless defined $config->{accounting}{infoDirList};
}

sub getAcctFiles
{
  my $self = shift;

  my $config = LSF::ConfigReader->instance()->config;
  my $acctDirList = $config->{accounting}{infoDirList} || [];

  my @fileList = ();
  for my $acctDir (@$acctDirList) {
    next unless -d $acctDir;

    # Read all the lsb.acct.* files. This should be done only once
    local *DIR;
    opendir DIR, $acctDir || carp qq|Failed to open directory $acctDir!|;

    # Schwarzian transformation
    push @fileList, map { qq|$acctDir/$_| }
                      grep { /lsb.acct/ }
                         readdir DIR;
    closedir DIR;
  }
  my %dict = map { $_ => -M $_ } @fileList;
  sort { $dict{$b} <=> $dict{$a} } keys %dict;
}

sub parseLine
{
  my ($self, $line, $dict) = @_;
  my $config = LSF::ConfigReader->instance()->config;
  my $skip_root = (exists $config->{accounting}{skip_root} and $config->{accounting}{skip_root}) ? 1 : 0;
  my $queues_toskip = $config->{queues_toskip} || [];
  my $verbose = $config->{accounting}{verbose} || 0;

  my $job = LSF::CompletedJobInfo->new({ line => $line, dict => $dict });
  my $info = $job->info;

  my $jid = $info->{JID};
  my $user = $info->{USER};
  print ">>> USER undefined! INPUT=$line\n" and return unless defined $user;
  return if ($skip_root and $user eq 'root');

  my $queue = $info->{QUEUE};
  return if not defined $queue or grep /$queue/, @$queues_toskip;

  unless (defined $self->{ugDict}{$user}) {
    my $group = undef;
    eval {
      $group = findGroup $user;
    };
    $@ and carp qq|problem finding group for user $user|;
    $self->{ugDict}{$user} = $group if defined $group;
  }
  my $group = $self->{ugDict}{$user} || q|other|;
  carp qq|WARNING. group not found for JID=$jid, USER=$user! setting GROUP=$group, was user created correctly?;| 
    if $group eq q|other|;
  return if ($skip_root and $group eq 'root');

  ### For Alberto Ciampa
  ###return if ($group eq 'cms' and $user ne 'cmsprd');

  my $walltime = $info->{WALLTIME};
  # FIXME. cputime >> walltime indicates a wrong entry
  my $cputime = min($info->{CPUTIME}, $walltime);
  printf "%10s %7.7d %9.1f %9.1f\n", $group, $jid, $walltime, $cputime if $verbose;

  # get the end time and 'wait' period of the job, all in seconds since the epoch
  my $etime = $info->{END};
  my $qtime = $info->{QTIME} || 0;
  my $stime = $info->{START} || 0;

  my $exit_status = $info->{EX_ST};
  my $wtime = ($stime>0 and $qtime>0) ? $stime - $qtime : 0; # waited on the queue
  if ($etime >= $self->{window}{start} and $etime <= $self->{window}{end}) {
    $self->{groupinfo}{$group}{jobs}++;
    $self->{groupinfo}{$group}{sjobs}++ unless $exit_status;
    $self->{groupinfo}{$group}{cputime}  += $cputime;
    $self->{groupinfo}{$group}{walltime} += $walltime;
    $self->{groupinfo}{$group}{waitfor}  += $wtime;

    $self->{userinfo}{$user}{jobs}++;
    $self->{userinfo}{$user}{sjobs}++ unless $exit_status;
    $self->{userinfo}{$user}{cputime}  += $cputime;
    $self->{userinfo}{$user}{walltime} += $walltime;
    $self->{userinfo}{$user}{waitfor}  += $wtime;
  }
}

sub update
{
  my $self = shift;

  my $groupInfo = $self->{groupinfo};

  # get the total walltime and total jobs in each period
  my @groupList = sort keys %$groupInfo;
  my $walltime_t = 0;
  my $njobs_t = 0;
  for my $group (@groupList) {
    $walltime_t += $groupInfo->{$group}{walltime};
    $njobs_t    += $groupInfo->{$group}{jobs};
  }
  for my $group (@groupList) {
    my $walltime = $groupInfo->{$group}{walltime};
    my $cputime  = $groupInfo->{$group}{cputime};
    my $njobs    = $groupInfo->{$group}{jobs};
    my $sjobs    = $groupInfo->{$group}{sjobs} || 0;
    my $srate    = ($njobs) ? $sjobs*1.0/$njobs : 0.0;
    my $avgwait  = ($njobs) ? $groupInfo->{$group}{waitfor}/$njobs : 0; # seconds
    my $cpueff   = ($walltime) ? min(1.0, $cputime/$walltime) : 0.0;
    $cpueff     *= 100;               # convert to percentage
    my $wtshare  = ($walltime_t) ? $walltime*100/$walltime_t : 0.0;

    $groupInfo->{$group}{success_rate}   = $srate;
    $groupInfo->{$group}{cpueff}         = $cpueff;
    $groupInfo->{$group}{walltime_share} = $wtshare;
    $groupInfo->{$group}{avgwait}        = $avgwait;
    $groupInfo->{$group}{job_share}      = ($njobs_t) ? $njobs*100/$njobs_t : 0.0;
  }
  $self->{groupinfo} = $groupInfo;
}

sub showGroups
{
  my $self = shift;
  my $info = $self->{groupinfo};
  printf "%10s %8s %8s %11s %11s %12s %12s %10s %9s %9s\n",
        q|GROUP|,
        q|Jobs|,
        q|SuccJobs|,
        q|SuccRate(%)|,
        q|JobShare(%)|,
        q|Walltime(s)|,
        q|CPUtime(s)|,
        q|WTShare(%)|,
        q|CPUEff(%)|,
        q|AvWait(s)|;
  for my $group (sort { $info->{$b}{walltime} <=> $info->{$a}{walltime} } keys %$info) {
    my $cputime = int($info->{$group}{cputime});
    printf "%10s %8d %8d %11.3f %11.3f %12s %12s %10.3f %9.3f %9d\n",
      $group, 
      $info->{$group}{jobs},
      $info->{$group}{sjobs},
      $info->{$group}{success_rate},
      $info->{$group}{job_share},
      (Math::BigInt->new($info->{$group}{walltime}))->bstr,
      (Math::BigInt->new($cputime))->bstr,
      $info->{$group}{walltime_share},
      $info->{$group}{cpueff},
      $info->{$group}{avgwait};
  }
}

sub showUsers
{
  my $self = shift;
  my $info = $self->{userinfo};
  printf "%16s %8s %8s %11s %12s %12s %10s %9s\n",
        q|User|,
        q|Jobs|,
        q|SuccJobs|,
        q|SuccRate(%)|,
        q|Walltime(s)|,
        q|CPUtime(s)|,
        q|CPUEff(%)|,
        q|AvWait(s)|;
  for my $user (sort { $info->{$b}{walltime} <=> $info->{$a}{walltime} } keys %$info) {
    my $walltime = $info->{$user}{walltime};
    my $cputime  = $info->{$user}{cputime};
    my $cpueff   = ($walltime) ? min(1.0, $cputime/$walltime) : 0.0;
    my $njobs    = $info->{$user}{jobs};
    my $sjobs    = $info->{$user}{sjobs} || 0;
    my $success_rate = ($njobs) ? $sjobs/$njobs : 0;
    my $avgwait  = ($njobs) ? $info->{$user}{waitfor}/$njobs : 0; # seconds

    printf "%16s %8d %8d %11.3f %12s %12s %10.3f %9d\n",
      $user, 
      $njobs,
      $sjobs,
      $success_rate,
      (Math::BigInt->new($info->{$user}{walltime}))->bstr,
      (Math::BigInt->new(int($cputime)))->bstr,
      $cpueff,
      $avgwait;
  }
}

sub collect 
{
  my $self = shift;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;
  my $verbose_g = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my @files = $self->getAcctFiles();
  # Loop over files
  for my $file (@files) {
    # skip files that are way out of the time window
    my $stats = stat $file or carp qq|$file not found, continue|;
    my $mtime = $stats->mtime;
    next if (($self->{window}{start} - $mtime) > 0.5 * aMonth);
    next if (($mtime - $self->{window}{end}) > 0.5 * aMonth);

    # first read the lsb.acct file directly
    my $info = LSF::Accounting->readAcctFile($file);

    # now use bacct to get the rest of the information
    my $jobList = LSF::Accounting->exec_bacct($file);

    for (@$jobList) {
      # We already have the long listing on the job at our disposal
      chop;
      $self->parseLine($_, $info);
    }
  }
  $self->update;
}

sub getEpoch
{
  my ($pkg, $dstr) = @_;
  my ($year, $month, $mday, $time) = (split m#/#, $dstr);  
  my ($hour, $min, $sec) = (defined $time) ? (split /:/, $time): (0,0,0);
  timelocal($sec, $min, $hour, $mday, $month-1, $year);
}

1;
__END__
package main;

# Build start and end times from human readable string like 2009/02/20/15:09:00 [bacct]
my $start = shift;
my $end   = shift;
my $obj = LSF::AccountingBase->new({ 
   start => LSF::AccountingBase->getEpoch($start), 
     end => LSF::AccountingBase->getEpoch($end) 
});
$obj->collect;
$obj->showGroups;
$obj->showUsers;
