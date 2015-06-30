#!/usr/bin/env perl
package main;

use strict;
use warnings;
use dCacheTools::Pool;

my $poolname = shift || die qq|Usage: $0 pool pnfsid1 [pnfsid2] .. [pnfsidn]\n\tstopped|;
scalar @ARGV or die qq|Usage: $0 poolname pnfsid1 [pnfsid2] .. [pnfsidn]\n\tstopped|; 

my $pool = dCacheTools::Pool->new({ name => $poolname });
$pool->alive({ refresh => 1 }) or die qq|Pool $poolname seems to be dead! stopped|; 
for my $pnfsid (@ARGV) {
  my @output = $pool->exec({ command => qq|rep rm $pnfsid -force| });
  print join ("\n", @output), "\n";
}
__END__
