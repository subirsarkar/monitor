#!/usr/bin/env perl

use strict;
use warnings;

use dCacheTools::PnfsManager;

sub main
{
  my $pnfsid = shift;
  my $pnfsH = dCacheTools::PnfsManager->instance();
  for (@ARGV) {
    my $csum = $pnfsH->pnfs_checksum({pnfsid => $_}) || '?';
    printf "pnfsid=%s,adler32_checksum=%s\n", $_, $csum;
  }
}
main;
__END__
