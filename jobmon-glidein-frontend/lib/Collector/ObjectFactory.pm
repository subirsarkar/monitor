package Collector::ObjectFactory;

use strict;
use warnings;
use Carp;

$Collector::ObjectFactory::VERSION = q|1.0|;

sub instantiate
{
  my $this = shift;   # must shift the arguments
  my $class = ref $this || $this; 
  my $type  = shift;
  my $location = qq|$type.pm|;
  $location =~ s/::/\//g;
  $class = $type;

  require $location;
  $class->new(@_); # pass the rest to the real class
}

1;
__END__
