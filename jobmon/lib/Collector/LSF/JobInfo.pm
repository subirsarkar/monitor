package Collector::LSF::JobInfo;

use strict;
use warnings;
use Carp;
use HTTP::Date;
use Data::Dumper;
use List::Util qw/min/;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       getCommandOutput/;

$Collector::LSF::JobInfo::VERSION = q|1.0|;
use constant SCALE => 1024;

our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $statusAttr =
{
    RUN => q|R|,
   PEND => q|Q|,
   DONE => q|E|,
   EXIT => q|E|,
  SSUSP => q|H|,
  USUSP => q|H|,
  PSUSP => q|H|,
  UNKWN => q|U|,
  ZOMBI => q|U|
};

our $AUTOLOAD;
my %fields = map { $_ => 1 }
          qw/JID
             USER
             GROUP
             QUEUE
             STATUS
             QTIME
             START
             END
             EXEC_HOST
             CPUTIME
             WALLTIME
             MEM
             VMEM
             EX_ST/;

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
  my $info = {};

  # Now parse the bjobs -l output
  my @lines;
  if (defined $attr->{text}) { 
    my $text = $attr->{text};
    @lines = split /\n/, $$text;
  }
  else {
    croak q|Must specify a valid JOBID| unless defined $attr->{jobid};
    my $reader = Collector::ConfigReader->instance();
    my $config = $reader->config;
    my $show_error = $config->{show_cmd_error} || 0;
    my $verbose = $config->{verbose} || 0;

    my $user    = $attr->{user} || q|all|;
    my $command = qq|bjobs -l -u $user $attr->{jobid}|;
    my $ecode = 0;
    chomp(@lines = getCommandOutput($command, \$ecode, $show_error, $verbose));
  }
  for ( map { trim $_ } @lines)  {
    next if /^$/;         # Skip empty lines
    if (/^Job\s+<(\d+?(?:\[\d+\])?)>/) {
      my $jid = $1;
      $info->{JID} = $jid;
      $info->{USER} = $attr->{info}{$jid}{user} || undef;
      my $status = $attr->{info}{$jid}{status};
      $info->{STATUS} = $statusAttr->{$status} || undef;
      $info->{QUEUE}  = $attr->{info}{$jid}{queue} || undef;
    }
    elsif (/(.*?)Submitted\s+from\s+host\s+<(.*?)>/) {
      my $qtime = substr $1, 0, -2;
      $info->{QTIME} = str2time($qtime);
    }
    elsif (defined $info->{STATUS} and $info->{STATUS} ne 'Q' and $info->{STATUS} ne 'U') {
      if (/(.*?)Started\s+on(?:.*?)<(.*?)>/ or /(.*?)\s+(?:\[\d+\])\s+started\s+on(?:.*?)<(.*?)>/) {
        my $start = substr $1, 0, -2;
        $start = substr $1, 0, -1 if length($start) < 19;
        $info->{START} = str2time($start);
        $info->{EXEC_HOST} = $2;
      }
      elsif (/CPU/) {
        if ($info->{STATUS} eq 'E') {
          $info->{DONE_TIME} = undef;
          $info->{CPUTIME} = (split /\s+/)[-2];
        }
        else {
          $info->{CPUTIME} = (split /\s+/)[5];
        }
      }
      elsif (/MEM:/) {
        my ($mem, $vmem) = (split /\s+/)[1,4];
        $info->{MEM}  = ($mem  =~ /\d+/) ? int($mem)  * $conv->{K} : undef;
        $info->{VMEM} = ($vmem =~ /\d+/) ? int($vmem) * $conv->{K} : undef;
        unless (defined $info->{MEM} and defined $info->{VMEM}) {
          my $msg = qq|ERROR. Invalid parameter(s) for JID=|. ($info->{JID} || 'undefined');
          $msg .= qq|, MEM=$mem, VMEM=$vmem|;
          carp $msg;
        }
      }
    }
    last if /PGID/;
  }
  $info->{WALLTIME} = (defined $info->{START})
    ? time() - $info->{START}
    : undef;
  if (defined $info->{WALLTIME}) {
    my $cput = (defined $info->{CPUTIME} and $info->{CPUTIME} =~ /\d+/)
      ? int($info->{CPUTIME})
      : undef;
    # TODO: investigate cases where CPUTIME > WALLTIME
    $info->{CPUTIME} = (defined $cput) ? min $info->{WALLTIME}, $cput : undef;
  }
  # Finally the group the user belongs to
  # We should use a little map for this purpose and should not
  # recalculate it for each user, so I prefer to do it on step up
  $self->{_INFO} = $info;
}

sub setStatus
{
  my ($self, $status) = @_;
  return $self->{_INFO}{STATUS} = $statusAttr->{$status} || undef;
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

sub tags
{
  my $self = shift;
  sort keys %{$self->{_INFO}};
}

sub toString
{
  my $self = shift;
  my $info = $self->info;
  my $output = sprintf (qq|\n{%s}{%s}{%s}\n|, 
      $info->{GROUP}, $info->{QUEUE}, $info->{JID});
  while ( my ($key, $value) = each %$info ) {
    $output .= sprintf(qq|%s: %s\n|, $key, $value);
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
    return ( defined $self->{_INFO}{$name} 
           ? $self->{_INFO}{$name} 
           : undef );
  }
}

# AUTOLOAD/carp fallout
sub DESTROY { }

1;
__END__
package main;

my $jid  = shift || die qq|Usage: $0 JOBID|;
my $job = new Collector::LSF::JobInfo({jobid => $jid});
$job->show;
