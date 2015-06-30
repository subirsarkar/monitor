#!/usr/bin/env perl
package main;

use strict;
use warnings;

use BaseTools::MyStore;
use BaseTools::Util;
use BaseTools::ConfigReader;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::PnfsManager;

my $modeDict = 
{
   error => [ q|e|, q|Error| ],
   inuse => [ q|u|, q|Use| ],
  locked => [ q|l|, q|Locked| ]
};

sub main
{
  # We do not need the detailed info
  my $pm    = dCacheTools::PoolManager->instance({ parse_all => 0 });
  my $pnfsH = dCacheTools::PnfsManager->instance();
  my @poollist = $pm->poollist;

  my $reader = BaseTools::ConfigReader->instance();
  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
  my $dbfile = qq|$cacheDir/pnfsid2pfn.db|;
  my $store = BaseTools::MyStore->new({ dbfile => $dbfile });
  my $skip_vos = $reader->{config}{skip_vos} || [];

  for my $mode (sort keys %$modeDict) {
    print qq|=======================\nFiles in $modeDict->{$mode}[1] State\n=======================\n|;
    printf qq|%12s %24s %20s %12s %s\n|, q|Pool|, q|pnfsid|, q|Status|, q|Size|, q|Filename|;
    for my $poolname (@poollist) {
      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;

      my @result = $pool->exec({ command => qq|rep ls -l=$modeDict->{$mode}[0]| });
      warn qq|>>> $poolname did not respond| 
        and next unless ($pool->alive and not $pool->hasException);

      foreach my $output (@result) {
        my ($pnfsid, $status, $size, $sclass) = (split /\s+/, $output); 
        my $vo = ($sclass =~ /si={(\w+?):(?:.*)}/) ? $1 : '?';
        warn qq|Problem with $poolname replica ($sclass): $output | and next if $vo eq '?';
        next if grep /$vo/, @$skip_vos;

        my $pfn = ($store->contains($pnfsid)) 
              ? $store->get($pnfsid)
              : ($pnfsH->pathfinder($pnfsid) || '?');
        printf qq|%12s %24s %20s %12U %s\n|, $poolname, $pnfsid, $status, $size, $pfn;
      }
    }
  }
}
main;
__END__
