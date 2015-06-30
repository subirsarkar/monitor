#!/usr/bin/env perl
package main;

use dCacheTools::Filesize;

my $fileid = shift || die qq|Usage: $0 pnfsid/pfn\n\tstopped|;
my $obj = dCacheTools::Filesize->new({ fileid => $fileid });
$obj->show;
__END__
