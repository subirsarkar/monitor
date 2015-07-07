package Util;

use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK);

use strict;
use warnings;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( _trim getTime _debug escape );
@EXPORT_OK = qw(getCommandOutput);
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

sub _debug {
  my $index = shift;
  print STDERR "DEBUG ".$index."...\n";
}

sub getCommandOutput
{
  my $command = shift;
  my $fh = new IO::File qq[$command |];
  die qq[ERROR. Could not execute $command, $!] if not $fh->opened;
  $fh->close, return [] if $fh->eof;

  chomp(my @lines = <$fh>);
  $fh->close;
  \@lines;
}

sub escape ($)
{
  my $text = shift;
  $text =~ s/&/\&amp;/g;
  $text =~ s/</\&lt;/g;
  $text =~ s/>/\&gt;/g;
  $text;
}

1;

__END__
