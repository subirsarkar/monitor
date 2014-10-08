package JobInfo;

use strict;
use warnings;
use Carp;
use HTTP::Date;
use Data::Dumper;

use Util qw/trim getCommandOutput/;
use ConfigReader;

$JobInfo::VERSION = q|0.1|;

my $keymap = 
{
              ClusterId => q|CLUSTER_ID|,
                 ProcId => q|PROC_ID|,
            GlobalJobId => q|JID|,
                  Owner => q|USER|,
              JobStatus => q|STATUS|,
                  QDate => q|QTIME|,
             RemoteHost => q|EXEC_HOST|,
    JobCurrentStartDate => q|START|,
         CompletionDate => q|END|,
    RemoteWallClockTime => q|WALLTIME|, 
          RemoteUserCpu => q|CPUTIME|,
          ImageSize_RAW => q|MEM|, 
              DiskUsage => q|VMEM|,
        AccountingGroup => q|GROUP|,
   x509userproxysubject => q|SUBJECT|,
      x509UserProxyFQAN => q|FQAN|,
             ExitStatus => q|EX_ST|,
                    Cmd => q|JOBDESC|,
   EnteredCurrentStatus => q|TIMELEFT|
};
our $AUTOLOAD;
my %fields = map { $_ => 1 } 
      qw/JID
         GRID_ID
         LOCAL_ID
         USER
         GROUP
         QUEUE
         STATUS
         LSTATUS
         QTIME
         START
         END
         EXEC_HOST
         CPUTIME
         WALLTIME
         MEM
         VMEM
         EX_ST
         CPULOAD
         JOBDESC
         ROLE
         GRID_CE
         FQAN
         SUBJECT
         TIMELEFT/;

use constant SCALE => 1024;
our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $statusAttr = 
{
  2 => [q|R|, q|running|],
  1 => [q|Q|, q|pending|],
  4 => [q|E|, q|exited|],
  3 => [q|E|, q|exited|],
  5 => [q|H|, q|held|]
};
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  bless {
    _permitted => \%fields
  }, $class;
}

