package Collector::Lustre::Transfers;
 
use strict;
use warnings;
use Carp;
use Net::Domain qw/hostfqdn/;

use Collector::ConfigReader;
use Collector::Util qw/trim commandFH/;

$Collector::Lustre::Transfers::VERSION = q|1.0|;

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
  $url = '/lustre' unless defined $url;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  # read transfer table and store in an array of array-ref
  my $rows = {};
  my $command = qq|lsof $url|;
  my $fh = commandFH($url, $verbose);
  if (defined $fh) {
    while (my $line = <$fh>) {
      my ($app, $pid, $user, $file) = (split /\s+/, trim $line)[0,1,2,-1];
      next unless (defined $pid and $pid =~ /\s+/);
      $rows->{$user}{$pid} = {info => $line};
    }
    $fh->close;
  }
  $self->{_rows} = $rows;
}  
sub getline
{
  my ($self, $attr) = @_;
  return undef unless (defined $attr->{pids} and defined $attr->{user});
  my $hostname = lc hostfqdn;

  my $rows = $self->{_rows};
  my @pidList = @{$attr->{pids}};
  my $user = $attr->{user};
  my $line = '';
  my $sep = ' ' x 4;
  for my $pid (@pidList) {
    next unless exists $rows->{$user}{$pid};
    my $info = $rows->{$user}{$pid}{info};
    $line .= (sprintf qq|%5d|, $pid).qq|\n$sep\\_ Lustre: |
          . qq|$info\n|;
  }
  $line;
}

1;
__END__
cmsRun  7226 aocampor  122r   REG 1273,181606 2031005326   3304575 /lustre/cms/phedex/store/mc/Summer09/QCD_Pt250to500-madgraph/GEN-SIM-RECO/MC_31X_V3_7TeV-v3/0004/B64C6249-4229-DF11-88D0-003048D479D8.root
