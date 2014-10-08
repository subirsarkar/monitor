package Collector::dCache::Transfers;
 
use strict;
use warnings;

use WebTools::Page;
use Net::Domain qw/hostfqdn/;
use Collector::Util qw/trim/;

$Collector::dCache::Transfers::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  # read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $url = $config->{storageinfo}{url};
  my $self = bless {
    _rows => {}
  }, $class;
  $self->_initialize($url);
  $self;
}
sub _initialize
{
  my ($self, $url) = @_;

  # read transfer table and store in an array of array-ref
  my $h = WebTools::Page->Table({ url => $url });
  $self->{_rows} = $h;
}  
sub getline
{
  my ($self, $attr) = @_;
  return undef unless defined $attr->{pids};

  my $hostname = lc hostfqdn;

  my %pidDict = map { $_ => 1 } @{$attr->{pids}}; # for fast indexing
  my @rows = @{$self->{_rows}};

  my $headers = shift @rows;

  # skip 'owner', 'process', 'host' and arrange the positional indexes
  my @list = (11,10,6,7,12,13,3,0..2,9);

  my $sep = ' ' x 4;
  my $line = '';
  for my $row (@rows) {
    my $pid  = trim $row->[5]; # process ID
    my $client = trim $row->[8];  # host
    next unless (defined $pidDict{$pid} and $hostname eq $client);

    $line .= (sprintf qq|%5d|, $pid).qq|\n$sep\\_ dCache: |;
    for my $i (@list) {
      $line .= qq|$headers->[$i]=$row->[$i] | if defined $row->[$i];
    }
    $line .= "\n";
  }
  $line;
}

1;
__END__
