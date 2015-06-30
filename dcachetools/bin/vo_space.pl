#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;
use Term::ProgressBar;
use List::Util qw/min max/;

use dCacheTools::Pool;
use dCacheTools::PoolManager;
use dCacheTools::Replica;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';

sub usage
{
  print <<HEAD;
Show VO space information

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)

Example usage:
perl -w $0 --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage;
}
sub main
{
  readOptions;
  # We do not need the detailed info
  my @poollist = dCacheTools::PoolManager->instance({ parse_all => 0 })->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);

  my $info = {};
  my $it = max 1, int($npools/100);
  my $ri = dCacheTools::Replica->new;
  for my $pname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $pname });
    $pool->online or next;
    print STDERR qq|>>> Processing $pname ...\n| if $verbose;
    my @output = $pool->exec({ command => q|rep ls -l| });
    for my $t (@output) {
      $ri->repls($t);
      $info->{$ri->vo}{files}++; 
      $info->{$ri->vo}{precious_files}++ if $ri->precious;
      $info->{$ri->vo}{cached_files}++   if $ri->cached;
      $info->{$ri->vo}{locked_files}++   if $ri->locked;
      $info->{$ri->vo}{space} += $ri->size; 
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  print Data::Dumper->Dump([$info], [qw/vospace/])
}
main;
__END__
