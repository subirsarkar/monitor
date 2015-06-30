#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Math::BigInt;

use WebTools::PhedexSvc;
use dCacheTools::Filemap;
use BaseTools::Util qw/trim/;

# Command line options with Getopt::Long
our $verbose;
our $help;
our $node = undef;
our $datapath;
our $pnfsroot = undef; # mind it phedex paths start with /store/...

sub usage
{
  print <<HEAD;
Verify a dataset - availability and filesize - at a site after PhEDEx transfer is complete. 

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-n|--node       PhEDEx site node name (D=config)
-p|--pnfsroot   find files under this pnfs path (D=config)
-d|--datapath   Dataset path

Example usage:

perl -w $0 --pnfs-root=/pnfs/pi.infn.it/data/cms \
           --node=T2_IT_Pisa \
           --data-path=/store/mc/Winter09/Zjets-madgraph/GEN-SIM-DIGI-RECO/IDEAL_V11_FastSim_v1 \
           --verbose \
           /Zjets-madgraph/Winter09_IDEAL_V11_FastSim_v1/GEN-SIM-DIGI-RECO  
HEAD

  exit 0;
}
sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
               'node=s' => \$node,
         'p|pnfsroot=s' => \$pnfsroot,
         'd|datapath=s' => \$datapath;
  my $reader = BaseTools::ConfigReader->instance();
  defined $pnfsroot or $pnfsroot = $reader->{config}{pnfsroot};
  defined $node or $node = $reader->{config}{node};
}
sub main
{
  readOptions;

  # Read the dataset
  my $dataset = shift @ARGV;
  die q|Dataset name not found! stopped| unless defined $dataset;

  # phedex file list
  my $phsvc = WebTools::PhedexSvc->new({ verbose => $verbose });
  $phsvc->options({ node => $node, complete => q|y| });
  my $phedexInfo = $phsvc->files($dataset);
  print Data::Dumper->Dump([$phedexInfo], [qw/phedexInfo/]) if $verbose;
  
  my @phedex_files = sort keys %$phedexInfo;
  return unless scalar @phedex_files;
  my $n_phedex = scalar @phedex_files;
  print STDERR q|PhEDEX finds |. $n_phedex . qq| files\n|;

  # if datapath is not specified on command line, try to find it
  unless (defined $datapath) {  
    my $dname = (split m#\/#, $dataset)[1];
    my $f = $phedex_files[0];
    my @fields;
    for (split m#\/#, $f) {
      push @fields, $_;
      last if /$dname/;
    }
    $datapath = $pnfsroot . join("/", @fields);
  }
  print STDERR qq|INFO. datapath: $datapath\n|;

  my $pnfsInfo = dCacheTools::Filemap->new({
            source => q|path|,
              path => $datapath, 
          pnfsroot => $pnfsroot,
         recursive => 1,
          get_size => 1,
         get_stats => 0,
     progress_freq => int($n_phedex/30),
           verbose => $verbose
  })->fileinfo;
  print Data::Dumper->Dump([$pnfsInfo], [qw/pnfsInfo/]) if $verbose;

  # find phedex only files
  my @list = ();
  for my $f (@phedex_files) {
    my $file = $pnfsroot . $f;
    if (defined $pnfsInfo->{$file}) {
      push @list, [$f, $phedexInfo->{$f}{size}, $pnfsInfo->{$file}{size}] 
        if ($phedexInfo->{$f}{size} - $pnfsInfo->{$file}{size});
    }
    else {
      push @list, [$f,  $phedexInfo->{$f}{size}, -1] 
    }
  }
  if (scalar @list) {
    print qq|INFO. PhEDEx only files!\n|;
    for my $aref (@list) {
      print $aref->[0], "\n" if $aref->[2] == -1;
    }
    print qq|INFO. PhEDEx - local size mismatch for the following files!\n|;
    for my $aref (@list) {
      next unless $aref->[2] > -1;
      printf qq|%s %s %s\n|, 
              $aref->[0], 
              (Math::BigInt->new($aref->[1]))->bstr,
              (Math::BigInt->new($aref->[2]))->bstr;
    }
  }
  # now find the pnfsonly files
  @list = ();
  for my $file (sort keys %$pnfsInfo) {
    $file =~ s/$pnfsroot//;   
    push @list, $file unless defined $phedexInfo->{$file};
  }
  if (scalar @list) {
    print qq|INFO. PNFS only files!\n|;
    print join("\n", @list), "\n";
  }
}
main;
__END__
