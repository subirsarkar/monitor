#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::Cell;

my $cell = shift;
my $command = join (' ', @ARGV);

my $obj = dCacheTools::Cell->new({ name => $cell });
my @output = $obj->exec({ command => $command });
print join("\n", @output), "\n";
__END__
