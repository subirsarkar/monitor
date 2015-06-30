#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::Queues;

my $obj = dCacheTools::Queues->new({ webserver => 'cmsdcache' });
$obj->show;
print $obj->movers({ pool => q|cmsdcache13_1|, type => q|default|, state => q|Active| }), "\n";
__END__
