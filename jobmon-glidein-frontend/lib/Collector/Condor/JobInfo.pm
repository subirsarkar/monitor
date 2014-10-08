package Collector::Condor::JobInfo;

use strict;
use warnings;
use Carp;
use HTTP::Date;
use Data::Dumper;

use Collector::Util qw/trim getCommandOutput importFields/;
use Collector::ConfigReader;

$Collector::Condor::JobInfo::VERSION = q|0.1|;

use constant SCALE => 1024;
our $AUTOLOAD;

my $keymap = 
{
                 ClusterId => q|CLUSTER_ID|,
                    ProcId => q|PROC_ID|,
               GlobalJobId => q|JID|,
                  BLTaskID => q|TASK_ID|,
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
           AccountingGroup => q|ACCT_GROUP|,
      x509userproxysubject => q|SUBJECT|,
         x509UserProxyFQAN => q|FQAN|,
                ExitStatus => q|EX_ST|,
                       Cmd => q|JOBDESC|,
                      Rank => q|RANK|,
                   JobPrio => q|PRIORITY|,
      EnteredCurrentStatus => q|TIMELEFT|,
         Glidein_MonitorID => q|GRID_ID|,
  MATCH_GLIDEIN_Gatekeeper => q|GATEKEEPER|,
     MATCH_GLIDEIN_CMSSite => q|GRID_SITE|
};
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

  my %fields = importFields;
  bless {
     _permitted => \%fields
  }, $class;
}

sub parse
{
  my ($self, $attr) = @_;
  my $info = {};
  
  my $config = Collector::ConfigReader->instance()->config;
  my $collector   = $config->{collector};
  my $verbose     = $config->{verbose} || 0;
  my $show_error  = $config->{show_error} || 0;
  my $remove_role = $config->{remove_role} || 0;

  croak q|Must specify if parsing running jobs or not!| unless defined $attr->{parse_running};
  my $parse_running = $attr->{parse_running};
  unless (defined $attr->{text}) { 
    croak q|Must specify a valid JOBID| unless defined $attr->{jobid};
    my $user = (defined $attr->{user} && $attr->{user} !~ /^all$/) ? "-submitter $attr->{user}" : q||;

    my $command = ($parse_running) ? __PACKAGE__->runningJobs : __PACKAGE__->pendingJobs;
    $command .= qq| $user $attr->{jobid}|;
    my $ecode = 0;
    chop($attr->{text} = getCommandOutput($command, \$ecode, $show_error, $verbose));
  }

  my $line = $attr->{text};
  $line =~ s/"//g;
  for my $item (split /!/, trim $line) {
    my ($key, $value) = (split /:=/, $item);
    next unless exists $keymap->{$key};
    $info->{$keymap->{$key}} = ($value ne 'undefined') ? $value : undef;
  }
  croak q|both CLUSTER_ID and PROC_ID must be available| 
    unless (defined $info->{CLUSTER_ID} and defined $info->{PROC_ID});
  $info->{LOCAL_ID} = qq|$info->{CLUSTER_ID}.$info->{PROC_ID}|;
  carp qq|GRID_ID undefined for JID=$info->{JID}\n| unless defined $info->{GRID_ID};
  #$info->{JID} = join '_', (split /#/, $info->{JID});

  # replace // by / in GRID_ID
  if (defined $info->{GRID_ID}) {
    $info->{GRID_ID} =~ s#//#/#g;
    $info->{GRID_ID} =~ s#/#//#;
  }

  # normalize  
  my $status = $info->{STATUS};
  $info->{STATUS}   = $statusAttr->{$status}[0] || undef; 
  $info->{LSTATUS}  = $statusAttr->{$status}[1] || undef; 
#  my $group =  __PACKAGE__->correctGroup({  user => $info->{USER}, 
#                                           group => $info->{GROUP},
#			                  ugdict => $attr->{ugdict}});
  $info->{GROUP} = 'cms'; ## unless defined $info->{GROUP};
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

#  $info->{GRID_CE} = (defined $info->{GATEKEEPER}) 
#        ? ((split /:/, $info->{GATEKEEPER})[0])
#        : undef; 
   $info->{GRID_CE} = $info->{GATEKEEPER};

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
  $info->{RB} = q|glideinWMS|;
  $info->{EXEC_HOST} = (split /\@/, lc $info->{EXEC_HOST})[-1]
    if (defined $info->{EXEC_HOST});

  $self->{_INFO} = $info;
}

