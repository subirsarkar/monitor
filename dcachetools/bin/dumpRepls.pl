#!/usr/bin/env perl
package main;

use strict;
use warnings;

use Term::ProgressBar;
use List::Util qw/min max/;

use BaseTools::ConfigReader;
use BaseTools::Util qw/storeInfo/;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Replica;

sub main
{
  my $reader = BaseTools::ConfigReader->instance();
  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
  my $dbfile = qq|$cacheDir/replica.db|;

  my $rColl = {};
  my $ri = dCacheTools::Replica->new;
  # We do not need the detailed info
  my @poollist = dCacheTools::PoolManager->instance({ parse_all => 0 })->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);

  my $it = max 1, int($npools/100);
  for my $poolname (@poollist) {
    unless ( (++$ipool)%$it ) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or warn qq|$poolname not enabled/active!| and next;
    my @output = $pool->exec({ command => q|rep ls -l| });
    for (@output) {
      $ri->repls($_);
      my $pnfsid = $ri->pnfsid;
      $rColl->{$pnfsid}{$poolname}{precious} = $ri->precious;
      $rColl->{$pnfsid}{$poolname}{ls}       = $_;
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  storeInfo($dbfile, $rColl);
}
main;
__END__
