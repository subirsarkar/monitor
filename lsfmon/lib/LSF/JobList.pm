package LSF::JobList;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use HTTP::Date;

use LSF::Util qw/trim 
                 commandFH 
                 getCommandOutput 
                 readFile 
                 findGroup
                 storeInfo 
                 restoreInfo 
                 show_message/;
use LSF::ConfigReader;
use LSF::JobInfo;
use LSF::Groups;
use LSF::UserGroup;

$LSF::JobList::VERSION = q|0.1|;

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
    my $config = LSF::ConfigReader->instance()->config;
    my $dbfile = $config->{overview}{bjobs}{dbfile} || qq|$config->{baseDir}/db/bjobs.db|;
    show_message ">>> bjobs -l failed! retrieve information from $dbfile";
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
sub exists
{
  my ($self, $jid) = @_;
  my $dict = $self->{_list};
  exists $dict->{$jid}; 
}
sub jobinfo
{
  my ($self, $jid) = @_;
  my $dict = $self->{_list};
  $dict->{$jid}; 
}
sub show
{
  my $self = shift;
  my $stream = shift || *STDOUT;
  my $joblist = $self->list; # returns a hash reference
  while ( my ($jid,$job) = each %$joblist ) {
    $job->show($stream);
  }
}
sub toString
{
  my $self = shift;
  my $output = q||;
  my $joblist = $self->list; # returns a hash reference
  while ( my ($jid,$job) = each %$joblist ) {
    $output .= $job->toString;
  }
  $output;
}
sub _initialize
{
  my $self = shift;

  my $dict = {};
  $self->list($dict);

  # Read the config in any case
  my $config = LSF::ConfigReader->instance()->config;

  my $verbose_g     = $config->{verbose} || 0;
  my $verbose       = $config->{overview}{verbose} || 0;
  my $time_cmd      = $config->{time_cmd} || 0;
  my $dbfile        = $config->{overview}{bjobs}{dbfile} || qq|$config->{baseDir}/db/bjobs.db|;
  my $max_jobs      = $config->{overview}{bjobs}{max_jobs} || 2000;
  my $queues_toskip = $config->{queues_toskip} || [];
  my $use_bugroup   = $config->{use_bugroup} || 0;
  my $show_error    = $config->{show_cmd_error} || 0;

  # Collect the jobids
  # Running and pending and suspended jobs
  my $ugDict = ($use_bugroup) ? LSF::Groups->instance({ verbose => 0 })->info : {};
  my $time_a = time();
  my $info = {};
  my $command = q|bjobs -w -u all|;
  my $fh = commandFH($command, $verbose_g);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while ( my $line = $fh->getline) {
      my @fields = (split /\s+/, trim $line);
      my ($jid, $user, $status, $queue, $ui) = @fields[0,1,2,3,4];
      $ui = (split m#\@#, $ui)[0];
      next if grep { $_ eq $queue } @$queues_toskip;

      my $host = ($status eq 'RUN') ? $fields[5] : undef;
      my $jname = join(" ", splice(@fields, 6, scalar(@fields)-9));
      my $index = ($jname =~ /(?:.*?)(\[\d+\])$/) ? $1 : undef;
      $jid .= qq|$index| if (defined $index and not $jid =~ /\d+\[\d+\]/);
      carp qq|\$info already contains $jid, parsing wrong!\n| if exists $info->{$jid};

      my $qtime = str2time(join (' ', splice(@fields, -3,3)));
      $info->{$jid} = 
      {
          user => $user, 
        status => $status, 
         queue => $queue, 
            ui => $ui, 
          host => $host
      };

      unless (defined $ugDict->{$user}) {
        my $group = findGroup($user);
        $ugDict->{$user} = [$group];
      }
      # We treat Running jobs differently
      next if $status eq 'RUN';
      my $job = LSF::JobInfo->new;
      $job->JID($jid);      
      $job->USER($user);      
      $job->QUEUE($queue);      
      $job->UI_HOST($ui);
      $job->setStatus($status);      
      # Can we keep all the groups?
      $job->GROUP($ugDict->{$user}[0] || undef);      
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
  return unless $nJobs;

  my @rList = grep { $info->{$_}{status} eq 'RUN' } @jidList;
  my $rJobs = scalar @rList;
  return unless $rJobs;

  my $sep = '-' x 78;
  $time_a = time();
  my $ecode = 0;
  my $b_command = q|bjobs -l -u all |;
  while (my @list = splice @rList, 0, $max_jobs) {
    my $command = $b_command . join(' ', @list);
    print STDERR $command, "\n" if $verbose;
    chop(my $text = getCommandOutput($command, \$ecode, $show_error, $verbose_g));
    last if $ecode;

    my @jobList = (split /$sep/, $text); 
    for my $jInfo (@jobList) {
      # We already have the long listing on the job at our disposal
      my $job = LSF::JobInfo->new;
      $job->parse({
          user => 'all', 
         jobid => undef, 
          text => \$jInfo,  
          info => $info
      });
      my $jobid = $job->JID;
      carp qq|INFO. JID not defined, input:\n$jInfo| and next unless defined $jobid;
  
      my $user = $job->USER;    
      unless (defined $ugDict->{$user}) {
        my $group = findGroup($user);
        $ugDict->{$user} = [$group];
      }
      carp qq|INFO. group not found for JID=$jobid, user=$user, continuing| and next
        unless defined $ugDict->{$user};
      # Only the first group is stored
      $job->GROUP($ugDict->{$user}[0]);
      my $ui = $info->{$jobid}{ui};
      $job->UI_HOST($ui);

      my $walltime = $job->WALLTIME;
      my $cputime  = $job->CPUTIME;
      my $cpuload  = (defined $cputime and defined $walltime and $walltime > 0) 
         ? $cputime*1.0/$walltime
         : undef;
      $job->CPUEFF($cpuload);

      $dict->{$jobid} = $job;
      $job->dump if $verbose;    
    }
  }
  show_message qq|>>> JobList::bjobs -l \@jidList (total=$nJobs,running=$rJobs) |.
    qq|exit code: $ecode; elapsed time = |. (time() - $time_a) . q| second(s)| if $time_cmd;

  # get correct User group
  my $extra_info = LSF::UserGroup->instance()->info;
  for my $jid (keys %$extra_info) {
    next unless exists $dict->{$jid};
    my $job = $dict->{$jid};
    $job->GROUP($extra_info->{$jid}{group});
  }
  # save in a storable in case the above went alright
  storeInfo($dbfile, $dict) unless $ecode;
}

1;
__END__
package main;

my $job = LSF::JobList->new;
$job->show;
