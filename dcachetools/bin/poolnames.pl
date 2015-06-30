#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use dCacheTools::PoolManager;
use dCacheTools::PoolGroup;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $pgroup  = undef;

sub usage
{
  print <<HEAD;
Print poolnames, global or for each PoolGroup

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pgroup     Poolgroup name (D=none)

Example usage:
perl -w $0 --pgroup=cms
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
             'pgroup=s' => \$pgroup;
}
sub main
{
  readOptions;

  # We do not need the detailed info
  my $pm = (defined $pgroup) ? dCacheTools::PoolGroup->new({ name => $pgroup })
                             : dCacheTools::PoolManager->instance({ parse_all => 0 });
  for my $poolname ($pm->poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    print qq|$poolname\n|;
  }
}
main;
__END__
