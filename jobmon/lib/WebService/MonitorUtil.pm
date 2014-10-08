package WebService::MonitorUtil;

use strict;
use warnings;
use Storable;

use XML::XPath;
use XML::XPath::XMLParser;
use XML::Writer;

use List::Util qw/min max sum/;
use Time::Local;
use POSIX qw/strftime/;

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
               avg
         timestamp
         getParser
  parseGridmapFile
    parseVOMapFile
              trim
         getWriter
         writeData
        time2hours
      getTimestamp 
           getTime 
   getXAxisLabelFD
     getXAxisLabel
      show_message
);
our $VERSION = "0.5";

$XML::XPath::SafeMode = 1;  # Enable

# Static methods; should also be availble as utility methods to others
sub getXAxisLabel
{
  my ($stime, $index) = @_;
  my @tim = localtime($stime + 600*$index + 300); # +300: round value of label to the nearest 10 min
  $tim[1] -= $tim[1]%10;
  sprintf "%2d:%02d", $tim[2], $tim[1];
}

sub getXAxisLabelFD
{
  my ($stime, $diff) = @_;
  my @tim = localtime($stime + $diff);
  $tim[1] -= $tim[1]%10;
  sprintf "%2d:%02d", $tim[2], $tim[1];
}
sub getTime 
{
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

sub getTimestamp
{
  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings)
      = localtime(time());
  my $year = 1900 + $yearOffset;
  sprintf "%04d/%02d/%02d-%02d:%02d:%02d", $year, $month+1, $dayOfMonth, $hour, $minute, $second;
}

sub time2hours 
{
  my $secs = shift;
  my ($h, $min);
  eval {
    $h = int($secs/3600);
    $secs -= $h*3600;
    $min = int($secs/60);
  };
  if ($@) {
    $h = ($min = 0);
  }
  sprintf "%d:%2.2d", $h, $min;
}

sub writeData
{
  my ($href, $outerTag, $innerTag) = @_;
  my $xmlstr;
  my $writer = WebService::MonitorUtil::getWriter(\$xmlstr);
  $writer->startTag($outerTag);
  for my $key (sort keys %$href) {
    my $tag = (defined $innerTag) ? $innerTag : $key;
    $writer->startTag($tag);
    $writer->characters($href->{$key});
    $writer->endTag;
  }
  $writer->endTag;
  $writer->end;

  $xmlstr;
}

sub getWriter
{
  my $xmlref = shift;
  my $writer = new XML::Writer(OUTPUT => $xmlref, DATA_MODE => 'true', DATA_INDENT => 2);
  $writer->xmlDecl("UTF-8");
  $writer;  
}

sub trim
{
  my $string = shift;
  return '' unless (defined $string and length $string);
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
}

sub parseGridmapFile
{
  my $file = shift;
  my $dict = {};
  open INPUT, qq|$file| or die qq|Cannot open $file, $!|;
  while (<INPUT>) {
    s/"//; # remove the first quote, then split against the second
    my ($subject, $vo) = split /"\s+/;
    $vo =~ s/\.//; 
    $vo =~ s/prd$//; # temorary fix to get the vo name for cmsprd, babarsgm etc.
    $vo =~ s/sgm$//; 
    $dict->{WebService::MonitorUtil::trim($subject)} = WebService::MonitorUtil::trim($vo);
  }
  close INPUT;

  $dict;
}

sub parseVOMapFile
{
  my ($file, $debug) = @_;
  # Read stored info about the DN->VO mapping
  my $map = {};
  eval {
    $map = retrieve $file;
  };
  print qq|Error reading from file, $file: $@| if $@;
  if ($debug) {
    for my $dn (keys %$map) {
      print STDERR join ("#", $dn, join( ",", @{$map->{$dn}} )), "\n";
    }
  }
  $map;
}

sub getParser
{
  my $xmlin = shift;
  my $xp;
  eval
  {
    $xp = new XML::XPath(xml => $xmlin);
  };
  if ($@)
  {
    print STDERR qq[Error creating XML::XPath object: $@];
    undef $xp;
  }
  $xp;
}

sub show_message
{
  my $message = shift;
  print strftime(qq|%Y-%m-%d %H:%M:%S|, localtime), qq|: $message.\n|;
}

sub timestamp
{
   strftime "%Y-%m-%d %H:%M:%S", localtime(time());
}

sub avg
{
  my $lref = shift;
  my @list = grep { $_ ne '?' && $_ != -1 } @$lref;
  my $len = scalar @list;
  my $sum = sum @list;
  my $avg = ($len>0) ? $sum/$len : 0.0;
  $avg;  
}

1;
__END__
