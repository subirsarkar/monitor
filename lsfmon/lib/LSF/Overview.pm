package LSF::Overview;

use strict;
use warnings;
use Carp;
use Storable;
use Data::Dumper;
use File::Find;
use File::Basename;
use List::Util qw/min max/;

use LSF::ConfigReader;
use LSF::Util qw/trim 
                 readFile 
                 sortedList
                 storeInfo
                 restoreInfo/;
use LSF::JobList;
use LSF::JobInfo;  # needed by de-serialization(Storable)
use LSF::Hosts;

$| = 1;

our $smap = 
{
  R => q|nrun|,
  Q => q|npend|,
  H => q|nheld|
};

sub new
{
  my ($this, $params) = @_;
  my $class = ref $this || $this;

  defined $params->{filemap} or carp q|JID-to-file mapping not provided!|;

  my $self = bless {}, $class;
  $self->_initialize($params->{filemap});
  $self;
}

sub _initialize
{
  my ($self, $filemap) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $hosts_toskip = $config->{overview}{hosts_toskip} || [];
  my $verbose = $config->{overview}{verbose} || 0;
  my $cluster_type = $config->{cluster_type} || q|grid|;

  # Batch slots
  my $slotinfo = LSF::Hosts->new()->info;
  my $maxSlots = $slotinfo->{max};
  my $okSlots  = $slotinfo->{available};
  my $jobSlots = $slotinfo->{job};
  my $runSlots = $slotinfo->{running};
  my $slots = {
      maxever => $self->updateSlotDB($maxSlots),
          max => $maxSlots,
    available => $okSlots,
      running => $runSlots,
      pending => $jobSlots - $runSlots,
         free => $okSlots - $runSlots
  };

  # Find (overall,user,ui,group,dn) jobs
  my $jobs = LSF::JobList->new;
  my $joblist = $jobs->list; # returns a hash reference
  my @jList = sort keys %$joblist;

  # Build (JID,DN) map
  my $dmap = ($cluster_type eq q|grid|) 
    ? __PACKAGE__->buildMap({jidList => \@jList,filemap => $filemap,verbose => $verbose})
    : {};

  my $jobinfo = {njobs => 0,
                  nrun => 0,
                 npend => 0,
                 nheld => 0,
                 ncore => 0,
              walltime => 0,
               cputime => 0,
               ratio10 => 0};
  my $groupinfo = {};
  my $uiinfo    = {};
  my $userinfo  = {};
  my $dninfo    = {};
  my $queueinfo = {};
  while ( my ($jx,$job) = each %$joblist ) {
    my $status = $job->STATUS;
    next if $status eq 'U';

    my $jid   = $job->JID;
    my $user  = $job->USER;
    my $ui    = $job->UI_HOST;
    my $group = $job->GROUP || q|other|;
    my $queue = $job->QUEUE;

    $jobinfo->{njobs}++;
    $groupinfo->{$group}{njobs}++;
    $queueinfo->{$queue}{njobs}++;
    $uiinfo->{$ui}{njobs}++;

    # The following may not be clean enough; for the same user we should try to 
    # avoid setting the same over and over again
    my $dn = $dmap->{$jid} || q|local-|.$user;
    $job->SUBJECT($dn);
    print join(":", $jid, $user, $status, $ui, $dn), "\n" if $verbose;

    $userinfo->{$user}{$group}{$dn}{$ui}{njobs}++;
    $dninfo->{$dn}{$user}{$group}{njobs}++;

    defined $smap->{$status} or next;
    my $tag = $smap->{$status};
    $jobinfo->{$tag}++;
    $groupinfo->{$group}{$tag}++;
    $queueinfo->{$queue}{$tag}++;
    $uiinfo->{$ui}{$tag}++;
    $userinfo->{$user}{$group}{$dn}{$ui}{$tag}++;
    $dninfo->{$dn}{$user}{$group}{$tag}++;
    if ($status eq 'R') {
      my $cputime  = $job->CPUTIME  || 0.0;
      my $walltime = $job->WALLTIME || 0.0;
      my $ncore    = $job->NCORE || 0;

      $jobinfo->{ncore}    += $ncore;
      $jobinfo->{cputime}  += $cputime;
      $jobinfo->{walltime} += $walltime;

      $groupinfo->{$group}{ncore}    += $ncore;
      $groupinfo->{$group}{cputime}  += $cputime;
      $groupinfo->{$group}{walltime} += $walltime;

      $queueinfo->{$queue}{ncore}    += $ncore;
      $queueinfo->{$queue}{cputime}  += $cputime;
      $queueinfo->{$queue}{walltime} += $walltime;

      $uiinfo->{$ui}{ncore}    += $ncore;
      $uiinfo->{$ui}{cputime}  += $cputime;
      $uiinfo->{$ui}{walltime} += $walltime;

      $dninfo->{$dn}{$user}{$group}{ncore}    += $ncore;
      $dninfo->{$dn}{$user}{$group}{cputime}  += $cputime;
      $dninfo->{$dn}{$user}{$group}{walltime} += $walltime;

      $userinfo->{$user}{$group}{$dn}{$ui}{ncore}    += $ncore;
      $userinfo->{$user}{$group}{$dn}{$ui}{cputime}  += $cputime;
      $userinfo->{$user}{$group}{$dn}{$ui}{walltime} += $walltime;

      my $ratio = min(1, (($walltime>0) ? $cputime/$walltime : 0));
      if ($ratio < 0.1) {
        ++$jobinfo->{ratio10};
        ++$groupinfo->{$group}{ratio10};
        ++$queueinfo->{$queue}{ratio10};
        ++$uiinfo->{$ui}{ratio10};
        ++$dninfo->{$dn}{$user}{$group}{ratio10};
        ++$userinfo->{$user}{$group}{$dn}{$ui}{ratio10};
      }
    }
  }    
  # Post-initialise
  for my $info ($groupinfo, $queueinfo, $uiinfo) {
    while ( my ($el) = each %$info ) {
      $info->{$el}{njobs}    = 0 unless defined $info->{$el}{njobs};
      $info->{$el}{nrun}     = 0 unless defined $info->{$el}{nrun};
      $info->{$el}{npend}    = 0 unless defined $info->{$el}{npend};
      $info->{$el}{nheld}    = 0 unless defined $info->{$el}{nheld};
      $info->{$el}{ncore}    = 0 unless defined $info->{$el}{ncore};
      $info->{$el}{cputime}  = 0 unless (defined $info->{$el}{cputime} and $info->{$el}{cputime}>0);
      $info->{$el}{walltime} = 0 unless (defined $info->{$el}{walltime} and $info->{$el}{walltime}>0);
      $info->{$el}{ratio10}  = 0 unless defined $info->{$el}{ratio10};
    }
  }
  while ( my ($user) = each %$userinfo) {
    my $groups = $userinfo->{$user};
    while ( my ($group) = each %$groups) {
      my $dnlist = $userinfo->{$user}{$group};
      while ( my ($dn) = each %$dnlist ) {
        my $uilist = $userinfo->{$user}{$group}{$dn};
        while ( my ($ui) = each %$uilist ) {
          $userinfo->{$user}{$group}{$dn}{$ui}{njobs} = 0 unless defined $userinfo->{$user}{$group}{$dn}{$ui}{njobs};
          $userinfo->{$user}{$group}{$dn}{$ui}{nrun}  = 0 unless defined $userinfo->{$user}{$group}{$dn}{$ui}{nrun};
          $userinfo->{$user}{$group}{$dn}{$ui}{npend} = 0 unless defined $userinfo->{$user}{$group}{$dn}{$ui}{npend};
          $userinfo->{$user}{$group}{$dn}{$ui}{nheld} = 0 unless defined $userinfo->{$user}{$group}{$dn}{$ui}{nheld};
          $userinfo->{$user}{$group}{$dn}{$ui}{ncore} = 0 unless defined $userinfo->{$user}{$group}{$dn}{$ui}{ncore};
          $userinfo->{$user}{$group}{$dn}{$ui}{cputime}  = 0 
            unless (defined $userinfo->{$user}{$group}{$dn}{$ui}{cputime} and $userinfo->{$user}{$group}{$dn}{$ui}{cputime}>0);
          $userinfo->{$user}{$group}{$dn}{$ui}{walltime}  = 0 
            unless (defined $userinfo->{$user}{$group}{$dn}{$ui}{walltime} and $userinfo->{$user}{$group}{$dn}{$ui}{walltime}>0);
          $userinfo->{$user}{$group}{$dn}{$ui}{ratio10}  = 0 
            unless (defined $userinfo->{$user}{$group}{$dn}{$ui}{ratio10} and $userinfo->{$user}{$group}{$dn}{$ui}{ratio10}>0);        }
      }
    }
  }
  while ( my ($dn)= each %$dninfo ) {
    my $users = $dninfo->{$dn};
    while ( my ($user) = each %$users) {
      my $groups = $users->{$user};
      while ( my ($group) = each %$groups) {
        $dninfo->{$dn}{$user}{$group}{njobs}    = 0 unless  defined $dninfo->{$dn}{$user}{$group}{njobs};
        $dninfo->{$dn}{$user}{$group}{nrun}     = 0 unless  defined $dninfo->{$dn}{$user}{$group}{nrun};
        $dninfo->{$dn}{$user}{$group}{npend}    = 0 unless  defined $dninfo->{$dn}{$user}{$group}{npend};
        $dninfo->{$dn}{$user}{$group}{nheld}    = 0 unless  defined $dninfo->{$dn}{$user}{$group}{nheld};
        $dninfo->{$dn}{$user}{$group}{ncore}    = 0 unless  defined $dninfo->{$dn}{$user}{$group}{ncore};
        $dninfo->{$dn}{$user}{$group}{cputime}  = 0 unless (defined $dninfo->{$dn}{$user}{$group}{cputime} and $dninfo->{$dn}{$user}{$group}{cputime}>0);
        $dninfo->{$dn}{$user}{$group}{walltime} = 0 unless (defined $dninfo->{$dn}{$user}{$group}{walltime} and $dninfo->{$dn}{$user}{$group}{walltime}>0);
        $dninfo->{$dn}{$user}{$group}{ratio10}  = 0 unless  defined $dninfo->{$dn}{$user}{$group}{ratio10};
      }
    }
  }

  if ($verbose) {
    print Data::Dumper->Dump([$slots],     [qw/slots/]);
    print Data::Dumper->Dump([$jobinfo],   [qw/jobinfo/]);
    print Data::Dumper->Dump([$groupinfo], [qw/groupinfo/]);
    print Data::Dumper->Dump([$queueinfo], [qw/queueinfo/]);
    print Data::Dumper->Dump([$uiinfo],    [qw/uiinfo/]);
    print Data::Dumper->Dump([$userinfo],  [qw/userinfo/]);
    print Data::Dumper->Dump([$dninfo],    [qw/dninfo/]);
  }
  # Finally attach to the object 
  $self->{slots}  = $slots;
  $self->{jobs}   = $jobinfo;
  $self->{groups} = $groupinfo;
  $self->{queues} = $queueinfo;
  $self->{uiinfo} = $uiinfo;
  $self->{users}  = $userinfo;
  $self->{dninfo} = $dninfo;
  $self->{joblist} = $joblist;
}

