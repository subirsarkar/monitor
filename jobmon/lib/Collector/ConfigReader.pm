package Collector::ConfigReader;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Class::Singleton;

use base 'Class::Singleton';

my $configFile = (exists $ENV{JOBMON_CONFIG_DIR} and -r qq|$ENV{JOBMON_CONFIG_DIR}/config.pl|) 
        ? qq|$ENV{JOBMON_CONFIG_DIR}/config.pl| 
        :  q|Collector/config.pl|;

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  # read the configuration file
  my $config;
  unless ($config = do $configFile) {
    croak qq|Could not parse $configFile: $@| if $@;
    croak qq|Could not do $configFile: $!|    unless defined $config;
    croak qq|Could not run $configFile|       unless $config;
  }

  # Ensure existence of some attributes and set default
  $config->{xmldir}  = qq|$config->{baseDir}/jobmon/data| unless defined $config->{xmldir}; 
  $config->{lrms}    = q|lsf|                             unless defined $config->{lrms};
  $config->{lrms} = lc $config->{lrms};

  $config->{verbose} = 0 unless defined $config->{verbose}; 
  $config->{debug}   = 0 unless defined $config->{debug}; 

  $config->{cachelife}{jobinfo}       =  3 * 60    unless defined $config->{cachelife}{jobinfo}; 
  $config->{cachelife}{gridinfo}      = 10 * 60    unless defined $config->{cachelife}{gridinfo}; 
  $config->{nodeinfo}{nlines}         = 300        unless defined $config->{nodeinfo}{nlines}; 
  $config->{nodeinfo}{validityPeriod} =  72 * 3600 unless defined $config->{nodeinfo}{validityPeriod}; 

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
