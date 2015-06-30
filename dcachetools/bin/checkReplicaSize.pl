#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use File::Find;
use File::Basename;
use File::Copy;

use POSIX qw/strftime/;
use Template::Alloy;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim writeHTML/;
use dCacheTools::PnfsManager;
use dCacheTools::Filemap;

# Command line options with Getopt::Long
our $verbose  = '';
our $help     = '';
our $pnfsroot = undef;
our $traverse = 1;
our $showall  = 1;
our $htmlFile = q|replicaSize.html|;
our $tmplFile = q|../tmpl/replicastatus.html.tmpl|;

sub usage
{
  print <<HEAD;
Validate replica size of a pfn on different pools

The command line options are

-v|--verbose    display debug information       (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pnfsroot   pnfs root path                  (D=config)
-t|--traverse   traverse the path recursively   (D=1)
-m|--html       name of the output HTML file    (D=replicaSize.html)
-a|--showall    show result for all the files   (D=1)

Example usage:
perl -w $0 -t 0 -m ltReplica.html -v /pnfs/pi.infn.it/data/cms/store/PhEDEx_LoadTest07
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!'    => \$verbose,
             'help!'       => \&usage,
             'pnfsroot=s'  => \$pnfsroot,
             'traverse=i'  => \$traverse,
             'a|showall=i' => \$showall,
             'm|html=s'    => \$htmlFile;
  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}

sub main
{
  readOptions;

  # Read the pathname
  my $path = shift @ARGV;
  die q|No path is defined! stopped| unless defined $path;

  my $pnfsH = dCacheTools::PnfsManager->instance();
  my $fileinfo = dCacheTools::Filemap->new({
        source => q|path|,
          path => $path, 
      pnfsroot => $pnfsroot,
     recursive => $traverse,
       verbose => $verbose
  })->fileinfo;

  my $dict = {};
  for my $file (sort keys %$fileinfo) {
    my $pnfsid = $fileinfo->{$file}{pnfsid};
    my $replicaSizeDict = {};
    my @poolList = @{$fileinfo->{$file}{pools}};
    for my $pool (@poolList) {
      my $filesize
        = $pnfsH->replica_filesize({ pool => $pool, pnfsid => $pnfsid }) || -1;
      $replicaSizeDict->{$pool} = $filesize;
      print "\$pool=$pool, \$filesize=$filesize\n" if $verbose;
    }
    my $status  = (scalar @poolList > 1) ? q|ok| : q|ko|;
    if (scalar @poolList > 1) {
      my @sizeList = sort { $a <=> $b } values %$replicaSizeDict;
      my $sizeRef = pop @sizeList;
      foreach my $element (@sizeList) {
        my $diff = abs($sizeRef - $element);
        if ($diff) {
          $status = q|ko|;
          last;
        }
      }
    }
    $dict->{$file}{pnfsid}   = $pnfsid;
    $dict->{$file}{replicas} = $replicaSizeDict;
    $dict->{$file}{status}   = $status;
  }
  # Now create the Template::Alloy object and create the html from template
  # Create a Template::Alloy object
  my $tt = Template::Alloy->new(
    EXPOSE_BLOCKS => 1,
    RELATIVE      => 1,
    INCLUDE_PATH  => q|dcachetools/tmpl|,
    OUTPUT_PATH   => q|./|
  );
  my $output_full = q||;
  my $outref_full = \$output_full;

  # html header
  $tt->process_simple(qq|$tmplFile/header|, {site => q|Pisa|, storage => q|dcache|}, $outref_full) 
        or die $tt->error, "\n";
  $tt->process_simple(qq|$tmplFile/table_start|, {}, $outref_full) or die $tt->error, "\n";

  # now loop over the files
  for my $file (keys %$dict) {
    my $pnfsid   = $dict->{$file}{pnfsid};
    my $sizeDict = $dict->{$file}{replicas};
    my $status   = $dict->{$file}{status};
    $status eq 'ko' or next unless $showall;

    my $pinfo = q||;
    my @pools = sort keys %$sizeDict;
    my $npools = scalar @pools;
    for my $pool (@pools) {
      $pinfo .= join(':', $pool, $sizeDict->{$pool});
      $pinfo .= " ";
    }
    $pinfo = trim $pinfo if length $pinfo;
    print join(' ', $file, $pnfsid, $pinfo, $status), "\n";
    $file =~ s#$pnfsroot##;
    my $row = {
               file => $file,
             pnfsid => $pnfsid,
      replica_class => (($npools>1) ? q|green| : q|red|),
            replica => $npools,
       status_class => (($status eq 'ok') ? q|green| : q|red|),
             status => $status,
             size   => $pinfo
    };
    $tt->process_simple(qq|$tmplFile/table_row|, $row, $outref_full) or die $tt->error, "\n";
  }
  my $tstr = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
  $tt->process_simple(qq|$tmplFile/table_end|, {}, $outref_full) or die $tt->error, "\n";
  $tt->process_simple(qq|$tmplFile/footer|, {timestamp => $tstr}, $outref_full) 
       or die $tt->error, "\n";

  # template is processed in memory, now dump
  writeHTML($htmlFile, $output_full);
}

# subroutine definition done
main;
__END__