sub readDir
{
  my $pkg = shift;

  # Read the global configuration, a singleton
  my $config = LSF::ConfigReader->instance()->config;
  my $path = $config->{overview}{infoDir};
  my $max_file_age = $config->{overview}{max_file_age} || 7;

  my @files = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    push @files, $file if (-f $file and -M $file < $max_file_age);
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}

sub filemap
{
  my ($pkg, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my @files = __PACKAGE__->readDir;

  my $fmap = {};
  for my $file (@files) {
    next if -d $file;
    my $base = basename $file;
    my $jid = (split /\./, $base)[-1];
    $fmap->{$jid} = $file;
  }
  print Data::Dumper->Dump([$fmap], [qw/fmap/]) if $verbose;
  $fmap;
}

sub buildMap
{
  my ($pkg, $params) = @_;

  croak q|input jidList missing!| unless defined $params->{jidList};
  my $jidList = $params->{jidList};
  my $verbose = $params->{overview}{verbose} || 0;
  my $filemap = $params->{filemap} || __PACKAGE__->filemap($verbose); 

  my $config = LSF::ConfigReader->instance()->config;
  my $dbfile = $config->{overview}{dbFile};

  # Read stored info for fast indexing
  my $stmap = restoreInfo($dbfile);
  for my $jid (@$jidList) {
    defined $stmap->{$jid} and next;
    defined $filemap->{$jid} or next;
    my $file = $filemap->{$jid};
    # some files may disappear in the mean time, so check again
    -e $file or carp qq|>>> $file does not exist!| and next;
    print ">>> Processing $file \n" if $verbose;

    chomp(my @content = readFile($file, $verbose));
    my @new_content = grep { /^GLOBUS_ID/ } @content;
    @new_content = grep { /^SUDO_COMMAND/ } @content unless scalar @new_content;
    @new_content = grep { /^X509_USER_PROXY/ } @content unless scalar @new_content;
    scalar @new_content or next;

    my $dn = $new_content[0];
    if ($dn =~ /^GLOBUS_ID/) {
      $dn =~ s/^GLOBUS_ID='//;
      $dn =~ s/'; export GLOBUS_ID$//;
    }
    elsif ($dn =~ /^SUDO_COMMAND/) {  # CREAM CE
      $dn =~ s/^SUDO_COMMAND='//;
      $dn =~ s/'; export SUDO_COMMAND$//;
      $dn = (split m#\s+\-u\s+#, $dn)[-1];
      $dn = (split m#\s+\-r\s+#, $dn)[0] || undef;
    } 
    else {
      $dn =~ s/^X509_USER_PROXY='//;
      $dn =~ s/'; export X509_USER_PROXY$//;
      $dn = (split m#/#, $dn)[6] || undef;
    }
    next unless defined $dn;
    $stmap->{$jid}{dn}        = trim $dn;
    $stmap->{$jid}{timestamp} = time;
  }

  # trim the stored map and transfer to $info
  my $then = time - 10 * 24 * 60 * 60;
  my $dnmap = {};
  while ( my ($jid) = each %$stmap ) {
    delete $stmap->{$jid} and next if $stmap->{$jid}{timestamp} < $then; 
    $dnmap->{$jid} = $stmap->{$jid}{dn};
  }
  print Data::Dumper->Dump([$dnmap], [qw/dnmap/]) if $verbose;

  storeInfo($dbfile, $stmap);
  $dnmap;
}
sub updateSlotDB
{
  my ($self, $slots) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $slotDB = $config->{overview}{slotDB};
  return $slots unless defined $slotDB;

  my $nent = 0;
  if ( -r $slotDB ) {
    my $info = restoreInfo($slotDB);
    my $nel  = $info->{slots};

    storeInfo($slotDB, {slots => $slots} ) if $slots > $nel;
    $nent = max $nel, $slots;
  }
  else {
    storeInfo($slotDB, {slots => $slots} );
    $nent = $slots;
  }
  $nent;
}
sub show
{
  my $self = shift;

  # Resources
  print "=================\nResource\n=================\n";
  printf "%10s| %10s| %10s| %10s| %10s|\n", 
    q|Max|, q|Available|, q|Running|, q|Pending|, q|Free|;
  my $slots = $self->{slots};
  printf "%10d| %10d| %10d| %10d| %10d|\n", $slots->{max}, 
                                            $slots->{available}, 
                                            $slots->{running},
                                            $slots->{pending},
                                            $slots->{free};

  # Overall jobs
  print "\n=================\nJobs\n=================\n";
  printf "%10s| %10s| %10s| %10s| %7s\n", 
    q|Jobs|, q|Running|, q|Pending|, q|Held|, q|CPU Eff|;
  my $jobinfo = $self->{jobs};
  
  my $cputime  = $jobinfo->{cputime};
  my $walltime = $jobinfo->{walltime};
  my $cpueff = ($walltime > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
       : '-';
  printf "%10s| %10s| %10s| %10s| %7.4f\n", $jobinfo->{njobs} || 0,
                                            $jobinfo->{nrun}  || 0,
                                            $jobinfo->{npend} || 0,
                                            $jobinfo->{nheld} || 0,
                                            $cpueff;

  # Jobs by groups
  print "\n=================\nJobs by Groups\n=================\n";
  printf "%12s| %10s| %10s| %10s| %10s| %7s\n", 
    q|Group|, q|Jobs|, q|Running|, q|Pending|, q|Held|, q|CPU Eff|;
  my $groupinfo = $self->{groups};
  for my $group (sort { $groupinfo->{$b}{nrun} <=> $groupinfo->{$a}{nrun} } keys %$groupinfo) {
    my $cputime  = $groupinfo->{$group}{cputime};
    my $walltime = $groupinfo->{$group}{walltime};
    my $cpueff = ($walltime > 0) 
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
       : '-';
    printf "%12s| %10d| %10d| %10d| %10d| %7s\n", $group, $groupinfo->{$group}{njobs}, 
                                                          $groupinfo->{$group}{nrun}, 
                                                          $groupinfo->{$group}{npend},
                                                          $groupinfo->{$group}{nheld},    
                                                          $cpueff;
  }

  # Jobs by Computing Elements
  print "\n=========================\nJobs by Computing Element\n=========================\n";
  printf "%8s| %10s| %10s| %10s| %10s| %7s\n", 
    q|UI|, q|Jobs|, q|Running|, q|Pending|, q|Held|, q|CPU Eff|;
  my $uiinfo = $self->{uiinfo};
  for my $ui (sort { $uiinfo->{$b}{nrun} <=> $uiinfo->{$a}{nrun} } keys %$uiinfo) {
    my $cputime  = $uiinfo->{$ui}{cputime};
    my $walltime = $uiinfo->{$ui}{walltime};
    my $cpueff = ($walltime > 0) 
      ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
      : '-';
    printf "%8s| %10d| %10d| %10d| %10d| %7s\n", $ui, $uiinfo->{$ui}{njobs}, 
                                                      $uiinfo->{$ui}{nrun}, 
                                                      $uiinfo->{$ui}{npend},
                                                      $uiinfo->{$ui}{nheld},
                                                      $cpueff;
  }

  # Jobs by DN
  print "\n=================\nJobs by DN\n=================\n";
  printf "%10s| %10s| %10s| %10s| %10s| %7s| %s|\n", 
    q|Group|, q|Jobs|, q|Running|, q|Pending|, q|Held|, q|CPU Eff|, q|DN|;
  my @cont = ();
  my $dninfo = $self->{dninfo};
  while ( my ($dn) = each %$dninfo ) {
    my $groups = $dninfo->{$dn};
    while ( my ($group) = each %$groups ) {
      my $nrun = $dninfo->{$dn}{$group}{nrun};
      my $cputime  = $dninfo->{$dn}{$group}{cputime};
      my $walltime = $dninfo->{$dn}{$group}{walltime};
      my $cpueff = ($walltime > 0) 
          ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime)) 
          : '-';
      push @cont, [
            $group,         
            $dninfo->{$dn}{$group}{njobs},
            $nrun,
            $dninfo->{$dn}{$group}{npend},
            $dninfo->{$dn}{$group}{nheld},
            $cpueff,
            $dn
      ];
    }
  }
  for my $aref (sort { $b->[2] <=> $a->[2] } @cont) {
    printf "%10s| %10s| %10s| %10s| %10s| %7s| %s|\n", @$aref;
  }
  # Jobs by local users
  print "\n=================\nJobs by Users\n=================\n";
  printf "%12s| %10s| %10s| %10s| %10s| %10s| %8s| %s|\n", 
    q|User|, q|Group|, q|Jobs|, q|Running|, q|Pending|, q|Held|, q|UI|, q|DN|;
  my $userinfo = $self->{users};
  while ( my ($user) = each %$userinfo ) {
    my $groups = $userinfo->{$user};
    while ( my ($group) = each %$groups ) {
      my $dnlist = $userinfo->{$user}{$group};
      while ( my ($dn) = each %$dnlist ) {
        my $uilist = $userinfo->{$user}{$group}{$dn};
        while ( my ($ui) = each %$uilist ) {
          printf "%12s| %10s| %10s| %10s| %10s| %10s| %8s| %s|\n", 
            $user,
            $group,
            $userinfo->{$user}{$group}{$dn}{$ui}{njobs},
            $userinfo->{$user}{$group}{$dn}{$ui}{nrun},
            $userinfo->{$user}{$group}{$dn}{$ui}{npend},
            $userinfo->{$user}{$group}{$dn}{$ui}{nheld},
            $ui,
	    $dn;
        }
      }
    }
  }
}

1;
__END__
package main;
my $obj = LSF::Overview->new;
$obj->show;
