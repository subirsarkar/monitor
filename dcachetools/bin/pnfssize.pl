#!/usr/bin/env perl
package main;

use dCacheTools::PnfsManager;

my $arg = shift || die qq|Usage: perl -w $0 pnfsid/pfn\n\tstopped|;
my $pnfsid = $arg;
$pnfsid = dCacheTools::PnfsManager->pfn2id($pnfsid) if $pnfsid =~ m#^/pnfs/#;
die qq|invalid format for PNFSID $pnfsid! stopped| 
    unless (defined $pnfsid and $pnfsid =~ /[0-9A-F]{24,}/);

my $pnfsH = dCacheTools::PnfsManager->instance();
my $size_pnfs = $pnfsH->pnfs_filesize({ pnfsid => $pnfsid }) || -1;
print $size_pnfs;
__END__
