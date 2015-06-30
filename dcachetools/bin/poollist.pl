#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

# We do not need the detailed info
my $pm = dCacheTools::PoolManager->instance();
for my $poolname ($pm->poollist) {
  my $pool = dCacheTools::Pool->new({ name => $poolname });
  $pool->online or next;
  printf qq|%s:%s:%s:%d\n|, $pool->host, $pool->path.q|/data|, $poolname, ($pool->enabled ? 1 : 0);
}
__END__
cmsdcache1:/storage/d1/pool/data:cmsdcache1_1:1
