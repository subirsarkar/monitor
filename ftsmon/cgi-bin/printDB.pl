#!/usr/bin/env perl

package main;

use strict;
use warnings;
use Storable;
use Data::Dumper;

our $INFO = '/var/www/html/ftsmon/info.dat';

sub _main {
  # Load the storedinfo
  my $storedinfo = {};
  eval {
    $storedinfo = retrieve($INFO) if -e $INFO;
  };
  die "Error reading from file: $@" if $@;

  print Dumper($storedinfo);
  for my $key (sort keys %$storedinfo) {
    print join (":", $key, $storedinfo->{$key}), "\n";
  }
}

_main;

__END__
