package Collector::JobList;

use strict;
use warnings;
use Carp;

$Collector::JobList::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  bless { 
    _list => {} 
  }, $class;
}
sub joblist
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
  my $joblist = $self->joblist; # returns a hash reference
  for my $job (values %$joblist) {
    $job->show($stream);
  }
}

sub toString
{
  my $self = shift;
  my $output = qq||;
  my $joblist = $self->joblist; # returns a hash reference
  for my $job (values %$joblist) {
    $output .= $job->toString;
  }
  $output;
}

sub jobinfo
{
  my $self = shift;
  my $info = {};
  my $joblist = $self->joblist; # returns a hash reference
  while ( my ($jid,$job) = each %$joblist ) {
    my $ji = $job->info;
    delete $ji->{JID};
    $info->{$jid} = $ji;
  }
  $info;
}

1;
__END__
