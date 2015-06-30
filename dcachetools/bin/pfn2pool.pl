#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use dCacheTools::Filemap;

# Command line options with Getopt::Long
our $verbose  = '';
our $help     = '';
our $pnfsroot = undef;
our $infile = undef;

sub usage
{
  print <<HEAD;
Find pool(s) for a pfn. The pfn entries are read from a file. 

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pnfsroot   pnfs namespace to prepend to filename (D=config)
-i|--infile     Input file with a list of LFN (D=none)

Example usage:
perl -w $0 --file=input_file
HEAD

  exit 0;
}
sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
             'infile=s' => \$infile,
           'pnfsroot=s' => \$pnfsroot;
  (defined $infile and -r $infile) or die qq|$infile not found|;
  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}
sub main
{
  readOptions;

  # Read the input filename
  my $infile = shift @ARGV;
  die q|Input file not specified! stopped| unless defined $infile;

  my $fileinfo = dCacheTools::Filemap->new({
        source => q|infile|,
        infile => $infile, 
      pnfsroot => $pnfsroot,
     get_stats => 0,
       verbose => $verbose
  })->fileinfo;

  for my $file (sort keys %$fileinfo) {
    my @poolList = @{$fileinfo->{$file}{pools}};
    my $pools = (scalar @poolList) ? join ' ', @poolList : '?';
    printf qq|%100s %s\n|, $file, $pools;
  }
}
# subroutine definition done
main;
__END__
