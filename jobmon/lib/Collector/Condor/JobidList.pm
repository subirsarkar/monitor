package Collector::Condor::JobidList;

use strict;
use warnings;
use Carp;

use Collector::Util qw/trim getHostname getCommandOutput/;
use Collector::JobidList;

use base 'Collector::JobidList';

our $VERSION = qq|0.1|;

sub new($$)
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize($attr);
  return $self;
}

sub _initialize($$) 
{
  my ($self, $attr) = @_;
  my $user  = (exists $attr->{user}  && $attr->{user}  !~ /^all$/) ? "-submitter $attr->{user}"    : qq||;
  my $state = (exists $attr->{state} && $attr->{state} !~ /^$/)    ? "State == $attr->{state} && " : qq||;

  my $host = getHostname();
  my $command = qq|/opt/condor/bin/condor_q -global $user -constraint "$state substr(RemoteHost,6) == \\"$host.fnal.gov\\""|;
  $command   .= qq| -format "%d." ClusterID -format "%d\\n" ProcID|;
  chomp(my @jobList = getCommandOutput($command));

  # keep only those jobs that belong to this CE
  my $jidList = [ map {(split)[0]} 
                   grep {//} @jobList ];

  $self->list($jidList);
}

1; 
__END__
package main;
my $job = new Collector::Condor::JobidList;
$job->show;
