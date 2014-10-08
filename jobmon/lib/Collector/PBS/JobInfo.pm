package Collector::PBS::JobInfo;

use strict;
use warnings;
use Carp;
use HTTP::Date;

use Collector::Util qw/trim/;

$Collector::PBS::JobInfo::VERSION = q|1.0|;

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
             RANK
             PRIORITY/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 
  bless {
    _permitted => \%fields,
    _INFO      => {}
  }, $class;
}
sub info
{
  my $self = shift;
  $self->{_INFO};
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
  my $output = sprintf (qq|\n{%s}{%s}{%s}\n|, $info->{GROUP}, $info->{QUEUE}, $info->{JID});
  for my $key (sort keys %$info) {
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
