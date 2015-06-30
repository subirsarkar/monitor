package dCacheTools::FilelistInPath;

use strict;
use warnings;
use Carp;

use BaseTools::ConfigReader;
use BaseTools::Util qw/readDir traverseDir/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|path missing| unless defined $attr->{path};

  # Read the pathname
  my $path = $attr->{path};
  my $pnfsroot = $attr->{pnfsroot};
  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }

  $path = $pnfsroot.$path unless $path =~ m#^/pnfs/#;
  -d $path or croak qq|$path is not a valid path!|;

  my @list = ($attr->{recursive}) ? traverseDir($path) : readDir($path);
  bless { filelist => \@list }, $class;
}
sub filelist
{
  my $self = shift;
  $self->{filelist};
}

1;
__END__
