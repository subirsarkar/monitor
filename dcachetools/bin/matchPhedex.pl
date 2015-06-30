#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use dCacheTools::PhedexComparison;

# Command line options with Getopt::Long
our $verbose  = '';
our $help     = '';
our $node     = undef;
our $path     = undef; # mind it phedex paths start with /store/...
our $complete = q|na|;

sub usage
{
  print <<HEAD;
Check pnfs against PhEDEx subscription

Four files are generated after the check
  - pnfs_files.txt       - a full list of files under pnfs path
  - phedex_files.txt     - list downloaded from PhEDEx
  - pnfsonly_files.txt   - files not known to PhEDEx
  - phedexonly_files.txt - Files are known to PhEDEx, but were somehow lost from pnfs

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pnfspath   find files under this pnfs path (D=config)
-n|--node       PhEDEx site node name (D=config)
-c|--complete   Specify if only completed transfers will be considered on the PhEDEX side 
                (D=na i.e do not use; valid options: y,n)

Example usage:
perl -w $0 --pnfspath=/pnfs/pi.infn.it/data/cms --node=T2_IT_Pisa --complete=y -v
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
           'pnfspath=s' => \$path,
               'node=s' => \$node,
           'complete=s' => \$complete;

  my $reader = BaseTools::ConfigReader->instance();
  defined $path or $path = $reader->{config}{pnfsroot};
  defined $node or $node = $reader->{config}{node};
}

sub main
{
  readOptions;
  my $obj = dCacheTools::PhedexComparison->new({
                node => $node,
            complete => $complete,
            pnfsroot => $path,
           pnfs_dump => q|pnfs_files.txt|,
       pnfsonly_dump => q|pnfsonly_files.txt|,
         phedex_dump => q|phedex_files.txt|,
     phedexonly_dump => q|phedexonly_files.txt|,
             verbose => $verbose
  });
  $obj->compare;
}
main;
__END__
