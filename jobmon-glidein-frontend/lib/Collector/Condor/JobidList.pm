package Collector::Condor::JobidList;

use strict;
use warnings;
use Carp;

use Collector::Util qw/trim getHostname getCommandOutput/;
use Collector::JobidList;

use base 'Collector::JobidList';

our $VERSION = q|0.1|;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = $class->SUPER::new;
  bless $self, $class;

  $self->_initialize($attr);
  return $self;
}

sub _initialize 
{
  my ($self, $attr) = @_;
  my $command = JobInfo->clusteridCmd($attr);
  chomp(my @jidList = getCommandOutput($command));

  $self->list(\@jidList);
}

1; 
__END__
package main;
my $job = Collector::Condor::JobidList->new;
$job->show;
