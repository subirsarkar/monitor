#/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::TransferStatus;

my $transferType = shift || q|dcap-cmsdcache|;
my $obj = dCacheTools::TransferStatus->new({ type => $transferType });
$obj->show;
__END__
