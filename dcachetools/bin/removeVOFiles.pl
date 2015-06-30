#!/usr/bin/env perl
package main;

use strict;
use warnings;
use File::stat;
use Term::ProgressBar;
use List::Util qw/min max/;

use BaseTools::Util qw/trim/;
use dCacheTools::PoolManager;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $vo      = undef;

sub usage
{
  print <<HEAD;
Remove files that belong to a VO

The command line options are

-v|--verbose  display debug information (D=false)
-h|--help     show help on this tool and quit (D=false)
--vo          VO name (D=none)

Example usage:
perl -w $0 --verbose --vo=biomed
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
                 'vo=s' => \$vo;
  die qq|No VO specified| unless defined $vo;
}
sub main
{
  readOptions;

  my @poollist = dCacheTools::PoolManager->instance({parse_all => 0})->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  my $it = max 1, int($npools/100);
  
  my $dict = {};
  for my $poolname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    print ">>> Processing $poolname\n" if $verbose;
    
    my @result = $pool->exec({ command => q|rep ls| });
    $pool->alive or next;
    $pool->hasException and next;
    
    foreach my $output (@result) {
      my ($pnfsid, $status, $size, $sclass) = map { trim $_ } (split /\s+/, $output); 
      my $vo = ($sclass =~ /si={(\w+?):(?:.*)}/) ? $1 : '?';
      if ($vo eq '?') {
        warn qq|Problem with $poolname replica ($sclass): $output | if $verbose;
        next; 
      }
      ($vo eq $myvo) or next;
      push @{$dict->{$poolname}}, $output;
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  for my $poolname (keys %$dict) {
    print join (' ', $poolname, @{$dict->{$poolname}}), "\n";
  }
}
main;
__END__
