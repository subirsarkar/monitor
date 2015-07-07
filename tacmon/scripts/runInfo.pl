package main;

# Declaration of globals
use vars qw/$verbose $help $run $subdet/;

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

use lib qw(/home/cmstac/scripts);
use RunInfo;

sub getOptions;
sub usage;

# Command line options with Getopt::Long
$verbose  = '';
$help     = '';
$run      = -1;
$subdet   = '';

use constant DEBUG => 0;

sub usage () {
  print <<HEAD;
  Query the ELOG and get information about runs

  The command line options are

  --verbose  (D=noverbose)
  --help     show help on this tool and quit (D=nohelp)
  --run      The run number we want information for
  --subdet   TIB, TEC etc.

  Example usage:
  perl -w runInfo.pl --subdet=TIB --run=572

Subir Sarkar
15/12/2006 12:10 hrs
HEAD

exit 0;
}
sub getOptions {
  # Extract command line options
  GetOptions 'verbose!'  => \$verbose,
             'help!'     => \&usage,
             'run=i'     => \$run,
             'subdet=s'  => \$subdet;

  print "Arglist:: ", join (":", $run, $subdet), "\n" if DEBUG;
  usage() if ($run == -1 || $subdet eq '');
}

sub _main {
  getOptions;
  my $obj = new RunInfo($subdet);
  my $info = $obj->parse($run);

  if (DEBUG) {
    for my $key (keys %$info) {
      print join (':', $key, $info->{$key}), "\n";
    }
  }
  print join (" ", $info->{Type}, 
                   $info->{Partition}, 
                   $info->{Events}), "\n";
}

_main;
__END__
