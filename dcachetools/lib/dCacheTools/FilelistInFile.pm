package dCacheTools::FilelistInFile;

use strict;
use warnings;
use Carp;

use BaseTools::Util qw/readFile/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Input file with pfn/lfn list missing| unless defined $attr->{infile};

  my $infile = $attr->{infile};
  croak qq|File $infile is not readable! stopped| unless -r $infile;

  my $ecode = 0;
  chomp(my @list = readFile($infile, \$ecode));
  $ecode and croak qq|Failed to read $infile|;

  bless { filelist => \@list }, $class;
}
sub filelist
{
  my $self = shift;
  $self->{filelist};
}

1;
__END__
