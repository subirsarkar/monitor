package LSF::CompletedJobInfo;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use HTTP::Date;
use List::Util qw/min/;

use LSF::ConfigReader;
use LSF::Util qw/trim/;

$LSF::CompletedJobInfo::VERSION = q|0.1|;

$| = 1;

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
            EX_ST
            NCORE
            UI_HOST/;

use constant SCALE => 1024;

our $statusAttr = 
{
  'DONE' => 0,
  'EXIT' => 1
};
our $conv =
{
  K => 1,
  M => SCALE,
  G => SCALE**2,
  T => SCALE**3,
};

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  croak q|Input line missing!| unless defined $attr->{line};

  my $self = bless {
    _permitted => \%fields
  }, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize
{
  my ($self, $attr) = @_;

  my $text = $attr->{line};
  my $dict = $attr->{dict};

  my $verbose = $attr->{verbose} || 0;
  print STDERR $text, "\n" if $verbose;

  my $config = LSF::ConfigReader->instance()->config;
  my $batch  = $config->{batch};

  my $info = {};
  my $lndx = 0;
  my @lines = map {trim $_ }
                grep {! $_ =~ /^$/}
                  (split /\n/, $text);
  for (@lines) {
    $lndx++;
    if (/^Job\s*<(.*?)>/) {
      my $jobid = $1;
      $jobid =~ /(\d+)(?:\[\d+\])?/; # handle job array
      my $jid = $1;
      if (exists $dict->{$jid}) {
        $info->{JID} = $jobid;
        $info->{USER}  = $dict->{$jid}[0];
        $info->{QUEUE} = $dict->{$jid}[1];
        $info->{UI_HOST} = $dict->{$jid}[2];
        $info->{QTIME} = $dict->{$jid}[3];
        $info->{START} = $dict->{$jid}[4];
        $info->{END}   = $dict->{$jid}[5];
      }
      else {
        print qq|>>> JID=$jobid, $jid\n|;
      } 
    }
    elsif (/(?:.*?)\s*Dispatched\s*to\s*<(.*?)>/) {
      $info->{EXEC_HOST} = $1;
      $info->{NCORE}     = 1;
    }
    elsif (m#(?:.*?)\s*Dispatched\s*to\s*<(\d+?)>Hosts/Processors\s*<(.*?)>#) {
      $info->{NCORE} = $1;
      my $host = $2;
      $info->{EXEC_HOST} = (split /\*/, $host)[-1] if defined $host;
    } 
    elsif (/^CPU_T/) {
      my ($cputime, $wait, $turnaround, $status, $hog_f, $mem, $vmem) = (split /\s+/, $lines[$lndx]);
      $info->{CPUTIME} = $cputime;

      my $munit = chop $mem; 
      my $vunit = chop $vmem; 
      $info->{MEM} = $conv->{$munit} * $mem;
      $info->{VMEM} = $conv->{$vunit} * $vmem;

      $info->{STATUS} = uc $status unless defined $info->{STATUS};
      last;
    }
  }
  $info->{EX_ST} = (defined $statusAttr->{$info->{STATUS}}) ? $statusAttr->{$info->{STATUS}} : 2;
  if (defined $info->{START} and defined $info->{END}) {
    $info->{WALLTIME} = ($info->{START} <= 0 or $info->{END} <= 0) ? 0 : $info->{END} - $info->{START};
    $info->{CPUTIME} = min($info->{WALLTIME}, $info->{CPUTIME});
  }
  else {
    $info->{WALLTIME} = $info->{CPUTIME} = 0;
  }
  print Data::Dumper->Dump([$info], [qw/jobinfo/]) if $verbose;

  $self->{_info} = $info;
}

sub info
{
  my $self = shift;
  $self->{_info};
}

sub UI
{
  my $self = shift;
  my $info = $self->info;
  $info->{UI_HOST};
}
sub jid
{
  my $self = shift;
  my $info = $self->info;
  $info->{JID};
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

  my $info = $self->info;
  if (@_) {
    return $info->{$name} = shift;
  } 
  else {
    return ( defined $info->{$name}
           ? trim($info->{$name}) 
           : undef );
  }
}

# AUTOLOAD/carp fallout
sub DESTROY 
{ 
  my $self = shift;
}

1;
__END__
##$line =~ s|"#!\s?(?:.*?)"\s+||;
