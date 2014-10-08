package Collector::Condor::JobInfo;

use strict;
use warnings;
use Carp;
use HTTP::Date;

use Collector::Util qw/trim getCommandOutput/;

our $VERSION = qq|0.1|;
use constant NEGN => -1;
use constant SCALE => 1024;
our $AUTOLOAD;
my $fields = 
{
             JID => NEGN,
            USER => q|?|,
           GROUP => q|?|,
           QUEUE => q|?|,
          STATUS => q|?|,
           QTIME => NEGN,
           START => NEGN,
             END => NEGN,
       EXEC_HOST => q|?|,
         CPUTIME => NEGN,
        WALLTIME => NEGN,
             MEM => NEGN,
            VMEM => NEGN,
           EX_ST => NEGN,
       DONE_TIME => NEGN
};
our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $statusAttr = 
{
    RUN => qq|2|,
   PEND => qq|1|,
   DONE => qq|4|,
   EXIT => qq|3|,
  UNKWN => qq|5|
};

sub new ($$)
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = bless {}, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize($$)
{
  my ($self, $attr) = @_;

  my @lines;
  if (defined $attr->{text}) { 
    my $text = $attr->{text};
    @lines = split /\n/, $$text;
  }
  else {
    croak qq|Must specify a valid JOBID| unless exists $attr->{jobid};
    my $user = (exists $attr->{user} && $attr->{user} !~ /^all$/)  ? "-submitter $attr->{user}" : qq||;

    my $command = qq|condor_q -global $user -l $attr->{jobid}|;
    chomp(@lines = getCommandOutput($command));
  }
  @lines = map {trim $_} @lines;

  for (@lines)  {
    next if /^$/;         # Skip empty lines

    if (/^ClusterId = (\d+?)/) {
      $info->{JID} = $1;
    } elsif (/^ProcId = (\d+?)/) {
      $info->{JID} = "$info->{JID}.$1";
    } elsif (/^Owner = (.*?)/) {
      $info->{USER} = $1; 
    } elsif (/^JobStatus = (\d+?)/) {
      my $status = $1;
      $info->{STATUS} = $statusAttr->{$status}; 
    } elsif (/(.*?)-- Schedd: (.*?) : /) {
      $info->{QUEUE}  = $1;
    } elsif (/^QDate = (\d+?)/) {
      $info->{QTIME}  = $1; 
    } elsif (/^RemoteHost = ".*"@"(.*?)"/) {
      $info->{EXEC_HOST}  = $1;
    } elsif (/^JobCurrentStartDate = (\d+?)/) {
      $info->{START} = $1;
    } elsif (/^CompletionDate = (\d+?)/) {
      $info->{DONE_TIME} = $1; # qq|?|;
    } elsif (/^RemoteUserCpu = (.*?)\.(.*)/) {
      $info->{CPUTIME} = $1; 
    } elsif (/^ImageSize = (.*?)/) {
      $info->{VMEM} = $1; $info->{MEM} *= $conv->{K};
    } elsif (/^DiskUsage = (.*?)/) {
      $info->{MEM} = $1; $info->{VMEM} *= $conv->{K};
    }
  }
  my $queueTime = $info->{QTIME};
  my $startTime = $info->{START};
  my $currentTime = time();
  $info->{WALLTIME} = ($info->{STATUS} eq 'Q') ? -1 : ($currentTime - $startTime);

  # Finally the group the user belongs to
  # We should use a little map for this purpose and should not
  # recalculate it for each user, so I prefer to do it on step up
  $self->{_INFO} = $info;
}

sub info($) 
{
  my $self = shift;
  $self->{_INFO};
}

sub jid($)
{
  my $self = shift;
  $self->{_INFO}{JID};
}

sub show($$)
{
  my $self = shift;
  my $stream = shift || *STDOUT;
  print $stream $self->toString;
}

sub toString($)
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

   croak qq|Failed to access $name field in class $type| unless exists $self->{_permitted}->{$name};

   if (@_) {
     return $self->{_INFO}{$name} = shift;
   } 
   else {
     return $self->{_INFO}{$name} || $self->{_permitted}->{$name};
   }
}

1;
__END__
package main;

my $jid  = shift || die qq|Usage $0 JID|;
my $job = new Collector::Condor::JobInfo({jobid => $jid});
$job->show;
