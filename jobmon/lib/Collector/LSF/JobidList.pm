package Collector::LSF::JobidList;

use strict;
use warnings;
use Carp;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       getHostname 
                       commandFH/;
use base 'Collector::JobidList';

$Collector::LSF::JobidList::VERSION = q|1.0|;

our $statusAttr =
{
    RUN => q|R|,
   PEND => q|Q|,
   DONE => q|E|,
   EXIT => q|E|,
  SSUSP => q|H|,
  USUSP => q|H|,
  PSUSP => q|H|,
  UNKWN => q|U|,
  ZOMBI => q|U|
};

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;

  my $jidList = {};
  $self->list($jidList);

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $queues_toskip = $config->{queues_toskip} || [];

  my $command = q|bjobs -w -u all|;
  my $fh = commandFH($command, $verbose);
  return unless defined $fh;

  # keep only those jobs that belong to this CE
  my $host = getHostname();

  $fh->getline; # remove header line
  while (my $line = $fh->getline) {
    my ($jid, $status, $queue, $ce) = (split /\s+/, trim $line)[0,2,3,4];    
    next unless (defined $ce and $host eq $ce);
    next if grep { $_ eq $queue } @$queues_toskip;
    $jidList->{$jid} = $statusAttr->{$status};
  }
  $fh->close;
}

1;
__END__
package main;

my $job = new Collector::LSF::JobidList;
$job->show;
