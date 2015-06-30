#!/usr/bin/perl
package main;

use strict;
use warnings;

use dCacheTools::Companion;
use dCacheTools::Pool;

scalar @ARGV or die qq|Usage: $0 pnfsid1 [pnfsid2] .. [pnfsidn]\n\tstopped|; 
my $dbc = dCacheTools::Companion->new;
for my $pnfsid (@ARGV) {
  next unless $pnfsid =~ /^[0-9A-F]{24,}$/;
  print qq|>>> Processing PNFSID=$pnfsid\n|;
  my @pools = $dbc->pools({ pnfsid => $pnfsid });
  for my $p (@pools) {
    my $pool = dCacheTools::Pool->new({ name => $p });
    my @result = $pool->exec({ command => qq|rep ls -l $pnfsid| });
    $pool->alive or warn qq|Pool $p did not respond! skipped\n| and next;
    printf qq|%15s %s\n|, $p, join(' ', @result);
  }
}
__END__
