package WebTools::Page;

use strict;
use warnings;
use Carp;

use LWP 5.64;
use URI;
use HTML::TableExtract;

sub Content
{
  my ($pkg, $params) = @_;
  croak qq|URL Must be specified| unless defined $params->{url};
  my $query = $params->{url};
  $params->{verbose} = 0 unless defined $params->{verbose};

  # makes an object representing the URL
  my $agent = LWP::UserAgent->new(timeout => 20);
  if (defined $params->{options}) {
    my $options = $params->{options};
    $query .= qq[?];
    for my $key (sort keys %$options) {
      $query .= qq|&$key=$options->{$key}|;
    }
    $query =~ s/\&//;
  }

  my $content = '';
  my $uriObj = URI->new($query);
  my $response;
  eval {
    $response = $agent->get($uriObj);
  };
  if ($@) {
    carp qq|WebTools::Page::Content. Site $query unavailable!, $@|;
    return $content;
  }
  unless ($response->is_success) {
    carp qq|WebTools::Page::Content. Failed to fetch $query -- |, $response->status_line;
    return $content;
  }

  $content = $response->content;
  print STDERR $content if $params->{verbose};
  carp qq|INFO. No information found!| unless length($content);

  $content;
}

sub Table
{
  my ($pkg, $params) = @_;
  croak qq|URL Must be specified| unless defined $params->{url};
  my $query   = $params->{url};
  my $depth   = $params->{depth}   || 0;
  my $count   = $params->{count}   || 0;
  my $gridmap = $params->{gridmap} || 0;

  my $h = [];
  my $content = __PACKAGE__->Content({url => $query});
  return $h unless length $content;

  my $te = HTML::TableExtract->new( depth => $depth,
                                    count => $count,
                                  gridmap => $gridmap,
                                keep_html => 1);
  $te->parse($content);
  foreach my $ts ($te->tables) {
    foreach my $row ($ts->rows) {
      @$row = grep { defined $_ } @$row;
      push @$h, $row;
    }
  }
  $h;
}

1;
__END__
package main;

my $url = qq|http://cmsdcache:2288/context/transfers.html|;
my $content = WebTools::Page->Content({url => $url, verbose => 0});
print $content;
print "\n";

# --- Documentation starts
=pod

=head1 NAME

WebTools::Page - Utility module that has functions to (1) fetch a webpage (2) extract a table embedded in a page

=head1 SYNOPSIS

  use WebTools::Page;

  my $query = qq|http://cmsdcache:2288/queueInfo|;
  my $content = WebTools::Page->Content($query);
  my $rows = WebTools::Page->Table({ url => $query });

=head1 REQUIRES

  LWP 5.64
  URI
  HTML::TableExtract

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

A collection of module level funtions to fetch web pages in its entirety, extract an embedded table etc.

=head2 Public methods

=over 4

=item * Content ($pkg, $url, $debug, $params): $content

Fetch a web page as a string.

  $pkg - this package
  $url - The webpage to fetch
  $debug - debug flag
  $params - key/value pair in case the url requires parameters

=item * Table ($pkg, $params): @rows

Extract a table embedded in a web page as an array of row objects(TD).

  $pkg    - this package
  $params - specify the table coordinates like depth, count, gridmap etc. that can
            uniquely indentify a table. This is required by HTML::TableExtract

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Page.pm,v 1.0 2008/06/17 00:03:19 sarkar Exp $

=cut
# ----- Documentation ends
