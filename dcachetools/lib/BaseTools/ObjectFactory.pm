package BaseTools::ObjectFactory;

use strict;
use warnings;

sub instantiate
{
  my $this = shift;   # must shift the arguments
  my $class = ref $this || $this; 
  my $type  = shift;

  eval "require $type";
  $type->new(@_); # pass the rest to the real class
}
sub get_instance
{
  my $this = shift;   # must shift the arguments
  my $class = ref $this || $this; 
  my $type  = shift;

  eval "require $type";
  $type->instance(@_); # pass the rest to the real class
}

1;
__END__
