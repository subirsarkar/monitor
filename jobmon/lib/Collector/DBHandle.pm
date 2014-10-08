package Collector::DBHandle;

use strict;
use warnings;
use Carp;

use Collector::Util qw/show_message/;
use Collector::ConfigReader;
use DBI;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $config = Collector::ConfigReader->instance()->config;
  my $dsn = qq|DBI:mysql:monitor;mysql_read_default_file=$config->{dbcfg};mysql_compression=1|;
  bless { 
    _dbh => DBI->connect($dsn, q||, q||, {PrintError => 1, RaiseError => 0}) 
  }, $class; 
}
sub dbh
{
  my $self = shift;
  $self->{_dbh};
}

sub DESTROY
{
  my $self = shift;
  my $dbh = $self->{_dbh};
  my $config = Collector::ConfigReader->instance()->config;
  my $verbose = $config->{verbose} || 0;
  show_message q|>>> Closing DB connection| if $verbose;
  $dbh->disconnect if defined $dbh;
}

1;
__END__
