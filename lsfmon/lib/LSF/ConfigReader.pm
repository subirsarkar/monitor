package LSF::ConfigReader;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use base 'Class::Singleton';

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $configFile = (exists $ENV{LSFMON_CONFIG_DIR} and -r qq|$ENV{LSFMON_CONFIG_DIR}/config.pl|) 
     ? qq|$ENV{LSFMON_CONFIG_DIR}/config.pl| 
     : qq|LSF/config.pl|;

  my $config;
  # read the configuration file
  unless ($config = do $configFile) {
    croak qq|Could not parse $configFile: $@| if $@;
    croak qq|Could not do $configFile: $!|    unless defined $config;
    croak qq|Could not run $configFile|       unless $config;
  }
  defined $config->{baseDir} or croak q|Application baseDir undefined!|;

  # Set defaults
  $config->{batch} = 'LSF' unless defined $config->{batch};
  $config->{batch_version} = '6.2' unless defined $config->{batch_version};

  $config->{accounting}{template_period} = qq|$config->{baseDir}/tmpl/acct_period.html.tmpl|
      unless defined $config->{accounting}{template_period};
  $config->{accounting}{template_full}= qq|$config->{baseDir}/tmpl/acct_overall.html.tmpl|
      unless defined $config->{accounting}{template_full};

  $config->{accounting}{dbFile} = qq|$config->{baseDir}/db/acctinfo.db| 
      unless defined $config->{accounting}{dbFile};
  $config->{plotcreator}{defaultColor} = q|#ca940c|
      unless defined $config->{plotcreator}{defaultColor};

  $config->{rrd}{db} = q|filen.rrd| unless defined $config->{rrd}{db};
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
