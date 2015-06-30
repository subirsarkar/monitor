#!/usr/bin/env perl
package main;

use strict;
use warnings;

use BaseTools::ConfigReader;
use dCacheTools::PoolManager;
use dCacheTools::Info::PoolGroup;
use dCacheTools::Space;

use constant GB2BY => 1.0*1024**3;
use constant GB2MB => 1024.;

my $qm = 
{
  default => 'others'
};
my $reader = BaseTools::ConfigReader->instance();
my $config = $reader->{config};
my $webserver = $config->{webserver} || 'cmsdcache';
my $has_info_service = $config->{has_info_service} || 0;

print "\t-----------------------\n\tSpace usage by VOs (GB)\n\t-----------------------\n";
printf "%10s %9s %9s %9s %9s\n", "VO", "Total", "Free", "Used", "Precious";

# We do not need the detailed info
my $pm = dCacheTools::PoolManager->instance({ parse_all => 0 });
for my $vo (sort $pm->pgrouplist) {
  my $info = {};
  if ($has_info_service) {
    my $pg = dCacheTools::Info::PoolGroup->new({ webserver => $webserver, name => $vo });
    $info->{total}    = $pg->total;
    $info->{free}     = $pg->free;
    $info->{used}     = ($info->{total} - $info->{free})/GB2BY;
    $info->{total}   /= GB2BY;
    $info->{free}    /= GB2BY;
    $info->{precious} = $pg->precious/GB2BY;
  }
  else {
    my $obj = dCacheTools::Space->new({ webserver => $webserver, pgroup => $vo });
    my $usage = $obj->getUsage;
    $info->{total} = $usage->{total}; # web numbers are in MB
    $info->{free}  = $usage->{free};
    my $info->{used}  = ($info->{total} - $info->{free})/GB2MB;
    $info->{total} /= GB2MB;
    $info->{free}  /= GB2MB;
    $info->{precious} = $usage->{precious}/GB2MB;
  }
  printf "%10s %9.1f %9.1f %9.1f %9.1f\n", 
    (exists $qm->{$vo}) ? $qm->{$vo} : $vo, 
    $info->{total}, $info->{free}, $info->{used}, $info->{precious};
}
__END__
