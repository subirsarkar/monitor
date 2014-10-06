package main;

use strict;
use warnings;
use Getopt::Long;

use LSF::AccountingBase;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $start   = '';
our $end     = '';

sub usage
{
  print <<HEAD;
LSF accounting for arbitrary time window

The command line options are

-v|--verbose  display debug information (D=false)
-h|--help     show help on this tool and quit (D=false)
-s|--start    start time of format YYYY/MM/DD/HH:MM::SS
-e|--end      end time of format YYYY/MM/DD/HH:MM::SS

Example usage:
perl -w $0 --start='2009/01/20/00:00:00' --end='2009/02/19/23:59:59'
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
             'help!'    => \&usage,
             'start=s'  => \$start,
             'end=s'    => \$end;
}

sub main
{
  readOptions;
  
  my $attr = {};
  $attr->{start} = LSF::AccountingBase->getEpoch($start) unless $start eq '';
  $attr->{end}   = LSF::AccountingBase->getEpoch($end) unless $end eq '';
  my $obj = LSF::AccountingBase->new($attr);
  $obj->collect;
  $obj->showGroups;
  $obj->showUsers;
}
main;
__END__
