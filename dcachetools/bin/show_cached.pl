#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

# We do not need the detailed info
my $pm = dCacheTools::PoolManager->instance({ parse_all => 0 });
for my $poolname ($pm->poollist) {
  my $pool = dCacheTools::Pool->new({ name => $poolname });
  $pool->online or next;
  print qq|>>> $poolname\n|;
  print join("\n", $pool->exec({ command => q|sweeper ls| })),"\n";
}
__END__
