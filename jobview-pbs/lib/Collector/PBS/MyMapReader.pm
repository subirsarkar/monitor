package Collector::PBS::MyMapReader;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                 read_dnmap/; 
use base 'Collector::Parser';

$Collector::PBS::MyMapReader::VERSION = q|0.1|;

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

  # Read the global configuration, a singleton
  my $config = Collector::ConfigReader->instance()->config;
  my $dbfiles = $config->{dnmap_files} || [];

  my $info = {};
  $self->info($info);

  # Build a (JID, DN) map
  my $dnmap = {};
  read_dnmap($dbfiles, $dnmap, $verbose);
  $info->{_dnmap} = $dnmap;
}
sub dnmap
{
  my $self = shift;
  $self->info()->{_dnmap};
}

1;
__END__
package main;
my $job = new Collector::PBS::MyMapReader;
$job->show;
