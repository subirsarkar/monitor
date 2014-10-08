package Collector::GridInfo;

use strict;
use warnings;
use Carp;
use File::stat;

use Collector::ConfigReader;
use Collector::DBHandle;
use Collector::GridInfoCore;
use Collector::Util qw/show_message
                       restoreInfo/;

$Collector::GridInfo::VERSION = q|0.7|;

our $AUTOLOAD;
my %fields = map { $_ => 1 } 
               qw/subject
                  gridid
                  rb
                  timeleft
                  jobdesc
                  role
                  gridce/;
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  croak q|Job List not found| unless defined $attr->{joblist};
  my $self = bless {
        dbconn => $attr->{dbconn} || Collector::DBHandle->new,
    _permitted => \%fields
  }, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize
{
  my ($self, $attr) = @_;

  my $config = Collector::ConfigReader->instance()->config;
  my $interval = $config->{jobsensor}{interval} || 600; # second
  my $baseDir   = $config->{baseDir} || q|/opt|;
  my $cacheLife = $config->{cachelife}{gridinfo} || 600; # seconds
  my $verbose = $config->{verbose} || 0;  
  my $inputFile = qq|$baseDir/jobmon/data/gridinfo.db|;
  my @joblist = @{$attr->{joblist}}; # deepcopy
  my $tjobs = scalar @joblist;

  my $stat = undef;
  my $nCached = 0;
  if (-e $inputFile) {
    # read the cached file anyway for the static information
    $stat = stat($inputFile) or croak qq|Failed to stat $inputFile|;
    ($stat->size >= 1024) and $nCached = 1; # size is in bytes
  }

  my $dict = {};
  $self->{info} = $dict;

  my @njoblist = ();
  if ($nCached) {
    # last modification time
    my $age = time() - $stat->mtime;
    my $cacheValid = ($age < $cacheLife) ? 1 : 0;

    # build a (JID,data) map
    my $jmap = restoreInfo($inputFile);
    printf STDERR qq|INFO. Reading cached information from %s, # of entries=%d,validity=%d\n|,
       $inputFile, scalar (keys %$jmap), $cacheValid;

    for my $jid (@joblist) {
      exists $jmap->{$jid} or push @njoblist, $jid and next;
      $dict->{$jid}{gridid}   = $jmap->{$jid}{gridid};
      $dict->{$jid}{rb}       = $jmap->{$jid}{rb};
      $dict->{$jid}{subject}  = $jmap->{$jid}{subject};
      $dict->{$jid}{jobdesc}  = $jmap->{$jid}{jobdesc};
      $dict->{$jid}{role}     = $jmap->{$jid}{role};
      $dict->{$jid}{gridce}   = $jmap->{$jid}{gridce};
      $dict->{$jid}{timeleft} = ($cacheValid and defined $jmap->{$jid}{timeleft}) 
         ? $jmap->{$jid}{timeleft} - $age : undef;

      my $nv = 0;
      for my $val (values %{$dict->{$jid}}) {
	++$nv unless defined $val;
      }
      push @njoblist, $jid and next if $nv;
    }
  }
  else {
    @njoblist = @joblist;
  }
  scalar @njoblist or (show_message qq|$inputFile updated| and return);
  my $njobs = scalar @njoblist;

  # We should now refer to the DB and retrieve information
  show_message qq|$inputFile failed for $njobs out of $tjobs jobs, query DB|; 
  my $dbh = $self->{dbconn}->dbh;
  my $query = q|SELECT jid,status,grid_id,rb,subject,jobdesc,role,ceid,timeleft
       FROM jobinfo_summary 
       WHERE jid=| . join (" OR jid=", map { '?' } @njoblist[1..10]);
  print STDERR $query, "\n" if $verbose;
  my $sth = $dbh->prepare($query);
  $sth->execute(@njoblist[1..10]);
  
  my %jdict = map { $_ => 1 } @njoblist;
  while (my @row = $sth->fetchrow_array()) {
    my ($jid, $status, $gridid, $rb, $subject, $jobdesc, $role, $gridce, $timeleft) = @row;
    next unless (defined $jid and defined $status);
    $dict->{$jid}{gridid}   = $gridid;
    $dict->{$jid}{rb}       = $rb;
    $dict->{$jid}{subject}  = $subject;
    $dict->{$jid}{jobdesc}  = $jobdesc;
    $dict->{$jid}{role}     = $role;
    $dict->{$jid}{gridce}   = $gridce;
    $dict->{$jid}{timeleft} = (defined $timeleft and $timeleft>0) 
               ? $timeleft - $interval
               : $timeleft;
    delete $jdict{$jid};
  }
  $sth->finish;

  @njoblist = keys %jdict;
  scalar @njoblist or (show_message q|DB successfully provided missing info| and return);

  # Finally, information could not be found from above steps, so connect   
  $njobs = scalar @njoblist; 
  show_message qq|Grid Information missing for $njobs out of $tjobs jobs, query Core Module|; 
  my $j = Collector::GridInfoCore->new({ joblist => \@njoblist }); 
  show_message q|start - filling dictionary|; 
  my $nent = 0;
  for my $jid (@njoblist) {
    print STDERR qq|.| unless (++$nent)%10;
    $dict->{$jid}{gridid}   = $j->gridid($jid)   unless defined $dict->{$jid}{gridid};
    $dict->{$jid}{rb}       = $j->rb($jid)       unless defined $dict->{$jid}{rb};
    $dict->{$jid}{subject}  = $j->subject($jid)  unless defined $dict->{$jid}{subject};
    $dict->{$jid}{jobdesc}  = $j->jobdesc($jid)  unless defined $dict->{$jid}{jobdesc};
    $dict->{$jid}{role}     = $j->role($jid)     unless defined $dict->{$jid}{role};
    $dict->{$jid}{gridce}   = $j->gridce($jid)   unless defined $dict->{$jid}{gridce};
    $dict->{$jid}{timeleft} = $j->timeleft($jid) unless defined $dict->{$jid}{timeleft};
  }
  print STDERR qq|\n| if scalar @njoblist > 10;
  show_message q| done - filling dictionary|;
}

sub show
{
  my ($self, $jid) = @_;
  return unless (defined $jid and defined $self->gridce($jid));
  print STDERR join ("##", $jid, 
                           $self->subject($jid), 
                           $self->gridid($jid), 
                           $self->rb($jid), 
                           $self->timeleft($jid),
                           $self->jobdesc($jid), 
                           $self->role($jid),
                           $self->gridce($jid)), 
                    "\n";
}

sub DESTROY
{
  my $self = shift;
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  my $jid = shift;
  croak q|JOBID not specified!| unless defined $jid;

  if (@_) {
    return $self->{info}{$jid}{$name} = shift;
  } 
  else {
    return ( defined $self->{info}{$jid}{$name} 
           ? $self->{info}{$jid}{$name} 
           : undef );
  }
}

1;
__END__
package main;

my $jlist= [210006, 210007];
my $j = Collector::GridInfo->new({joblist => $jlist});
$j->show(210007);
