#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim 
                       getCommandOutput 
                       readFile/;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Filemap;

# Command line options with Getopt::Long
our $verbose;
our $help = '';
our $progress_freq = 100;
our $pnfsroot = undef;
our $iofile = q|filesOnPools.list|;
our $use_cache = '';
our $lookup_only = '';

sub usage
{
  print <<HEAD;
Find orphan entries under pnfs

The command line options are

-v|--verbose         display debug information (D=false)
-h|--help            show help on this tool and quit (D=false)
-f|--pnfsid-file     input file containing a list of all the pnfsids (D=filesOnPools.list)
-p|--pnfsroot        pnfs namespace to prepend to filename (D=config)
-s|--progress-step   show progress every N files
-c|--use-cache       read cached pnfsid list from all the servers
-l|--lookup-only     read the pool pnfsid only and then quit

Example usage:
perl -w $0 /pnfs/pi.infn.it/data/cms/store --use-cache
HEAD

  exit 0;
}
sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
      'f|pnfsid-file=s' => \$iofile,
         'p|pnfsroot=s' => \$pnfsroot,
    's|progress-step=i' => \$progress_freq,
        'l|lookup-only' => \$lookup_only,
          'c|use-cache' => \$use_cache;

  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}
sub findOrphans
{
  my $path = shift;

  # file pnfs entries
  my $fileinfo = dCacheTools::Filemap->new({
            source => q|path|,
              path => $path, 
          pnfsroot => $pnfsroot,
         recursive => 1,
         get_stats => 0,
     progress_freq => $progress_freq, 
           verbose => $verbose
  })->fileinfo;
  scalar(keys %$fileinfo) or die qq|Path $path does not contain any files! stopped|;

  # read the input pnfsid list in an array and then in a map
  my $ecode = 0;
  chomp(my @idlist = grep { /^[0-9A-F]{24,}$/ } readFile($iofile, \$ecode));
  $ecode and die qq|Failed to read $iofile, ecode=$ecode; stopped|;
  scalar @idlist or die q|Input pnfsid list empty! stopped|; 

  # build a map for fast indexing
  my $pnfsid_store = { map { $_ => 1 } @idlist };

  # now time to compare
  for my $file (keys %$fileinfo) {
    print STDERR qq|>>> Processing $file\n| if $verbose;
    my $pnfsid = $fileinfo->{$file}{pnfsid};
    exists $pnfsid_store->{$pnfsid} and next;

    my @poolList = @{$fileinfo->{$file}{pools}};
    my $pools = (scalar @poolList) ? join ' ', @poolList : '?';
    printf qq|NoPnfsidOnPools: %s %24s %s\n|, $pools, $pnfsid, $file; 
    printf qq|        NoPools: %s %24s %s\n|, $pools, $pnfsid, $file if $pools eq '?'; 
  }
}
sub filesOnPools
{
  open OUTPUT, qq|>$iofile| or die qq|Failed to open output $iofile|;
  my $pm = dCacheTools::PoolManager->instance(); # We _do_ need the detailed info
  for my $poolname ($pm->poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    my $host    = $pool->host;
    defined $host or warn qq|>>> host not found for pool $poolname!| and next;
    my $datadir = $pool->path.q|/data|;
    printf STDERR qq|%s:%s:%s:%d\n|, $host, $datadir, $poolname, ($pool->enabled ? 1 : 0);
    print OUTPUT qq|# Processing $poolname\n|;
    my $ecode = 0;
    my $cmd = qq|ssh -2 $host ls -1 $datadir|;
    chomp(my @lines = map { trim $_ } getCommandOutput($cmd, \$ecode));
    print OUTPUT join("\n", @lines), "\n";       
  }
  close OUTPUT;
}
sub main
{
  readOptions;

  defined $lookup_only and filesOnPools and return;

  # read the pathname
  my $path = shift @ARGV;
  defined $path or die q|pnfs path not defined|;

  $use_cache or filesOnPools;
  findOrphans $path;  
}

# subroutine definition done
main;
__END__
