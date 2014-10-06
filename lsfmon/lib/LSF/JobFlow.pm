package LSF::JobFlow;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use POSIX qw/strftime/;

use LSF::ConfigReader;
use LSF::Util qw/trim 
                 commandFH 
                 getCommandOutput 
                 findGroup
                 show_message/;
use LSF::Overview;
use LSF::Groups;
use LSF::UserGroup;

$| = 1;

our $smap = 
{
  S => q|submitted|,
  D => q|dispatched|,
  C => q|completed|
};

sub new
{
  my ($this, $params) = @_;
  defined $params->{filemap} or carp q|JobFlow::JID-to-file mapping not provided!|;
  my $class = ref $this || $this;

  my $self = bless {}, $class;
  $self->_initialize($params->{filemap});
  $self;
}

sub _initialize
{
  my ($self, $filemap) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $show_error = $config->{show_cmd_error} || 0;
  my $period  = $config->{jobflow}{period}  || 3600;
  my $verbose = $config->{jobflow}{verbose} || 0;
  my $verbose_g = $config->{verbose} || 0;
  my $time_cmd = $config->{time_cmd} || 0;
  my $cluster_type = $config->{cluster_type} || q|grid|;

  my $jobinfo = {};
  $self->{jobinfo} = $jobinfo;

  # execute bhist for different types and fill 2 temporary hashes.
  my $dict = {};
  my $jids = {};
  my $ecode = 0;
  my $time_a = time();
  for my $type (sort keys %$smap) {
    # Submitted/Dispatched/Finished Jobs in the last hour
    my $timenow = time();
    my $now  = strftime('%Y/%m/%d/%H:%M', localtime($timenow));
    my $then = strftime('%Y/%m/%d/%H:%M', localtime($timenow - $period));

    my $command = qq|bhist -w -u all -$type$then,$now|;
    print ">>> JobFlow::Executing $command\n" if $verbose>0;
    chomp(my @jobList = getCommandOutput($command, \$ecode, $show_error, $verbose_g));
    shift @jobList for (0..1); # 2 header lines
    pop @jobList;              # last line is usually blank
    $dict->{$type} = \@jobList;
    for my $line (@jobList) {
      my ($jid) = (split /\s+/, trim($line))[0];
      ++$jids->{quotemeta $jid};
    }
  }
  show_message q|>>> JobFlow::bhist elapsed time = |. 
    (time() - $time_a) . q| second(s)| if $time_cmd;

  # build (JID,DN) map
  my @jList = keys %$jids;
  return unless scalar @jList > 0;

  my $dmap = ($cluster_type eq q|grid|)
    ? LSF::Overview->buildMap({jidList => \@jList, filemap => $filemap, verbose => $verbose})
    : {};

  # finding the group,UI,dn for all the jobs at a time now will be efficient
  # CLEAN_PERIOD is set to 60 mins by default
  my $use_bugroup = $config->{use_bugroup} || 0;
  my $ugDict  = ($use_bugroup) ? LSF::Groups->instance({ verbose => 0 })->info : {};
  my $jidDict = {};
  $time_a = time();
  my $command = q|bjobs -w |.join(' ', @jList);
  print ">>> JobFlow::Executing $command\n" if $verbose>0;
  my $fh = commandFH($command, $verbose_g);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while ( my $line = $fh->getline) {
      my ($jid, $user, $queue, $ui) = (split /\s+/, trim($line))[0,1,3,4];    
      $jid = quotemeta $jid;

      # Find job group
      $ugDict->{$user} = findGroup $user unless defined $ugDict->{$user};
      $jidDict->{$jid}{group} = $ugDict->{$user}[0] || undef;

      # queue
      $jidDict->{$jid}{queue} = $queue;

      # Submitter (UI)
      $jidDict->{$jid}{ui} = $ui;

      # Finally, the DN
      $jidDict->{$jid}{dn} = $dmap->{$jid} || q|local-|.$user;
    }
    $fh->close;
  }
  show_message q|>>> JobFlow::bjobs -w joblist elapsed time = |. 
       (time() - $time_a) . q| second(s)| if $time_cmd;

  # get correct User group
  my $extra_info = LSF::UserGroup->instance()->info;
  for my $jid (keys %$extra_info) {
    next unless exists $jidDict->{$jid};
    $jidDict->{$jid}{group} = $extra_info->{$jid}{group};
  }

  # now process all
  for my $type (sort keys %$smap) {
    my $tag = $smap->{$type};
    my @jobList = @{$dict->{$type}};
    for my $line (@jobList) {
      my ($jid, $user) = (split /\s+/, trim($line))[0,1];
      $jid = quotemeta $jid;
      unless (defined $jidDict->{$jid}) {
	$verbose>0 and carp qq|JobFlow::jidDict missed entry for JID=$jid!|;
	next;
      }
      ++$jobinfo->{joblist}{$tag};
      my ($ui, $group, $queue, $dn) = ($jidDict->{$jid}{ui}    || undef,
                                       $jidDict->{$jid}{group} || undef, 
                                       $jidDict->{$jid}{queue} || undef, 
                                       $jidDict->{$jid}{dn}    || undef);
      ++$jobinfo->{uilist}{$ui}{$tag} if defined $ui;
      ++$jobinfo->{queuelist}{$queue}{$tag} if defined $queue;
      if (defined $group) {
        ++$jobinfo->{grouplist}{$group}{$tag};
        ++$jobinfo->{dnlist}{$dn}{$user}{$group}{$tag} if (defined $dn and defined $user);
        ++$jobinfo->{userlist}{$user}{$group}{$dn}{$ui}{$tag} 
            if (defined $user and defined $dn and defined $ui);
      }
    }
  }
  print Data::Dumper->Dump([$jidDict], [qw/jidDict/]) if $verbose>1;
  print Data::Dumper->Dump([$jobinfo], [qw/jobinfo/]) if $verbose>1;
}

sub show
{
  my $self = shift;

  print "\n=========================\nJobs\n=========================\n";
  my $info = $self->{jobinfo}{joblist};
  for my $type (sort keys %$info) {
    printf "%10d|", $info->{$type};
  }
  print "\n";
}

1;
__END__
package main;
my $filemap = LSF::Overview->filemap;
my $obj = LSF::JobFlow->new({ filemap => $filemap });
$obj->show;
