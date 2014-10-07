package Collector::PBS::JobList;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Date::Manip;
use POSIX qw/strftime/;
use List::Util qw/min max/;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       show_message
                       getCommandOutput 
                       storeInfo
                       restoreInfo
                       findGroup/;
use Collector::JobList;
use Collector::PBS::JobInfo;

use base 'Collector::JobList';

$Collector::PBS::JobList::VERSION = q|1.0|;

our $statusAttr = 
{
   R => q|running|,
   Q => q|pending|,
   W => q|waiting|,
   H => q|held|,
   C => q|exited|
};
our $parserDict = 
{ 
   gridmap => q|Collector::PBS::GridmapReader|,
    jobdef => q|Collector::PBS::JobdefParser|,
  external => q|Collector::PBS::MyMapReader|
};

sub convert_kb;
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();  
  bless $self, $class;

  $self->_initialize(); # must tell the interpreter that we have a function call
  my $dict = $self->list;
  unless (scalar keys %$dict) {
    # Read the values from last iteration
    my $reader = Collector::ConfigReader->instance();
    my $config = $reader->config;
    my $dbfile = $config->{db}{jobinfo};
    show_message qq|>>> qstat -f failed! retrieve information from $dbfile|;
    $self->list(restoreInfo($dbfile));
  }
  $self;
}

sub _initialize
{
  my $self = shift;

  my $dict = {};
  $self->list($dict);

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose      = $config->{verbose} || 0;
  my $show_error   = $config->{show_cmd_error} || 0;
  my $server_as_ce = $config->{server_as_ce} || 0;
  my $time_cmd     = $config->{time_cmd} || 0;

  my $option = $config->{dnmap_option} || 'gridmap';
  my $class = $parserDict->{$option};
  defined $class or croak qq|Unrecognised Parser option $option!|;

  # get JID-DN mapping
  my $parser = Collector::ObjectFactory->instantiate($class);
  my $dnmap = $parser->dnmap;
  $verbose and print Data::Dumper->Dump([$dnmap], [qw/dnmap/]);

  # Get running and queued jobs
  my $time_a = time();
  my $command = q|qstat -f|;
  my $ecode;
  chop(my $text = 
    getCommandOutput($command, \$ecode, $show_error, $verbose));
  show_message q|>>> JobList: qstat -f elapsed time = |. (time() - $time_a) . q| second(s)|
    if $time_cmd;
	
  my @jobList = split /Job Id: +/, $text;
  shift @jobList; # The first element is empty by construction
  my $nJobs = scalar @jobList;
  return unless $nJobs;

  my $ugDict = {};
  my $nRun = 0;  
  for my $jobInfo (@jobList) {
    my @lines = map { trim $_ } 
                  grep { $_ if length($_)>0 }
                    (split /\n/, $jobInfo);
    my $jid = shift @lines;
    $jid =~ s/\..*//;

    my $jinfo = {};
    for my $line (@lines) {
      my ($key, $value) = (split m#\s+=\s+#, trim $line);
      defined $key or next;
      $value = '?' unless (defined $value and length $value);
      $jinfo->{$key} = $value;
    }
    my $job = new Collector::PBS::JobInfo;
    my ($user, $ce) = (split /\@/, $jinfo->{Job_Owner});
    unless (defined $ugDict->{$user}) {
      my $group = findGroup $user;
      $ugDict->{$user} = $group;
    }
    my $subject = $dnmap->{$jid} || $user;
    $job->JID($jid);
    $job->SUBJECT($subject);
    $job->GRID_CE(($server_as_ce) ? $jinfo->{server} : $ce);
    $job->GROUP($ugDict->{$user});
    $job->QUEUE($jinfo->{queue});
    $job->USER($user);
    my $status = $jinfo->{job_state};
    $job->STATUS($status);
    $job->LSTATUS($statusAttr->{$status} || undef);
    $job->QTIME(UnixDate(ParseDate($jinfo->{qtime}), "%s"));
    if ($job->STATUS eq 'R') {
      my $start_time = (exists $jinfo->{start_time}) ? $jinfo->{start_time} : $jinfo->{mtime};
      $job->START(UnixDate(ParseDate($start_time), "%s"));
      my $host = $jinfo->{exec_host} || undef;
      if (defined $host) {
        $host = (split m#/#, $host)[0];
        $host = (split m#\.#, $host)[0];
      }
      $job->EXEC_HOST($host); 
      $job->CPUTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.cput'}), 0, "%st") || 0);
      $job->WALLTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.walltime'}), 0, "%st") || 0);
      $job->MEM(convert_kb($jinfo->{'resources_used.mem'}));
      $job->VMEM(convert_kb($jinfo->{'resources_used.vmem'}));
      
      my $walltime = $job->WALLTIME;
      my $cputime = min $walltime, $job->CPUTIME;
      $job->CPUTIME($cputime);
      my $cpuload = ($walltime > 0) ? $job->CPUTIME*1.0/$walltime : 0.0;
      $job->CPUEFF($cpuload);
      ++$nRun; 
    }
    # no need to set END and EX_ST
    $dict->{$job->JID} = $job;
  }
  show_message q|>>> JobList: Parser elapsed time = |. (time() - $time_a) . q| second(s)|
    if $time_cmd;
  show_message qq|>>> Processed nJobs=$nJobs,nRun=$nRun|;

  # save in a storable
  my $dbfile = $config->{db}{jobinfo};
  storeInfo($dbfile, $dict);
}
sub convert_kb
{
  my $mem = shift;
  return -1 unless $mem;
  $mem =~ s/kb$//;
  $mem;
}

1;
__END__
