#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use POSIX qw/strftime/;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::GridftpTransfer;
use dCacheTools::Mover;
use BaseTools::Util qw/trim message/;

# Autoflush
$| = 1;

# Command line options with Getopt::Long
our $verbose   = '';
our $help      = '';
our $tmax      = 1200; # seconds
our $rmin      = 20;  # KB/s
our $killstuck = '';

sub usage
{
  print <<HEAD;
Kill Gridftp transfers that are either dead or stuck. You may decide
on the definition of stuck.

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-t|--tmax       how long the transfer should be on to qualify(D=600 s)
-r|--rate       minimum transfer rate to qualify (D=100 KB/s)
-s|--kill-stuck by default only the dead transfers are killed(D=false) 

Example usage:
perl $0 --kill-stuck --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
               'tmax=i' => \$tmax,
               'rmin=f' => \$rmin,
        's|kill-stuck!' => \$killstuck;
}

sub main
{
  readOptions;

  my $mi = dCacheTools::Mover->new;
  my @poollist = (scalar @ARGV) ? @ARGV
                         : dCacheTools::PoolManager->instance({parse_all => 0})->poollist;
  for my $poolname (@poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    message BLUE, qq| >>> Processing $poolname| if $verbose;

    # Now check mover ls
    my @output = grep { /gridftp/ } $pool->exec({ command => q|mover ls| });
    $pool->alive or next;

    for my $t (@output) {
      $mi->moverls($t);
      my $gftp = dCacheTools::GridftpTransfer->new({ name => $mi->door });
      unless ($gftp->alive) {
        message RED, sprintf(qq| door=%s is dead! killing the moverid=%d|, $mi->door, $mi->id);
        print $pool->exec({ command => sprintf(qq|mover kill %d|, $mi->id) }), "\n";
      }
      else {
        my $color = GREEN;
        my $state = q|running|; 
        if ($mi->duration > $tmax and $mi->rate < $rmin) {
          $color = RED;
          $state = q|stuck|;
        }
        message $color, sprintf(qq| door=%s, moverid=%d is $state|, $mi->door, $mi->id);
        printf qq|Remote Host: <%s>, Pool: <%s>, Pnfsid: <%s>, \nFile: %s\n|,
                    $gftp->remote_host, 
                    $gftp->pool, 
                    $gftp->pnfsid, 
                    $gftp->filename;
        printf qq|Status: <%s>, Transferred: <%U Bytes>, Duration: <%Us>, Rate: <%7.2f KB/s>, lm: <%U>\n|,  
                    $gftp->status, 
                    $mi->bytes, 
                    $mi->duration, 
                    $mi->rate, 
                    $mi->lm;
        if ($killstuck and $state eq 'stuck') {
          print $pool->exec({ command => sprintf(qq|mover kill %d|, $mi->id) }), "\n";
        }
      }
      print "\n";
    }
  }
}

main;
__END__
11561 A H {GFTP-cmsdcache7-Unknown-109@gridftp-cmsdcache7Domain:10007} 000800000000000001F79888 h={SU=1682243584;SA=1730150400;S=None} bytes=1680146432 time/sec=6224 LM=0
