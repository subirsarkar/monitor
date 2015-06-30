package dCacheTools::FilelistInDataset;

use strict;
use warnings;
use Carp;

use WebTools::PhedexSvc;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|dataset name missing| unless defined $attr->{dataset};

  # Read the pathname
  my $dataset = $attr->{dataset};
  my $svc = WebTools::PhedexSvc->new({ verbose => 0 });
  my $node = $attr->{node} || undef;
  unless (defined $node) {
    my $reader = BaseTools::ConfigReader->instance();
    $node = $reader->{config}{node};
  }
  $svc->query({ node => $node });
  my $files = $svc->files($dataset);
  my @list = sort keys %$files;
  bless { filelist => \@list }, $class;
}
sub filelist
{
  my $self = shift;
  $self->{filelist};
}

1;
__END__
