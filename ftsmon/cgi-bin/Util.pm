package Util;

use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK);

use strict;
use warnings;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( _trim getTime );
@EXPORT_OK = qw();
$VERSION = "0.5";

sub _trim($);
sub getTime($);

# Remove whitespace from the start and end of the string
sub _trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
}

sub getTime ($) {
  my $input = shift;
  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) 
    = localtime($input);
  my $year = 1900 + $yearOffset;
  my $theTime = sprintf "%s %s %d, %d %02d:%02d:%02d hrs",
     $weekDays[$dayOfWeek], $months[$month], $dayOfMonth, $year, $hour, $minute, $second;
  $theTime;
}

1;
__END__
