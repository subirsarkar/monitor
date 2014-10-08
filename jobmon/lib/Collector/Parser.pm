package Collector::Parser;

use strict;
use warnings;
use Carp;
use Data::Dumper;

$Collector::Parser::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  bless { 
    _info => {} 
  }, $class;
}
sub info
{
  my $self = shift;
  if (@_) {
    return $self->{_info} = shift;
  } 
  else {
    return $self->{_info};
  }
}
sub show
{
  my $self = shift;
  my $info = $self->info;
  return unless defined $info;

  print Data::Dumper->Dump([$info], [qw/info/]);    
}

1;
__END__
