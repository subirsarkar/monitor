package Collector::PBS::JobList;

use strict;
use warnings;
use Carp;
use Date::Manip;
use Net::Domain qw/hostname hostfqdn/;
use POSIX qw/strftime/;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       readFile
                       getCommandOutput 
                       findGroup/;
use base 'Collector::JobList';
use Collector::PBS::JobInfo;

$Collector::PBS::JobList::VERSION = q|1.0|;
use constant MINUTE => 60;
our $period = 30 * MINUTE;

sub convert_kb;
sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();  
  bless $self, $class;

  $self->_initialize(); # must tell the interpreter that we have a function call
  $self;
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
  my $queues_toskip = $config->{queues_toskip} || [];

  my $celist    = $config->{site_ce}{list} || [];
  my $multi_ce  = (scalar @$celist > 1) ? 1 : 0;  
  my $master_ce = $config->{site_ce}{master};
  carp q|Master CE undefined on a multiple CE system, local jobs will not be available| 
    if ($multi_ce and not defined $master_ce);
  $master_ce = (split /\./, lc $master_ce)[0] if defined $master_ce;
  my $host = lc hostname; # short name
  my $iam_master = ($multi_ce) ? ((defined $master_ce and $host eq $master_ce) ? 1 : 0)
                               : 1;
  @$celist = map { lc $_ }
               map { (split /\./)[0] }
                 @$celist if scalar @$celist;

  # Get priority and rank of queued jobs
  my $command = q|diagnose -p|;
  my $ecode = 0;
  chomp(my @prioList = getCommandOutput($command, \$ecode, $show_error, $verbose));
  my $rank = 1;
  my $prioDict = {};
  my $rankDict = {};
  for (@prioList) {
    if (/^([0-9]+)\s+([0-9\-]+)/) {
      $prioDict->{$1} = $2;
      $rankDict->{$1} = $rank;
      $rank++;
    }
  }

  # Get running and queued jobs
  $host = lc hostfqdn;
  my $jobList = __PACKAGE__->qstat_f;
  my $ugDict = {};
  for my $jobInfo (@$jobList) {
    my @lines = map { trim $_ }   # that's schwartzian transformation
                  grep { $_ if length($_)>0 }
                    (split /\n/, $jobInfo);
    my $jid = shift @lines;
    $jid = (split /\./, $jid)[0];

    my $jinfo = {};
    for (@lines) {
      my ($key, $value) = (split m#\s+=\s+#);
      next unless defined $value;
      $jinfo->{$key} = $value;
    }
    next if (defined $jinfo->{queue} and 
       grep { $_ eq $jinfo->{queue} } @$queues_toskip);

    # Multiple CE system
    my $ceid = (split /\@/, $jinfo->{Job_Owner})[-1];
    next unless defined $ceid;
    next if ($multi_ce and not __PACKAGE__->keepJob({
           host => $host,
           ceid => $ceid,
         celist => $celist,
      is_master => $iam_master
    }));    
    my $job = new Collector::PBS::JobInfo;
    my $user = $jinfo->{euser} || (split /\@/, $jinfo->{Job_Owner})[0];
    unless (defined $ugDict->{$user}) {
      my $group = findGroup $user;
      $ugDict->{$user} = $group;
    }
    $job->JID($jid);
    $job->GROUP($ugDict->{$user});
    $job->QUEUE($jinfo->{queue});
    $job->USER($user);
    $job->STATUS($jinfo->{job_state});
    $job->QTIME(UnixDate(ParseDate($jinfo->{qtime}), "%s"));
    my $start_time = (exists $jinfo->{start_time}) ? $jinfo->{start_time} : $jinfo->{mtime};
    ($job->STATUS eq 'R') and $job->START(UnixDate(ParseDate($start_time), "%s"));
    my $exec_host = (defined $jinfo->{exec_host}) ? (split /\./, $jinfo->{exec_host})[0] : '?';
    $job->EXEC_HOST($exec_host); 
    $job->CPUTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.cput'}), 0, "%st") || undef);
    $job->WALLTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.walltime'}), 0, "%st") || undef);
    $job->MEM(convert_kb($jinfo->{'resources_used.mem'}));
    $job->VMEM(convert_kb($jinfo->{'resources_used.vmem'}));

    $job->RANK($rankDict->{$jid} || -1);
    $job->PRIORITY($prioDict->{$jid} || -1000000);

    $dict->{$job->JID} = $job;
  }
  # Get finished jobs
  # We should try to find all the files within the range
  my $currAcct  = $config->{acctDir} . "/" . strftime('%Y%m%d', localtime);
  my $startTime = time() - $period;
  my $prevAcct  = $config->{acctDir} . "/" . strftime('%Y%m%d', localtime($startTime));
  $prevAcct = "" if $currAcct eq $prevAcct;

  $command = qq|grep -h ";E;" $prevAcct $currAcct|;
  print STDERR $command, "\n" if $config->{verbose};
  chomp(my @finJobs = getCommandOutput($command, \$ecode, $show_error, $verbose));
  for (@finJobs) {
    my ($jid, $info) = map { trim $_ } (split /;/)[2..3];
    $jid = (split /\./, $jid)[0];

    my $jinfo = {};
    for my $attr (split /\s+/, $info) {
      my ($key, $value) = map { trim $_ } (split m/=/, $attr);
      $jinfo->{$key} = $value;
    }
    # skip entries older than $period
    next if $jinfo->{end} < $startTime;
    next if (defined $jinfo->{queue} and 
      grep { $_ eq $jinfo->{queue} } @$queues_toskip);

    # Multiple CE system
    my $ceid = (split /\@/, $jinfo->{owner})[-1];
    next unless defined $ceid;
    next if ($multi_ce and not __PACKAGE__->keepJob({
           host => $host,
           ceid => $ceid,
         celist => $celist,
      is_master => $iam_master
    }));    
 
    my $user = $jinfo->{user} || (split /\@/, $jinfo->{owner})[0];
    unless (defined $ugDict->{$user}) {
      my $group = findGroup $user;
      $ugDict->{$user} = $group;
    }
    my $job = new Collector::PBS::JobInfo;
    $job->JID($jid);
    $job->GROUP($ugDict->{$user});
    $job->QUEUE($jinfo->{queue});
    $job->USER($user);
    $job->STATUS('E');
    $job->QTIME($jinfo->{qtime});
    $job->START($jinfo->{start});
    $job->END($jinfo->{end});
    my $exec_host = (defined $jinfo->{exec_host}) ? (split /\./, $jinfo->{exec_host})[0] : '?';
    $job->EXEC_HOST($exec_host); 
    $job->CPUTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.cput'}), 0, "%st") || undef);
    $job->WALLTIME(Delta_Format(ParseDateDelta($jinfo->{'resources_used.walltime'}), 0, "%st") || undef);
    $job->MEM(convert_kb($jinfo->{'resources_used.mem'}));
    $job->VMEM(convert_kb($jinfo->{'resources_used.vmem'}));
    $job->EX_ST($jinfo->{Exit_status} || undef);
    # how about Rank and priority?

    $dict->{$job->JID} = $job;
  }
}
sub qstat_f
{
  my $pkg = shift;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose     = $config->{verbose} || 0;
  my $show_error  = $config->{show_cmd_error} || 0;
  my $cache_qstat = $config->{query_cache}{file};
  my $cache_life  = $config->{query_cache}{lifetime} || 180; # seconds

  my $read_fromcache = 0;
  if (defined $cache_qstat and -e $cache_qstat) {
    # last modification time
    my $age = time() - (stat $cache_qstat)[9];
    $read_fromcache = 1 if $age < $cache_life;
  }
  my $text;
  if ($read_fromcache) {
    chop($text = readFile($cache_qstat, $verbose));
  }
  else {
    my $command = q|qstat -f|;
    my $ecode = 0;
    chop($text = getCommandOutput($command, \$ecode, $show_error, $verbose));
  }
  my @jobList = (split /Job Id: +/, $text);
  shift @jobList; # The first element is empty by construction

  \@jobList;
}
sub keepJob
{
  my ($pkg, $params) = @_;
  # We assume that all the relevant parameters are available
  # accept jobs only for this CE 
  my $conda = ($params->{ceid} eq $params->{host}) ? 1 : 0; # fully specified name

  # process local jobs. only one CE should handle local jobs in this scheme
  my $ceid = (split /\./, $params->{ceid})[0];
  my $condb = ($params->{is_master} and not grep { $_ eq $ceid } @{$params->{celist}}) ? 1 : 0;
  ($conda or $condb) ? 1 : 0;
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
