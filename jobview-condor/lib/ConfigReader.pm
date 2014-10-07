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

  my $configFile = (exists $ENV{JOBVIEW_CONFIG_DIR} and -r qq|$ENV{JOBVIEW_CONFIG_DIR}/config.pl|)
     ? qq|$ENV{JOBVIEW_CONFIG_DIR}/config.pl|
     : qq|config.pl|;

  my $config;
  # read the configuration file
  unless ($config = do $configFile) {
    croak qq|Could not parse $configFile: $@| if $@;
    croak qq|Could not do $configFile: $!| unless defined $config;
    croak qq|Could not run $configFile| unless $config;
  }

  # Ensure existence of some attributes and set default
  defined $config->{baseDir} or croak q|Application baseDir undefined!|;
  defined $config->{domain} or croak q|Domain undefined!|;
  defined $config->{collector} or croak q|Condor collector undefined!|;

  $config->{batch} = q|Condor| unless defined $config->{batch}; 
  $config->{html} = qq|$config->{baseDir}/html/overview.html| unless defined $config->{html}; 

  $config->{rrd}{db} = qq|filen.rrd| unless defined $config->{rrd}{db};
  $config->{rrd}{location} = qq|$config->{baseDir}/db| unless defined $config->{rrd}{location};
  $config->{rrd}{supportedGroups} = [] unless defined $config->{rrd}{supportedGroups};
  $config->{rrd}{step}   = 180 unless defined $config->{rrd}{step};
  $config->{rrd}{width}  = 300 unless defined $config->{rrd}{width};
  $config->{rrd}{height} = 100 unless defined $config->{rrd}{height};

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
