#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::Pool;

my $poolname = shift || die qq|Usage: $0 pool pnfsid1 [pnfsid2] .. [pnfsidn]\n\tstopped|;
scalar @ARGV or die qq|Usage: $0 poolname pnfsid1 [pnfsid2] .. [pnfsidn]\n\tstopped|; 

my $pool = dCacheTools::Pool->new({ name => $poolname });
die qq|Pool $poolname seems to be dead! stopped| unless $pool->alive({ refresh => 1 });
my $ri = dCacheTools::Replica->new;
for my $pnfsid (@ARGV) {
  warn qq|Error. Wrong format for PNFSID $pnfsid\n| and next unless $pnfsid =~ /[0-9A-F]{24,}/;

  # check if the replica is already precious, skip then
  my @output = $pool->exec({ command => qq|rep ls $pnfsid| });
  warn qq|No replica information for $poolname::$pnfsid| 
    and next unless scalar @output;
  $ri->repls($output[0]);
  warn qq|Replica $poolname::$pnfsid already precious! skipping| 
    and next if $ri->precious;

  # now take action
  $pool->exec({ command => qq|rep set precious $pnfsid -force| });
}
__END__
