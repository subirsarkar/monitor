package AvailableServers;

use strict;
use warnings;
use Carp;
use Data::Dumper;

#use JSON;
use Util qw/trim/;
use ConfigReader;
use WebTools::Page;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  bless {
    _info => {}
  }, $class;
}
sub parse 
{
  my ($self, $attr) = @_;
  $self->{_info} = {};
  my $url = $attr->{url} || q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AvailableServerList|;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $server_blacklist = $config->{server_blacklist} || [];
  my $content = WebTools::Page->Content({ url => $url });
  return unless length $content;
#  my $json = new JSON;
  my $info = $self->{_info};
  for (split /\n/, $content) {
    (/^$/ or /^#/) and next;
    my $server = (split)[0];
    my $url = q|http://cmsdoc.cern.ch/cms/LCG/crab/config/server_| . $server . q|.conf|;
    my $content = WebTools::Page->Content({ url => $url });
    next unless length $content;
#    my $obj = $json->jsonToObj($content);
    for (split /\n/, $content) {
      if (/serverName/) {
        my $sname = (split /:/)[-1];
        $sname =~ s#'##g; $sname =~ s#,\\##;
        my $fname = (split /\./, $sname)[0];
        next if grep {$_ eq $fname } @$server_blacklist;
        $info->{$server}{webserver} = $sname; # $obj->{serverName};     
      }
    }
  }
  $self;
}
sub dump
{
  my $self = shift;
  my $info = $self->{_info};
  print Data::Dumper->Dump([$info], [qw/servers/]);  
}
sub list
{
  my $self = shift;
  my $info = $self->{_info};
  keys %$info;
}
sub webserver
{
  my ($self, $server) = @_;
  defined $server or return undef;
  my $info = $self->{_info};
  $info->{$server}{webserver};
}

1;
__END__
my $as = AvailableServers->new;
$as->parse;
$as->dump;
