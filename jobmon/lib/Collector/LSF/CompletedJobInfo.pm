package Collector::LSF::CompletedJobInfo;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Collector::ConfigReader;
use Collector::Util qw/trim/;

$Collector::LSF::CompletedJobInfo::VERSION = q|1.0|;
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
            CE/;
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
  my $line = $attr->{line};
  my $verbose = $attr->{verbose} || 0;
  print STDERR $line, "\n" if $verbose;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $lrms   = $config->{lrms};
  my $lrms_version = $config->{lrms_version};

  my $info = {};
  my ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem);
  my @fields = (split /\s+/, $line);
  if ($lrms_version eq '7.06') {
    ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem)
        = @fields[2,3,7,10,11,12,16,24,-50,-49,-29,-24,-23];
  }
  elsif ($lrms_version eq '7.05') {
    ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem)
        = @fields[2,3,7,10,11,12,16,24,-48,-47,-27,-22,-21];
  }
  elsif ($lrms_version eq '7.04') {
    ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem)
	= @fields[2,3,7,10,11,12,16,24,-47,-46,-26,-21,-20];
  }
  elsif ($lrms_version eq '6.2') {
    ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem)
	= @fields[2,3,7,10,11,12,16,24,-39,-38,-18,-13,-12];
  }
  elsif ($lrms_version eq '6.0') {
    ($end,$jobid,$submit,$start,$user,$queue,$ce,$host,$usertime,$systime,$exit_status,$mem,$vmem)
	= @fields[2,3,7,10,11,12,16,24,-38,-37,-17,-12,-11];
  }
  else {
    warn qq|$lrms $lrms_version not supported!| and return;
  }
  $info->{JID}       = $attr->{jid} || int($jobid);

  $user =~ s/"//g;
  $info->{USER}      = $user;

  $queue =~ s/"//g;
  $info->{QUEUE}     = $queue;
  $info->{END}       = int($end);
  $info->{QTIME}     = int($submit);
  $info->{START}     = int($start);
  $info->{EX_ST}     = int($exit_status);
  $info->{WALLTIME}  = ($info->{START} <= 0 or $info->{END} <= 0) ? 0 : $info->{END} - $info->{START};
  $info->{CPUTIME}   = (($usertime + $systime) > 0) ? sprintf "%.2f", ($usertime + $systime) : 0.0;
  $info->{MEM}       = int($mem);
  $info->{VMEM}      = int($vmem);

  $host =~ s/"//g;
  $info->{EXEC_HOST} = $host;

  $ce =~ s/"//g;
  $info->{CE}        = $ce;

  print STDERR Data::Dumper->Dump([$info], [qw/jobinfo/]) if $verbose;
  $self->{_info} = $info;
}

sub info
{
  my $self = shift;
  $self->{_info};
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
