package dCacheTools::Companion;

use strict;
use warnings;
use Carp;

use BaseTools::ObjectFactory;
use BaseTools::ConfigReader;

our $source_types =
{
     pnfs => q|dCacheTools::CompanionDB|,
  chimera => q|dCacheTools::ChimeraCompanionDB|
};

sub new
{
  my $this = shift;
  my $class = ref $this || $this;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};

  my $namespace = $config->{namespace} || q|pnfs|;
  my $dclass = $source_types->{$namespace};
  my $obj = BaseTools::ObjectFactory->instantiate($dclass);

  bless { _baseobj => $obj }, $class;
}

sub pools
{
  my ($self, $params) = @_;
  carp q|>>> PNFSID not provided!| and return () unless defined $params->{pnfsid};
  my $obj = $self->{_baseobj};
  $obj->pools($params);
}

1;
__END__
