package Collector::ConfigReader;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Class::Singleton;

use base 'Class::Singleton';

our $stdConfigFile = q|Collector/config.pl|;

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $configFile = (defined $attr && exists $attr->{config_file})
        ? $attr->{config_file}
        : $stdConfigFile;

  my $config;
  # read the configuration file
  unless ($config = do $configFile) {
    croak qq|Could not parse $configFile: $@| if $@;
    croak qq|Could not do $configFile: $!|    unless defined $config;
    croak qq|Could not run $configFile|       unless $config;
  }

  # Ensure existence of some attributes and set default
  defined $config->{baseDir} or croak q|Application baseDir undefined!|;
  defined $config->{domain} or croak q|Domain undefined!|;

  $config->{batch} = q|pbs| unless defined $config->{batch}; 
  $config->{html} = qq|$config->{baseDir}/html/overview.html| 
    unless defined $config->{html}; 

  $config->{rrd}{db} = q|filen.rrd| unless defined $config->{rrd}{db};
  $config->{rrd}{location} = qq|$config->{baseDir}/db| 
    unless defined $config->{rrd}{location};
  $config->{rrd}{supportedGroups} = [] 
    unless defined $config->{rrd}{supportedGroups};
  $config->{rrd}{step}   = 180 unless defined $config->{rrd}{step};
  $config->{rrd}{width}  = 300 unless defined $config->{rrd}{width};
  $config->{rrd}{height} = 100 unless defined $config->{rrd}{height};

  $config->{db}{dnmap} = qq|$config->{baseDir}/db/dnmap.db| 
    unless defined $config->{db}{dnmap};
  $config->{db}{jobinfo} = qq|$config->{baseDir}/db/jobinfo.db| 
    unless defined $config->{db}{jobinfo};
  $config->{db}{slot} = qq|$config->{baseDir}/db/slots.db| 
    unless defined $config->{db}{slot};
  $config->{db}{priority} = qq|$config->{baseDir}/db/prio.db| 
    unless defined $config->{db}{priority};

  # Ensure existence of some attributes and set default
  $config->{verbose} = 0 unless exists $config->{verbose};
  $config->{debug}   = 0 unless exists $config->{debug};

  bless { _config => $config }, $class;  
}

sub config
{
  my $self = shift;
  $self->{_config};
}

sub show
{
  my $self = shift;
  my $config = $self->config;
  print Data::Dumper->Dump([$config], [qw/cfg/]); 
}

1;
__END__
