package ConfigReader;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use base 'Class::Singleton';

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $configFile = (exists $ENV{CSMON_CONFIG_DIR} and -r qq|$ENV{CSMON_CONFIG_DIR}/config.pl|)
     ? qq|$ENV{CSMON_CONFIG_DIR}/config.pl|
     : qq|config.pl|;

  my $config;
  # read the configuration file
  unless ($config = do $configFile) {
    croak qq|Could not parse $configFile: $@| if $@;
    croak qq|Could not do $configFile: $!|    unless defined $config;
    croak qq|Could not run $configFile|       unless $config;
  }

  # Ensure existence of some attributes and set default
  defined $config->{baseDir} or croak qq|Application baseDir undefined!|;

  $config->{rrd}{location} = qq|$config->{baseDir}/db| unless defined $config->{rrd}{location};
  $config->{rrd}{step}   = 180 unless defined $config->{rrd}{step};
  $config->{rrd}{width}  = 600 unless defined $config->{rrd}{width};
  $config->{rrd}{height} = 400 unless defined $config->{rrd}{height};

  bless { 
    _config => $config 
  }, $class;  
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
