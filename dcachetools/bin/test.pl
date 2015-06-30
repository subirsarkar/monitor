#!/usr/bin/env perl

use strict;
use warnings;

use dCacheTools::Admin;

my $group = shift || 'cms';
my $admin = new dCacheTools::Admin;
my @result = $admin->exec({ cell => "PoolManager", command => "psu ls pgroup -l $group"});
print join ("\n", @result), "\n"
