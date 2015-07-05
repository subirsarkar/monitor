#!/usr/bin/env perl

package main;

use strict;
use warnings;
use Storable;

use Monitor;

use constant DEBUG => 0;

our $INFO = '/var/www/html/ftsmon/info.dat';

sub _main {
  my $mon = new Monitor;
  die "Monitor object not initialised correctly" if !$mon->valid;

  # Load the storedinfo
  my $storedinfo = {};
  eval {
    $storedinfo = retrieve $INFO if -e $INFO;
  };
  die "Error reading from file: $@" if $@;

  # Get list of active transfers
  my $fileList = $mon->getAllFileList (['Active']);
  for my $element (sort keys %$fileList) 
  {
    my ($file, $jid) = (split /\s+\[/, $element);
    $jid  = (split /:/, $jid)[0];
    my $info = $mon->getStorageInfo($jid, $file);

    my $destSURL = $mon->getFTSInfo($jid, $file)->{destSURL};
    my $tag = (split m#/pnfs/pi\.infn\.it/data/cms#, $destSURL)[-1];
    print $destSURL, " ", $tag, "\n" if DEBUG;
    $storedinfo->{$tag} = $info;
  }

  # Close the storedinfo
  eval {
    store $storedinfo, $INFO;
  };
  print "Error writing to file: $@" if $@;
}

_main;

__END__