sub parse
{
  my ($self, $attr) = @_;
  
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose    = $config->{verbose} || 0;
  my $domain     = $config->{domain};
  my $collector  = $config->{collector};
  my $show_error = $config->{show_cmd_error} || 0;
  my $group_map  = $config->{group_map} || {};

  croak q|Must specify if parsing running jobs or not!| unless defined $attr->{parse_running};
  my $parse_running = $attr->{parse_running};
  unless (defined $attr->{text}) { 
    croak q|Must specify a valid JOBID| unless defined $attr->{jobid};
    my $user = (defined $attr->{user} && $attr->{user} !~ /^all$/) ? "-submitter $attr->{user}" : q||;

    my $command = ($parse_running) ? __PACKAGE__->runningJobs : __PACKAGE__->pendingJobs;
    $command .= qq| $user -l $attr->{jobid}|;
    my $ecode = 0;
    chop($attr->{text} = getCommandOutput($command, \$ecode, $show_error, $verbose));
  }

  my $info = {};
  $self->{_INFO} = $info;

  my $line = $attr->{text};
  $line =~ s/"//g;
  for my $item (split /!/, trim $line) {
    my ($key, $value) = (split /:=/, $item);
    next unless exists $keymap->{$key};
    $info->{$keymap->{$key}} = ($value ne 'undefined') ? $value : undef;
  }

  # Normalise 
  $info->{JID} =~ s/#/_/g if defined $info->{JID}; 
  my $status = $info->{STATUS};
  $info->{STATUS}   = $statusAttr->{$status}[0] || undef; 
  $info->{LSTATUS}  = $statusAttr->{$status}[1] || undef; 
  $info->{LOCAL_ID} = (defined $info->{CLUSTER_ID} and defined $info->{PROC_ID})
                         ? qq|$info->{CLUSTER_ID}.$info->{PROC_ID}| 
                         : undef;

  my $group =  __PACKAGE__->correctGroup({  user => $info->{USER}, 
                                           group => $info->{GROUP},
			                  ugdict => $attr->{ugdict}});
  # Some parameters are still missing
  $info->{GROUP} = $group;
  $info->{ROLE}  = $info->{GROUP};
  $info->{QUEUE} = $info->{GROUP};

  # Treat SUBJECT
  if (defined $info->{FQAN}) {
    my @fields = (split /\,/, $info->{FQAN});
    $info->{ROLE} = $fields[1] if scalar @fields > 1;
    $info->{SUBJECT} = $fields[0]
      if (not defined $info->{SUBJECT} or $info->{SUBJECT} =~ m/CN=(?:limited\+)?proxy/);

    # crude, truncate very long SUBJECT, the trailing fields make the same SUBJECT look different 
    $info->{SUBJECT} = (split m#(?:/CN=\d+){2}#, $info->{SUBJECT})[0];
  }
  $info->{SUBJECT} = qq|localjob| unless defined $info->{SUBJECT};

  $info->{GRID_ID} = $info->{JID}; 
  my $ceid = (split /_/, $info->{GRID_ID})[0];
  $info->{GRID_CE} = $ceid.q|/jobmanager-condor-|.$info->{QUEUE};

  # patch walltime
  my $timenow = time();
  if ((defined $info->{STATUS} and $info->{STATUS} eq 'R') 
        and (not defined $info->{WALLTIME} or $info->{WALLTIME} <= 0)) {
    if (defined $info->{START}) {
      my $startTime = $info->{START};
      $info->{WALLTIME} = $timenow - $startTime;
      my $cpuload = (defined $info->{CPUTIME} && $info->{WALLTIME}>0) 
         ? $info->{CPUTIME}*1.0/$info->{WALLTIME} : undef;
      $info->{CPULOAD} = (defined $cpuload) ? sprintf ("%.3f", $cpuload) : undef;
    }
  }
  $info->{TIMELEFT} = (defined $info->{TIMELEFT}) ? $timenow + 36 * 3600 - $info->{TIMELEFT} : undef;
}

sub correctGroup
{
  my ($pkg, $attr) = @_;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose   = $config->{verbose} || 0;
  my $group_map = $config->{group_map} || {};

  my $user  = $attr->{user};
  my $group = $attr->{group};
  if (defined $group and length $group) {
    $group = (split /\@/, $group)[0];
    my @fields = (split /\./, $group);
    pop @fields;
    $group = join '.', @fields;
    $group =~ s/^group_//;
  }
  elsif (defined $attr->{ugdict}{$user}) {
    $group = $attr->{ugdict}{$user}; 
  }
  elsif (scalar keys (%$group_map)) {
    print STDERR qq|INFO. Group for $user undefined, use group_map\n| if $verbose;
    my @userp = sort keys %$group_map;
    for my $patt (@userp) {
      if ($user =~ m/$patt/) {
        $group = $group_map->{$patt};
        $attr->{ugdict}{$user} = $group; 
        print qq|>>> group=$group\n| if $verbose;
        last;
      }
    } 
  }
  else {
    $group = q|unknown|; 
  }
  $group;
}
sub pendingJobs
{
  # Read the config in any case
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $collector = $config->{collector};
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist .= qq| -name $_| for (@$scheddList);
  my $verbose = $config->{verbose} || 0;

  my $command = <<"END";
condor_q -pool $collector \\
      -format "ClusterId:=%d!" ClusterId \\
      -format "ProcId:=%d!" ProcId \\
      -format "JobStatus:=%d!" JobStatus \\
      -format "Owner:=%s!" Owner \\
      -format "GlobalJobId:=%s!" GlobalJobId \\
      -format "QDate:=%d!" QDate \\
      -format "AccountingGroup:=%V!" AccountingGroup \\
      -format "x509UserProxyFQAN:=%V!" x509UserProxyFQAN \\
      -format "x509userproxysubject:=%V\\n" x509userproxysubject \\
      -constraint 'jobstatus == 1 || jobstatus == 5' \\
END
  # query only the listed schedds
  $command .= (scalar @$scheddList) ? $slist : q| -global|;
  $command .= qq| -constraint '$config->{constraint}{condor_q}'| 
    if defined $config->{constraint}{condor_q};

  print $command, "\n";

  $command;
}
sub runningJobs
{
  # Read the config in any case
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $collector = $config->{collector};
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist .= qq| -name $_| for (@$scheddList);
  my $verbose = $config->{verbose} || 0;

  my $command = <<"END";
condor_q -pool $collector \\
      -format "ClusterId:=%d!" ClusterId \\
      -format "ProcId:=%d!" ProcId \\
      -format "GlobalJobId:=%s!" GlobalJobId \\
      -format "Owner:=%s!" Owner \\
      -format "JobStatus:=%d!" JobStatus \\
      -format "QDate:=%d!" QDate \\
      -format "RemoteHost:=%V!" RemoteHost \\
      -format "JobCurrentStartDate:=%V!" JobCurrentStartDate \\
      -format "CompletionDate:=%V!" CompletionDate \\
      -format "RemoteWallClockTime:=%V!" RemoteWallClockTime \\
      -format "RemoteUserCpu:=%V!" RemoteUserCpu \\
      -format "ImageSize_RAW:=%V!" ImageSize_RAW \\
      -format "DiskUsage:=%V!" DiskUsage \\
      -format "AccountingGroup:=%V!" AccountingGroup \\
      -format "x509userproxysubject:=%V!" x509userproxysubject \\
      -format "x509UserProxyFQAN:=%V!" x509UserProxyFQAN \\
      -format "ExitStatus:=%d!" ExitStatus \\
      -format "Cmd:=%V!" Cmd \\
      -format "EnteredCurrentStatus:=%d\\n" EnteredCurrentStatus \\
      -constraint 'jobstatus == 2' \\
END
  # query only the listed schedds
  $command .= (scalar @$scheddList) ? $slist : q| -global|;
  $command .= qq| -constraint '$config->{constraint}{condor_q}'| 
    if defined $config->{constraint}{condor_q};

  print $command, "\n";

  $command;
}
sub setStatus
{
  my ($self, $status) = @_;
  $self->{_INFO}{LSTATUS} = $statusAttr->{$status}[1] || undef;
  $self->{_INFO}{STATUS}  = $statusAttr->{$status}[0] || undef;
}

sub info
{
  my $self = shift;
  $self->{_INFO};
}

sub dump
{
  my $self = shift;
  my $info = $self->info;
  print Data::Dumper->Dump([$info], [qw/jobinfo/]);
}
sub show
{
  my $self = shift;
  my $stream = shift || *STDOUT;
  print $stream $self->toString;
}

sub toString
{
  my $self = shift;
  my $info = $self->info;
  my $output = sprintf (qq|\n{%s}{%s}{%s}\n|, $info->{GROUP}, $info->{QUEUE}, $info->{JID});
  while ( my ($key) = each %$info ) {
    $output .= sprintf(qq|%s: %s\n|, $key, $info->{$key});
  }
  $output;
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  if (@_) {
    return $self->{_INFO}{$name} = shift;
  } 
  else {
    return ((defined $self->{_INFO}{$name}) 
      ? $self->{_INFO}{$name} 
      : undef);
  }
}

sub DESTROY
{
  my $self = shift;
}

1;
__END__
package main;

my $jid = shift || die qq|Usage $0 JID|;
my $job = JobInfo->new({jobid => $jid});
$job->show;
