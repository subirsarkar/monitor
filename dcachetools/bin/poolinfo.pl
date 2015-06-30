#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

use Term::ProgressBar;
use List::Util qw/min max/;

use POSIX qw/strftime/;
use Template::Alloy;

use BaseTools::ConfigReader;
use BaseTools::Util qw/storeInfo restoreInfo writeHTML/;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

use constant KB2BY => 1024;
use constant GB2BY => 1.0*(KB2BY**3);
use constant TB2BY => 1.0*(KB2BY**4);

our $htmlFile = q|storage.html|;
our $tmplFile = q|../tmpl/storage.html.tmpl|;
our $dbfile   = q|poolinfo.db|;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';

sub usage
{
  print <<HEAD;
Shows Pool information in a compact tabular format

The command line options are

-v|--verbose  display debug information (D=false)
-h|--help     show help on this tool and quit (D=false)

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

sub updateDB
{
  my $diskav = shift;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $file = $config->{resourceDB}{server};

  return $diskav unless defined $file;

  my $value = 0;
  if ( -r $file ) {
    my $info   = restoreInfo($file);
    my $diskdb = $info->{disk};

    storeInfo($file, {disk => $diskav} ) if $diskav > $diskdb;
    $value = max $diskdb, $diskav;
  }
  else {
    storeInfo($file, {disk => $diskav} );
    $value = $diskav;
  }
  $value;
}

sub getFloat
{
  my $val = shift;
  sprintf(qq|%.2f|, $val);
}

sub main
{
  readOptions;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $moverTypes = $config->{mover_types};

  my ($g_total, $g_free, $g_precious) = (0,0,0);
  my $tmovers = {};
  my $info = '';
  my $pm = dCacheTools::PoolManager->instance();
  my @poollist = $pm->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);

  my $it = max 1, int($npools/100);
  my $pinfo = {};
  for my $poolname (@poollist) {
    unless ( (++$ipool)%$it ) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or warn qq|$poolname not enabled/active!| and next;
    print STDERR qq|>>> Processing $poolname ...\n| if $verbose;

    $pinfo->{$poolname} = [$pool->host, $pool->path, $pool->space_info()->{total}/GB2BY];

    my @list = $pool->summary($moverTypes);
    $info .= join ('', @list).qq|\n|;
  
    print STDERR qq|INFO. Failed to get information about $poolname!\n| 
      and next unless scalar @list > 6;
  
    # total space usage
    my $space_info = $pool->space_info;
    $g_total    += $space_info->{total};
    $g_free     += $space_info->{free};
    $g_precious += $space_info->{precious};
  
    # total number of movers for each category
    my $mover_info = $pool->mover_info('client_movers');
    for my $m (@$moverTypes) {
      next unless exists $mover_info->{$m};
      $tmovers->{$m}{active} += abs($mover_info->{$m}{active});
      $tmovers->{$m}{max}    += abs($mover_info->{$m}{max});
      $tmovers->{$m}{queued} += abs($mover_info->{$m}{queued});
    }
    for my $m (qw/p2p_server p2p_client/) {
      my $info = $pool->mover_info($m);
      $tmovers->{$m}{active} += abs($info->{active});
      $tmovers->{$m}{max}    += abs($info->{max});
      $tmovers->{$m}{queued} += abs($info->{queued});
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  open OUTPUT, qq|>$dbfile| || die qq|Failed to open output file $dbfile|;
  print OUTPUT Data::Dumper->Dump([$pinfo], [qw/poolinfo/]);
  close OUTPUT;

  my $g_used = $g_total - $g_free;

  # Now total space usage and movers in use
  my $maxv = updateDB($g_total)/TB2BY;
  print qq|---------------------\n   Space Usage (TB)\n---------------------\n|;
  printf qq/%10s %10s %8s %8s %8s %12s\n/, 
     q|Installed|, 
     q|Available|, 
     q|Free|, 
     q|Used|, 
     q|Precious|,
     q|[% Fraction]|;
  printf qq/%10.2f %10.2f %8.2f %8.2f %8.2f %8.1f\n/,
     $maxv,
     $g_total/TB2BY,
     $g_free/TB2BY,
     $g_used/TB2BY,
     $g_precious/TB2BY,
     $g_precious*100/$g_used;
  
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

  # HTML header
  my $tstr = strftime(qq|%Y-%m-%d %H:%M:%S|, localtime(time()));
  $tt->process_simple(qq|$tmplFile/header|, 
     {site => q|Pisa|, storage => q|dCache|, timestamp => $tstr}, $outref_full) 
    or die $tt->error, "\n";
  $tt->process_simple(qq|$tmplFile/table_start|, {}, $outref_full) or die $tt->error, "\n";
  my $row = {
    installed => getFloat($maxv),
    available => getFloat($g_total/TB2BY),
     av_class => q|default|,
         free => getFloat($g_free/TB2BY),
         used => getFloat($g_used/TB2BY),
     precious => getFloat($g_precious/TB2BY),
     pr_class => q|default|
  };
  $tt->process_simple(qq|$tmplFile/table_row|, $row, $outref_full) or die $tt->error, "\n";
  $tt->process_simple(qq|$tmplFile/table_end|, {}, $outref_full) or die $tt->error, "\n";
  $tt->process_simple(qq|$tmplFile/footer|, {}, $outref_full) 
       or die $tt->error, "\n";

  # Template is processed in memory, now dump
  writeHTML($htmlFile, $output_full);

  # Movers
  print qq|\n---------------------\n     Total Movers\n---------------------\n|;
  printf qq/%12s %6s %6s %6s\n/, q|Type|, q|Active|, q|Queued|, q|Max|;
  for my $type (sort keys %$tmovers) {
    printf qq/%12s %6d %6d %6d\n/, $type, 
                                   $tmovers->{$type}{active},
                                   $tmovers->{$type}{queued},
                                   $tmovers->{$type}{max};
  }
  printf qq/\n%51s|%43s|%34s|%20s\n/, 
                      q|---------------------- Pools ----------------------|, 
                      q|-------------------- Space -----------------|, 
                      q|------------- Movers -------------|,
                      q|------- Cost -------|;
  my $FORMAT = qq/%14s %-22s %8s %4s| %7s %7s %13s %13s| %8s %9s %7s %6s| %9s %9s\n/;
  my @headers = (q|Name|, 
                 q|Base directory|, 
                 q|Mode|, 
                 q|Stat|, 
                 q|Totl(G)|, 
                 q|Free(G)|, 
                 qq!Used(G|%)!, 
                 qq!Precious(G|%)!, 
                 q|Lan|, 
                 q|Wan|, 
                 q|p2p-s|, 
                 q|p2p-c|, 
                 q|Space|, 
                 q|CPU|);
  printf $FORMAT, @headers;
  print $info;
}
main;
__END__
