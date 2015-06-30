#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose  = '';
our $help     = '';
our $poolname;
our $movers   = 20;
our $queue    = q|default|;
our @p2pList  = qw/pp p2p/;

sub usage
{
  print <<HEAD;
Change the number of movers associated with each kind of transfer

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pool       pool name
-m|--movers     number of movers (D=20)
-q|--queue      show result for all the files (D=default, other options=wan, p2p, pp)
                default => dcap, wan => gsiftp, p2p => p2p server, pp => p2p client
Example usage:
perl -w $0 --pool=cmsdcache1_2 --movers=10 --queue=p2p --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
               'pool=s' => \$poolname,
             'movers=i' => \$movers,
              'queue=s' => \$queue;
  defined $poolname or warn q|Pool name  must be specified! \n\n| and usage;
}

sub main
{
  readOptions;
 
  my $pool = dCacheTools::Pool->new({ name => $poolname });
  ($pool->alive({refresh => 1}) and not $pool->timedOut)
    or die qq|Pool $poolname did not respond, stopped|;

  my $command = (grep {$_ eq $queue} @p2pList) ? $queue : q|mover|;
  $command .= qq| set max active $movers|;
  $command .= qq| -queue=$queue| unless grep { $_ eq $queue} @p2pList;
  $command .= qq|\nsave|;
  print "$command\n" if $verbose;
  print $pool->exec({ command => $command }), "\n";
}
main;
__END__
