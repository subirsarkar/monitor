package Collector::LSF::JobList;

use strict;
use warnings;
use Carp;
use POSIX qw(strftime);
use Data::Dumper;
use HTTP::Date;

use Collector::Util qw/trim 
                       show_message
                       getHostname 
                       getCommandOutput 
                       commandFH
                       readFile 
                       findGroup/;
use Collector::ConfigReader;
use Collector::LSF::JobInfo;
use Collector::LSF::CompletedJobInfo;
use base 'Collector::JobList';

$Collector::LSF::JobList::VERSION = q|1.0|;

use constant MINUTE => 60;
our $period =  60 * MINUTE; # hour

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize;
  $self;
}

sub fillAccounting
{
  my ($content, $file, $lines) = @_;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  my $command = qq|tail -$lines $config->{acctDir}/$file|;
  my $fh = commandFH($command, $verbose);
  return unless defined $fh;
  while (<$fh>) {
    push @$content, $_;
  }
  $fh->close;
}
sub readAccountingFiles
{
  my $class = shift;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $content = [];
  my $max_lines = 5000;

  fillAccounting($content, 'lsb.acct', $max_lines);
  
  my $nlines = $max_lines - scalar @$content;
  fillAccounting($content, 'lsb.acct.1', $nlines) if $nlines > 0;

  $content;
}

sub _initialize
{
  my $self = shift;

  my $dict = {};
  $self->joblist($dict);

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $verbose       = $config->{verbose} || 0;
  my $show_error    = $config->{show_cmd_error} || 0;
  my $time_cmd      = (exists $config->{time_cmd}) ? $config->{time_cmd} : 1;
  my $queues_toskip = $config->{queues_toskip} || [];
  my $max_jobs      = 2000;
  my $use_bugroup   = 0;
  
  # Hostname is needed in order to select jobs only for this CE 
  my $host = getHostname();

  # Collect the jobids
  # Running and Pending jobs
  my $ugDict = ($use_bugroup) ? Collector::LSF::Groups->instance({ verbose => 0 })->info : {};
  my $time_a = time();
  my $info = {};
  my $command = q|bjobs -w -u all|;
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while ( my $line = $fh->getline) {
      my @fields = (split /\s+/, trim $line);
      my ($jid, $user, $status, $queue, $ce) = @fields[0,1,2,3,4];
      next unless (defined $ce and $host eq $ce);
      next if grep { $_ eq $queue } @$queues_toskip;

      my ($host, $jname) = ($status eq 'RUN') ? @fields[5,6] : (undef, $fields[-4]);
      my $index = ($jname =~ /(?:.*?)(\[\d+\])$/) ? $1 : undef;
      $jid .= qq|$index| if defined $index;
      carp qq|\$info already contains $jid, parsing wrong!\n| if exists $info->{$jid};

      my $qtime = str2time(join (' ', splice(@fields, -3,3)));
      $info->{$jid} =
      {
          user => $user,
        status => $status,
         queue => $queue,
            ce => $ce,
          host => $host
      };
      unless (defined $ugDict->{$user}) {
        my $group = findGroup($user);
	$ugDict->{$user} = $group;
      }
      # We treat Running jobs differently
      next if $status eq 'RUN';
      my $job = new Collector::LSF::JobInfo;
      $job->JID($jid);
      $job->USER($user);
      $job->QUEUE($queue);
      $job->setStatus($status);
      $job->GROUP($ugDict->{$user} || undef);
      $job->QTIME($qtime);

      $dict->{$jid} = $job;
      $job->dump if $verbose;
    }
    $fh->close;
  }
  show_message q|>>> JobList::bjobs -w -u all elapsed time = |.
      (time() - $time_a) . q| second(s)| if $time_cmd;
  print Data::Dumper->Dump([$info], [qw/info/]) if $verbose;

  my @jidList = keys %$info;
  my $nJobs = scalar @jidList;

  my @rList = grep { $info->{$_}{status} eq 'RUN' } @jidList;
  my $rJobs = scalar @rList;

  my $sep = '-' x 78;
  $time_a = time();
  my $ecode = 0;
  my $b_command = q|bjobs -l -u all |;
  while (my @list = splice @rList, 0, $max_jobs) {
    my $command = $b_command . join(' ', @list);
    print STDERR $command, "\n" if $verbose;
    chop(my $text = getCommandOutput($command, \$ecode, $show_error, $verbose));
    next if $ecode;

    my @jobList = (split /$sep/, $text);
    for my $jInfo (@jobList) {
      # We already have the long listing on the job at our disposal
      my $job = new Collector::LSF::JobInfo;
      $job->parse({
        text => \$jInfo,
        info => $info
      });
      my $jobid = $job->JID;
      carp qq|INFO. JID not defined, input:\n$jInfo| and next unless defined $jobid;

      my $user = $job->USER;
      unless (defined $ugDict->{$user}) {
	my $group = findGroup($user);
	$ugDict->{$user} = $group;
      }
      carp qq|INFO. group not found for JID=$jobid, user=$user, continuing|
	unless defined $ugDict->{$user};
      $job->GROUP($ugDict->{$user});
      $dict->{$jobid} = $job;
      $job->dump if $verbose;
    }
  }
  show_message qq|>>> JobList::bjobs -l \@jidList (total=$nJobs,running=$rJobs) |.
      qq|exit code: $ecode; elapsed time = |. (time() - $time_a) . q| second(s)| if $time_cmd;

  # Finished Jobs
  # Now get content of the lsb.acct.[1] files
  my @content = @{__PACKAGE__->readAccountingFiles()};

  # Build a (JID,data) map
  my $jmap = {};
  for my $l (@content) {
    my $jid = (split /\s+/, $l)[3];
    $jmap->{$jid} = $l;
  }

  # now bhist
  my $timenow = time();
  my $now  = strftime('%Y/%m/%d/%H:%M', localtime($timenow));
  my $then = strftime('%Y/%m/%d/%H:%M', localtime($timenow - $period));
  $command = qq|bhist -w -u all -C$then,$now|;
  print STDERR $command, "\n" if $config->{verbose};
  $fh = commandFH($command, $verbose);
  if (defined $fh) {
    $fh->getline for (0..1);
    while ( my $line = $fh->getline) {
      next if $line =~ /$^/;
      my $jid = (split /\s+/, $line)[0];
      next unless defined $jid;
      carp qq|JID $jid not an integer!| and next unless $jid =~ /\d+/;

      # now check if the jobid appears in the accounting file
      print STDERR qq|INFO. bhist finds JID=$jid status=DONE, but not yet noted in lsb.acct!\n|
        and next unless defined $jmap->{$jid};
      my $line = $jmap->{$jid};
      my $job = new Collector::LSF::CompletedJobInfo({
             jid => int($jid), 
            line => $line,
         verbose => $verbose
      });
      # Cludge accept jobs submitted thru' this CE
      $job->CE eq $host or next;
      my $user = $job->USER;
      unless (defined $ugDict->{$user}) {
        my $group = findGroup($user);
        $ugDict->{$user} = $group;
      }
      defined $ugDict->{$user} or print STDERR qq|INFO. group not found for user $user|;
      $job->GROUP($ugDict->{$user});
      $job->STATUS('E');
      $dict->{$job->JID} = $job;
    }
    $fh->close; 
  }
}

1;
__END__
package main;

my $job = new Collector::LSF::JobList;
$job->show;
