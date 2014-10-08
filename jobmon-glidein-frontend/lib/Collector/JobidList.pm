package Collector::JobidList;

use strict;
use warnings;
use Carp;

$Collector::JobidList::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  bless { 
    _list => {} 
  }, $class;
}
sub list
{
  my $self = shift;
  if (@_) {
    return $self->{_list} = shift;
  } 
  else {
    return $self->{_list};
  }
}

sub show
{
  my $self = shift;
  print STDERR join ("\n", sort keys %{$self->list}), "\n"; 
}

1;
__END__
