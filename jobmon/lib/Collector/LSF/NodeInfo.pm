package Collector::LSF::NodeInfo;
 
use strict;
use warnings;
use Carp;
use IO::File;
use Net::Domain qw/hostname/;
use Data::Dumper;

use Collector::Util qw/trim 
                       getCommandOutput 
                       findGroup/;
use base 'Collector::NodeInfo';

$Collector::LSF::NodeInfo::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class(nCPU => __PACKAGE__->nCPU());
  bless $self, $class;

  $self->_initialize();
  $self;
}

sub _initialize
{ 
  my $self = shift;
  my $config = $self->config;
  my $verbose = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $info = {};
  $self->info($info);

  my $dict = __PACKAGE__->getJobList();
  my $ecode = 0;
  while ( my ($jid) = each %$dict ) {
    # Ask bjobs to return a list of PIDs for this job
    my $command = qq|bjobs -l $jid |;
    chomp(my @content = getCommandOutput($command, \$ecode, $show_error, $verbose));
    my @pidList = ();
    for (@content) {
      if (/PGID/../SCHEDULING/) {
        next if /^$/; # empty line
        next if /SCHEDULING/;
        s/PGID:\s+\d+;\s+PIDs:\s+//g;
        my @fields = (split /\s+/, trim $_);
        push @pidList, @fields;
      }
    }
    # Now store for each pid the cpu (note. top does not accept > 20 -p arguments)
    my $pidInfo = $dict->{$jid}{pids};
    $command = q|ps --no-headers -o pid,pcpu,comm --pid | . join(',', @pidList);
    chomp(@content = map { trim $_ } getCommandOutput($command, \$ecode, $show_error, $verbose));
    for my $line (@content) {
      my ($pid, $pcpu, $cmd) = (split /\s+/, trim $line);
      $pcpu = 0.0 if $pcpu eq '';
      $pidInfo->{$pid} = $pcpu;
      unless (defined $dict->{$jid}{jwdir}) {
        $dict->{$jid}{jwdir} = qq|/proc/$pid/cwd| if $cmd =~ /jobwrapper/;
      }
    }
  }
  print Data::Dumper->Dump([$dict], [qw/dict/]) if $config->{debug}>1;
  $info->{jidmap} = $dict;
}

sub getJobList 
{
  my $class = shift;

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $host = lc hostname();
  my $command = qq|bjobs -w -u all -m $host 2>/dev/null|;
  my $ecode = 0;
  chomp(my @list = getCommandOutput($command, \$ecode, $show_error, $verbose)); shift @list;

  my $map = {};
  for (@list) {
    my ($jid, $uid) = (split)[0,1];
    my $gid = findGroup $uid;
    $map->{$jid} = {
      pids => {},
       uid => $uid, 
       gid => $gid
    };
  }
  $map;
}

sub nCPU
{
  my $class = shift;

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $host = lc hostname();
  my $command = qq|lshosts $host|;
  my $ecode = 0;
  chomp(my @content = getCommandOutput($command, \$ecode, $show_error, $verbose));
  shift @content; # header line is gone
  return -1 unless scalar @content == 1;
  my $row = trim $content[0];
  (split /\s+/, $row)[4];
}

1;
__END__
