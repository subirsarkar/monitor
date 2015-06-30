#!/usr/bin/env perl
package main;

use strict;
use warnings;
use dCacheTools::PoolGroup;

my $pgroup = shift || 'cms';
my $obj = dCacheTools::PoolGroup->new({ name => $pgroup });
$obj->show;
__END__
