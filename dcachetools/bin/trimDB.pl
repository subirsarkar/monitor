#!/usr/bin/env perl
package main;

use strict;
use warnings;

use BaseTools::ConfigReader;
use BaseTools::Util qw/restoreInfo storeInfo/;
use dCacheTools::Companion;

sub main
{
  my $reader = BaseTools::ConfigReader->instance();
  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};

  my $dbfile = qq|$cacheDir/pnfsid2pfn.db|;
  my $info = restoreInfo($dbfile);

  my $dbc = dCacheTools::Companion->new;
  while ( my ($pnfsid) = each %$info) {
    unless ( scalar $dbc->pools({ pnfsid => $pnfsid })) {
      delete $info->{$pnfsid};
    }
  }
  storeInfo($dbfile, $info);
}
main;
__END__
