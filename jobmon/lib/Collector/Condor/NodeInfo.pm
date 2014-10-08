package Collector::Condor::NodeInfo;
 
use strict;
use warnings;
use Carp;
use IO::File;
use Net::Domain qw/hostname/;
use Data::Dumper;

use Collector::NodeInfo;
use Collector::Util qw/trim getCommandOutput/;

use base 'Collector::NodeInfo';

our $VERSION = qq|0.4|;

sub new($) 
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class(nCPU => __PACKAGE__->nCPU());
  bless $self, $class;

  $self->_initialize();
  $self;
}
sub _initialize($)
{ 
  my $self = shift;
  my $config = $self->config;
  my $baseDir = $config->{baseDir};
  my $domain  = $config->{domain};

  my $info = {};
  $self->info($info);

  my $map = __PACKAGE__->getJobList();
  my @jidList = sort keys %$map;
  return unless scalar @jidList; # must have jids

  for my $jid (@jidList) {
    my $rjid = $map->{$jid}{rjid};
    my $command = qq|$baseDir/jobmon/lib/Collector/Condor/findProcs.sh $rjid|;
    chomp(my @content = getCommandOutput($command));
    my @pidList = ();
    for (@content) {
      next if /^$/; # empty line
      push @pidList, $_;
    }

    # Now store for each pid the cpu (top does not accept > 20 -p arguments)
    my $pidInfo = $map->{$jid}{pids};
    $command = qq|ps --no-headers -o pid,pcpu --pid |.join(",", map {trim($_)} @pidList);
    chomp(@content = getCommandOutput($command));
    @content = map {trim $_} @content;
    for (@content) {
      my ($pid, $pcpu) = (split /\s+/);
      $pid  = trim($pid);
      $pcpu = trim($pcpu);
      $pcpu = 0.0 if $pcpu eq '';
      $pidInfo->{$pid} = $pcpu;
    }
  }
  print Data::Dumper->Dump([$map], [qw/map/]) if $config->{debug};
  $info->{jidmap} = $map;
}

sub getJobList 
{
  my $class = shift;
  my $host = hostname();  
  my $command = qq[condor_q -global -pool cmssrv59 -constraint "regexp (\\"$host.$domain\\",RemoteHost) " -format "%d" QDate -format "%d" ClusterID -format "%d " ProcID -format "%d." ClusterID -format "%d " ProcID -format "%s\\n" Owner 2>/dev/null; condor_q -global -pool cmssrv14 -constraint "regexp (\\"$host.$domain\\",RemoteHost)" -format "%d" QDate -format "%d" ClusterID -format "%d " ProcID -format "%d." ClusterID -format "%d " ProcID -format "%s\\n" Owner 2>/dev/null];
  chomp(my @list = getCommandOutput($command));

  my $map = {};
  for (@list) {
    my ($jid, $rjid, $uid) = (split);
    $jid = substr $jid, 4; 
    my $gid = findGroup($uid);
    $map->{$jid} = {
	pids => {},
         uid => $uid, 
         gid => $gid, 
        rjid => $rjid
    };
  }
  $map;
}

sub nCPU
{
  my $class = shift;
  my $host = hostname();
  my $command = qq[cat /proc/cpuinfo | grep Processor | wc -l];
  chomp(my @content = getCommandOutput($command));
  return -1 unless scalar(@content)==1;
  my $row = trim($content[0]);
  (split /\s+/, $row)[0];
}

sub getJobPath($$)
{
  my ($self, $jid) = @_;
  my $config = $self->config;
  my $verbose = $config->{verbose};

  my $info = $self->info;
  return qq|| unless defined $info;

  my $command = $self->buildCommand($jid, 'path');
  return qq|| if $command eq '?';

  $command .= qq# | grep 'condor_exec.exe' | sort | head -1 | awk '{m=split (\$0,a," "); for(i=0;i<m+1;i++) { if (index(a[i],"condor_exec.exe")>0 ) { print a[i]; } } }' | sed 's!/condor_exec.exe!!' #; # | awk -F\\/ '{print \$2, \$3, \$4}'#;
  print STDERR "command=$command\n" if $verbose;

  chop(my $elements = `$command`);
  $elements;
}

1;
__END__
