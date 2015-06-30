#!/usr/bin/env perl
package main;

use strict;
use warnings;
use dCacheTools::Space;

my $pgroup = shift || 'cms';
my $obj = dCacheTools::Space->new({ webserver => 'cmsdcache', pgroup => $pgroup });
$obj->show;

$obj->reset;
$obj->show;
__END__
