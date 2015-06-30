package dCacheTools::Admin;

use strict;
use warnings;
use Carp;

use BaseTools::ObjectFactory;
use BaseTools::ConfigReader;
# must 'use' the following module, otherwise the INLINEed code does not work
use dCacheTools::AdminAPI;

use base 'Class::Singleton';

our $interfaceList =
{
  API => q|dCacheTools::AdminAPI|,
  SSH => q|dCacheTools::AdminSSH|
};

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader = BaseTools::ConfigReader->instance();
  my $interface = $reader->{config}{admin}{proto} || q|API|;
  my $type = $interfaceList->{$interface};
  BaseTools::ObjectFactory->get_instance($type, $attr);
}

1;
__END__
