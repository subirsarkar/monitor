package Collector::JobList;

use strict;
use warnings;
use Carp;

$Collector::JobList::VERSION = q|0.1|;

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
  my $stream = shift || *STDOUT;
  my $joblist = $self->list; # returns a hash reference
  for my $job (values %$joblist) {
    $job->show($stream);
  }
}

sub toString
{
  my $self = shift;
  my $output = q||;
  my $joblist = $self->list; # returns a hash reference
  for my $job (values %$joblist) {
    $output .= $job->toString;
  }
  $output;
}

1;
__END__
