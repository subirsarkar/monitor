package WebPage;

use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK);

use strict;
use warnings;

use LWP 5.64;
use URI;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( getURL );
@EXPORT_OK = qw( );
$VERSION = "0.5";

use constant DEBUG => 0;

sub getURL($$);

sub getURL($$)
{
  my ($web_site, $param) = @_;

  # makes an object representing the URL
  my $ua = new LWP::UserAgent;
  $ua->timeout(20);

  $web_site .= "?";
  for my $key (sort keys %$param) {
    $web_site .= "&".$key."=".$param->{$key};
  }
  $web_site =~ s/\&//;

  my $content = '';
  my $url = new URI($web_site);
  my $response;
  eval {
    $response = $ua->get($url);
  };
  if ($@) {
    warn qq[WebPage::getURL. Site $web_site unavailable!, $?];
    return $content;
  }
  unless ($response->is_success) {
    warn "WebPage::getURL. Couldn't get $url -- ", $response->status_line;
    return $content;
  }

  $content = $response->content;
  print STDERR $content if DEBUG;
  warn "INFO. No information found!" if not length($content);

  $content;
}

1;
__END__
