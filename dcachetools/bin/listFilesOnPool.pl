#!/usr/bin/env perl
package main;

use strict;
use warnings;
use File::Copy;
use Math::BigInt;

use BaseTools::Util qw/readFile trim/;
use BaseTools::ConfigReader;
use dCacheTools::Pool;
use dCacheTools::Companion;
use dCacheTools::PnfsManager;
use dCacheTools::Replica;

sub main
{
  my $dbc   = dCacheTools::Companion->new;
  my $pnfsH = dCacheTools::PnfsManager->instance();

  # ignore unwanted VOs
  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->config;
  my $pnfsroot = $config->{pnfsroot};
  my $cacheDir = $config->{cache_dir};
  my $skip_vos = $reader->{config}{skip_vos} || [];
    
  my $ri = dCacheTools::Replica->new;
  for my $poolname (@ARGV) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    my @result = $pool->exec({ command => q|rep ls -l| });
    $pool->alive or warn qq|Pool $poolname did not respond! skipped\n| and next;
    
    # now read the cache
    my $cacheFile = qq|$cacheDir/$poolname.filelist|;
    my $tmpFile   = qq|$cacheFile.tmp|;
    my $ecode = 0;
    chomp(my @list = readFile($cacheFile, \$ecode));
    my $cache = {};
    for (@list) {
      next if /^$/;
      my ($pnfsid, $pfn) = map { trim $_ } (split /\s+/)[0,4];  
      $pfn =~ /CacheException/ and next;
      $cache->{$pnfsid} = $pfn;
    }
    open OUTPUT, qq|>$tmpFile| or die qq|Failed to open $tmpFile|;
    print qq|----------------------\nFiles On $poolname\n----------------------\n|;
    for (@result) {
      next if /^$/;
      $ri->repls($_);
      my ($pnfsid, $status, $size, $vo) = ($ri->pnfsid, $ri->status, $ri->size, $ri->vo); 
      $vo eq '?' and next;
      grep { /$vo/ } @$skip_vos and next;
    
      my $pfn;
      if ( defined $cache->{$pnfsid} ) {
        $pfn = $cache->{$pnfsid};
      }
      else {
        $pfn = $pnfsH->pathfinder($pnfsid);
        defined $pfn or $pfn = '?'; 
        print STDERR qq|INFO. Processing $poolname - Cache MISS for $pnfsid, $pfn\n|;
      }
      $pfn =~ s/$pnfsroot//;

      my @poolList = $dbc->pools({ pnfsid => $pnfsid });
      scalar @poolList or 
        print qq|INFO. Processing $poolname - no pool for $_ in the Associated DB\n| 
          and next;
      @poolList = grep { $_ ne $poolname } @poolList;
      unshift @poolList, $poolname;

      $vo =~ s/\W+//g;
      printf OUTPUT qq|%24s %10s %21s %11s %s %s\n|,
         $pnfsid, 
         $vo,
         $status, 
         (Math::BigInt->new($size))->bstr, 
         $pfn, 
         join(' ', @poolList);
    }
    close OUTPUT;
    
    # Atomic step
    copy $tmpFile, $cacheFile or
      warn qq|Failed to copy $tmpFile to $cacheFile: $!\n|;
    unlink $tmpFile;
  }
}
main;
__END__
