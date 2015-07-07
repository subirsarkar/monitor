#!/usr/bin/env perl

package main;

# Declaration of globals
use vars qw/$verbose $force $help $nrun/;

use strict;
use warnings;
use Getopt::Long;

use lib qw(/home/cmstac/monitor/bin);
use RunLocation;

sub getOptions;
sub usage;
sub main;

# Command line options with Getopt::Long
$verbose  = '';
$help     = '';
$nrun     = -1;

sub usage () 
{
  print <<HEAD;
  Create the XML file mapping run => {disk, detector} locally

  The command line options are

  --verbose   (D=noverbose)
  --help      show help on this tool and quit (D=nohelp)
  --nrun      list the latest runs only (D=-1 or all)

  Example usage:
  perl -w createRunMap.pl --nrun=10

Subir Sarkar
14/04/2007 12:15 hrs
HEAD

exit 0;
}

sub getOptions 
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
             'help!'    => \&usage,
             'nrun=i'   => \$nrun;
}

sub main
{
  getOptions;

  die "Usage: $0 /data3/EDMProcessed/TIBTOB/fileMap.txt, wildcard can be used" if $#ARGV<2;
  my $obj = new RunLocation($nrun);
  $obj->createMap(\@ARGV);
}

main;
