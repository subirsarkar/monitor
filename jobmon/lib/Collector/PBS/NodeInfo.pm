package Collector::PBS::NodeInfo;
 
use strict;
use warnings;
use Carp;

use IO::File;
use Data::Dumper;

use Collector::Util qw/trim 
                       getCommandOutput 
                       findGroup/;
use base 'Collector::NodeInfo';

$Collector::PBS::NodeInfo::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize();
  $self;
}

sub _initialize
{ 
  my $self = shift;
  my $config = $self->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $info = {};
  $self->info($info);

  my $dict = $self->getJobList;
  while ( my ($jid) = each %$dict ) {
    my $sid = $dict->{$jid}{sid};
    next unless (defined $sid and $sid != -1);

    my $command = qq|ps --no-headers --sid $sid -o pid|;
    my $ecode = 0;
    chomp(my @pidList = 
      map { trim $_ } getCommandOutput($command, \$ecode, $show_error, $verbose));
    next unless scalar @pidList;

    # Now store for each pid the cpu (top does not accept > 20 -p arguments)
    my $pidInfo = $dict->{$jid}{pids};
    $command = q|ps --no-headers -o pid,pcpu,comm --pid | . join(',', @pidList);
    chomp(my @content = 
      map { trim $_ } getCommandOutput($command, \$ecode, $show_error, $verbose));
    for (@content) {
      my ($pid, $pcpu, $cmd) = map { trim $_ } (split /\s+/);
      $pidInfo->{$pid} = $pcpu || 0.0;
      unless (defined $dict->{$jid}{jwdir}) {
        $dict->{$jid}{jwdir} = qq|/proc/$pid/cwd| if $cmd =~ /jobwrapper/;
      }
    }
  }

  print Data::Dumper->Dump([$dict], [qw/dict/]) if $verbose;
  $info->{jidmap} = $dict;
}

sub getJobList
{
  my $self = shift;
  my $config = $self->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $map = {};
  my $jobDir = $config->{jobDir};
  return $map unless -r $jobDir;

  # Probably the simplest way to find the ids of the jobs on a WN
  local *DIRH;
  opendir DIRH, $jobDir 
    or croak qq|Failed to open directory $jobDir, $!, stopped|;
  my @list = grep { /^(?:\d+).(?:.*).SC$/ } readdir DIRH;
  closedir DIRH;

  my $ecode = 0;
  for (@list) {
    my $jid = (split /\./)[0];
    next unless $jid =~ /\d+/;
    my ($uid, $gid, $sid) = (q|?|, q|?|, -1);
    my $command = qq|qstat -f $jid|;
    chomp(my @content = 
      getCommandOutput($command, \$ecode, $show_error, $verbose));
    for my $line (@content) {
      if ($line =~ /Job_Owner/) {
        $uid = (split m#\s+=\s+#, trim $line)[-1];
        $uid = (split /\@/, trim $uid)[0]; 
        $gid = findGroup $uid;
      }
      elsif ($line =~ /session_id/) {
        $sid = (split m#\s+=\s+#, trim $line)[-1];
      }
    }
    $map->{$jid} = 
    {
      pids => {}, 
      uid => $uid, 
      gid => $gid, 
      sid => $sid
    };
  }
  $map;
}

1;
__END__