sub _buildCmd
{
  # Read the config in any case
  my $config = Collector::ConfigReader->instance()->config;
  my $collector = $config->{collector};

  my $command = <<"END";
condor_q -pool $collector \\
      -format "JobStatus:=%d!" JobStatus \\
      -format "ClusterId:=%d!" ClusterId \\
      -format "ProcId:=%d!" ProcId \\
      -format "GlobalJobId:=%s!" GlobalJobId \\
      -format "BLTaskID:=%V!" BLTaskID \\
      -format "AccountingGroup:=%V!" AccountingGroup \\
      -format "Owner:=%s!" Owner \\
      -format "QDate:=%d!" QDate \\
      -format "Rank:=%V!" Rank \\
      -format "JobPrio:=%V!" JobPrio \\
      -format "x509UserProxyFQAN:=%V!" x509UserProxyFQAN \\
      -format "x509userproxysubject:=%V!" x509userproxysubject \\
      -format "Glidein_MonitorID:=%V!" Glidein_MonitorID \\
      -format "MATCH_GLIDEIN_CMSSite:=%V!" MATCH_GLIDEIN_CMSSite \\
END

  $command;
}
sub pendingJobs
{
  # Read the config in any case
  my $config = Collector::ConfigReader->instance()->config;
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist = qq| -name $_| for (@$scheddList);

  my $cmdPart = _buildCmd;
  my $command = <<"END";
$cmdPart      -format "MATCH_GLIDEIN_Gatekeeper:=%V\\n" MATCH_GLIDEIN_Gatekeeper \\
         -constraint 'jobstatus == 1 || jobstatus == 5' \\
END
  $command .= qq| -constraint '$config->{constraint}{condor_q}'| 
    if defined $config->{constraint}{condor_q};

  # Finally, if instructed query only the listed schedds
  $command .= (scalar @$scheddList) ? $slist : q| -global|;
  print $command, "\n";

  $command;
}
sub runningJobs
{
  # Read the config in any case
  my $config = Collector::ConfigReader->instance()->config;
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist = qq| -name $_| for (@$scheddList);

  my $cmdPart = _buildCmd;
  my $command = <<"END";
$cmdPart      -format "MATCH_GLIDEIN_Gatekeeper:=%V!" MATCH_GLIDEIN_Gatekeeper \\
      -format "RemoteHost:=%V!" RemoteHost \\
      -format "JobCurrentStartDate:=%V!" JobCurrentStartDate \\
      -format "CompletionDate:=%V!" CompletionDate \\
      -format "RemoteWallClockTime:=%V!" RemoteWallClockTime \\
      -format "RemoteUserCpu:=%V!" RemoteUserCpu \\
      -format "ImageSize_RAW:=%V!" ImageSize_RAW \\
      -format "DiskUsage:=%V!" DiskUsage \\
      -format "ExitStatus:=%d!" ExitStatus \\
      -format "Cmd:=%V!" Cmd \\
      -format "EnteredCurrentStatus:=%d\\n" EnteredCurrentStatus \\
      -constraint 'jobstatus == 2' \\
END
  $command .= qq| -constraint '$config->{constraint}{condor_q}'| 
    if defined $config->{constraint}{condor_q};

  # Finally, if instructed query only the listed schedds
  $command .= (scalar @$scheddList) ? $slist : q| -global|;
  print $command, "\n";

  $command;
}
sub clusteridCmd
{
  my $attr = shift;
  # Read the config in any case
  my $config = Collector::ConfigReader->instance()->config;
  my $collector = $config->{collector};
  my $slist = '';
  my $scheddList = $config->{schedd_list} || [];
  $slist = qq| -name $_| for (@$scheddList);

  my $command = <<"END";
condor_q -pool $collector \\
      -format "%d." ClusterId \\
      -format "%d\\n" ProcId \\
      -constraint 'jobstatus == 1 || jobstatus == 2 || jobstatus == 5' \\
END
  $command .= qq| -constraint '$config->{constraint}{condor_q}'| 
    if defined $config->{constraint}{condor_q};

  # Finally, if instructed query only the listed schedds
  $command .= (scalar @$scheddList) ? $slist : q| -global|;

  my $submitter = (exists $attr->{user}  && $attr->{user} !~ /^all$/) ? qq| -submitter $attr->{user}| : qq||;
  $command .= $submitter;
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
  for my $key (keys %$info) {
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

my $jid  = shift || die qq|Usage $0 JID|;
my $job = JobInfo->new({jobid => $jid});
$job->show;
