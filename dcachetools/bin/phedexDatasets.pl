#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;

use WebTools::PhedexSvc;
use BaseTools::Util qw/trim readFile/;

# Command line options with Getopt::Long
our $verbose;
our $help;
our $node = q|T2_IT_Pisa|;

sub usage
{
  print <<HEAD;
Given a list of datasets, check if PhEDEx knows about them for a site

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-n|--node       PhEDEx site node name (D=T2_IT_Pisa)

Example usage:
perl -w $0 input_list --node=T2_IT_Pisa --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
               'node=s' => \$node;
}

sub main
{
  readOptions;

  # Read the dataset list from a file
  my $infile = shift @ARGV;
  die q|Dataset list not provided, stopped| unless $infile;
  my $ecode = 0;
  chomp(my @list = readFile($infile, \$ecode));
  die qq|Failed to read $infile| if $ecode;

  # phedex file list
  my $phsvc = WebTools::PhedexSvc->new({ verbose => $verbose });
  $phsvc->options({ node => $node, complete => q|y| });

  my $map = {};
  for my $dataset (map { trim $_ } @list) {
    next if $dataset =~ /^$/;
    print STDERR qq|>>> Processing $dataset\n|;
    my $phedexInfo = $phsvc->files($dataset);
    print Data::Dumper->Dump([$phedexInfo], [qw/phedexInfo/]) if $verbose;
  
    my @phedex_files = sort keys %$phedexInfo;
    my $n_phedex = scalar @phedex_files;
    $map->{$dataset} = $n_phedex;
  }
  for my $dataset (sort { $map->{$b} <=> $map->{$a} } keys %$map) {
    printf STDERR qq|%6d %s\n|, $map->{$dataset}, $dataset;
  }
}
main;
__END__
