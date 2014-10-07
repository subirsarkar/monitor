package Collector::PBS::GridmapReader;

use strict;
use warnings;
use Carp;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       read_dnmap/;
use base 'Collector::Parser';
use Collector::PBS::GridmapParser;

$Collector::PBS::GridmapReader::VERSION = q|0.9|;

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
  my $verbose = $config->{verbose} || 0;

  my $info = {};
  $self->info($info);

  # parser files for this CE
  my $parser = new Collector::PBS::GridmapParser;
  my $dnmap = $parser->dnmap;

  # read mapping files for other CEs
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
