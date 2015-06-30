#!/usr/bin/env perl
package main;

use strict;
use warnings;

use BaseTools::ConfigReader;
use BaseTools::MyStore;
use dCacheTools::PnfsManager;

scalar @ARGV or die qq|Usage: perl -w $0 pnfsid [pnfsid1]...[pnfsidn]\n\tstopped|;

my $reader = BaseTools::ConfigReader->instance();
my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
my $dbfile = qq|$cacheDir/pnfsid2pfn.db|;
my $store = BaseTools::MyStore->new({ dbfile => $dbfile });
my $pnfsH = dCacheTools::PnfsManager->instance();
for my $pnfsid (@ARGV) {
  next unless $pnfsid =~ /[0-9A-F]{24,}/;

  my $pfn = ($store->contains($pnfsid)) 
       ? $store->get($pnfsid)
       : ($pnfsH->pathfinder($pnfsid) || '?');

  # Now find the pool 
  my @poolList = $pnfsH->pools($pnfsid);
  push @poolList, q|?| unless scalar @poolList;
  print STDOUT join (' ', $pnfsid, $pfn, @poolList), "\n";
}
__END__
