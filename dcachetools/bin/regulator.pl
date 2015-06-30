#!/usr/bin/env perl
package main;

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw/usleep/;
use List::Util qw/min max/;
use POSIX qw/strftime/;

use BaseTools::ConfigReader;
use dCacheTools::PoolGroup;
use dCacheTools::Pool;

# auto-flush
$| = 1;

our $max_movers_map = 
{
  cmsdcache1  => 100,
  cmsdcache2  =>  60,
  cmsdcache4  =>  10,
  cmsdcache8  => 100,
  cmsdcache9  =>  50,
  cmsdcache13 =>  10,
  cmsdcache14 =>  40,
  cmsdcache15 =>  40,
  cmsdcache16 =>  40
};
# Command line options with Getopt::Long
our $verbose = '';
our $help = '';
our $mover_type = q|default|;
our $pgroup = q|cms|;
our $limit = 2.0;
our $threshold = 0.5;

sub usage
{
  print <<HEAD;
Regulate dcap and wan movers allowed on each pool

-v|--verbose   display debug information (D=false)
-h|--help      show help on this tool and quit (D=false)
-t|--threshold regulate if # of queued transfer is > the threshold * max_allowed
-l|--limit     hard limit; active movers should never exceed (limit * max_movers_map->{hostname})
-t|--type      type of movers (D=default)
-g|--pgroup    Pool group (D=cms)

Example usage:
perl -w $0 --type=default --threshold=0.3 -v
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
          'threshold=f' => \$threshold,
              'limit=f' => \$limit,
           'g|pgroup=s' => \$pgroup,
               'type=s' => \$mover_type;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $moverTypes = $config->{mover_types};
  die qq|Unknown mover_type $mover_type specified!| 
    unless grep { $_ eq $mover_type} @$moverTypes;

  $threshold = 0.5 if $threshold < 0;
  $limit = 2 if $limit < 0;
}
sub main
{
  readOptions;
  
  my $pgroup = dCacheTools::PoolGroup->new({ name => $pgroup });
  for my $poolname ($pgroup->poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online
       or warn qq|$poolname not enabled/active!| and next;
    my $host = $pool->host;
    warn qq|Host not found for pool $poolname| and next unless defined $host;
    my $max_movers_soft = $max_movers_map->{$host} || 20;
    my $max_movers_hard = $limit * $max_movers_soft;
    $verbose and 
      printf qq|limits: pool=%s,host=%s,soft=%d,hard=%d\n|, 
        $poolname, $host, $max_movers_soft, $max_movers_hard;

    # total number of movers for each category
    my $mover_info = $pool->mover_info('client_movers');
    my $m_active = abs($mover_info->{$mover_type}{active}) || 0;
    my $m_max    = abs($mover_info->{$mover_type}{max})    || 0;
    my $m_queued = abs($mover_info->{$mover_type}{queued}) || 0;
    printf qq|%15s: %s=%-3d %s=%-3d %s=%-3d; |,
      $poolname, q|m_active|, $m_active, q|m_queued|, $m_queued, q|m_max|, $m_max;

    # act now
    my $message = undef;
    if ($m_queued > int($threshold * $m_active) and ($m_max < $max_movers_hard)) {
      ++$m_max;
      $message = q|increment max movers.|;
    }   
    elsif ($m_active < $m_max) {
      warn qq|no action!\n| 
        and next unless $m_max > $max_movers_soft;
      $m_max = max $m_active, $max_movers_soft;
      $message = qq|reset dcap movers to $m_max.|;
    }
    print qq|no action!\n| and next unless defined $message;
    print qq|$message\n|;

    $pool->exec({ command => qq|mover set max active $m_max -queue=default\nsave| });
    ($pool->alive and not $pool->hasException) or
       warn qq|>>> $poolname: did not respond!\n| and next;
    usleep 5000;
  }
}
main;
__END__
