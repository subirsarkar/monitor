package BaseTools::Util;

use strict;
use warnings;
use Carp;

use IO::File;
use File::Find;
use File::Copy;
use Storable;

use XML::XPath;
use XML::XPath::XMLParser;
$XML::XPath::SafeMode = 1;  # Enable

use Net::Domain qw/hostname/;
use POSIX qw/setsid/;

use POSIX qw/strftime/;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
                  trim  
               getTime 
              parseInt
                 debug 
      getCommandOutput
              readFile
            filereadFH
           getHostname
               message
             writeHTML
           traverseDir
               readDir
             storeInfo
           restoreInfo
          getXMLParser
  fisher_yates_shuffle 
);
our $VERSION = "1.0";

use constant DEBUG => 0;

# Remove whitespace from the start and end of the string
sub trim
{
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
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

sub parseInt
{
  my ($arg, $patt) = @_;
  return -1 unless (defined $arg and length $arg);

  $arg =~ s#$patt## if defined $patt;
  ($arg =~ /(-?\d+)/) ? $1 : -1;
}

sub debug
{
  my $index = shift;
  print STDERR "DEBUG ".$index."...\n";
}

sub getCommandOutput
{
  my ($command, $ecode) = @_;  # exit code should be passed by reference 
  $$ecode = 0 unless defined $ecode;
  my $fh = IO::File->new(qq!$command 2>/dev/null |!);

  unless (defined $fh and $fh) {
    carp qq|$command failed!, $!| if DEBUG; 
    $$ecode = 1;
    return (wantarray ? () : qq||) 
  }

  unless ($fh->opened) {
    carp qq|ERROR. Failed to open command pipe for $command| if DEBUG;
    $$ecode = 2;
    return (wantarray ? () : qq||);
  }

  if ($fh->eof) {
    carp qq|ERROR. end-of-file reached too soon!| if DEBUG;
    $$ecode = 3;
    $fh->close;
    return (wantarray ? () : qq||); 
  }

  my @content = <$fh>;
  $fh->close;
  $$ecode = 0;
  return (wantarray ? @content : join '', @content);
}

sub readFile
{
  my ($filename, $ecode) = @_;
  $$ecode = 0 unless defined $ecode;
  my $fh = IO::File->new($filename, 'r');

  unless (defined $fh and $fh) {
    carp qq|Failed to open $filename, $!| if DEBUG;
    $$ecode = 1;
    return (wantarray ? () : qq||);
  }

  unless ($fh->opened) {
    carp qq|ERROR. Failed to open $filename| if DEBUG;
    $$ecode = 2;
    return (wantarray ? () : qq||);
  }
  if ($fh->eof) {
    carp qq|ERROR. end-of-file reached too soon!| if DEBUG;
    $$ecode = 3;
    $fh->close;
    return (wantarray ? () : qq||); 
  }

  my @content = <$fh>;
  $fh->close;
  $$ecode = 0;
  return (wantarray ? @content : join '', @content);
}

sub filereadFH
{
  my ($filename, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $fh = IO::File->new($filename, 'r');
  unless (defined $fh && $fh) {
    carp qq|ERROR. Failed to create file handle for $filename| if $verbose;
    return undef;
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open $filename| if $verbose;
    return undef;
  }
  if ($fh->eof) {
    carp qq|WARNING. End-of-File reached too soon!| if $verbose;
    $fh->close and return undef;
  }

  $fh;
}
sub getHostname
{
  return (split /\./, hostname())[0];
}

sub message
{
  my ($color, $txt) = @_;
  my $now = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
  print $color, $now, RESET;
  print $txt, "\n";
}

sub writeHTML
{
  my ($htmlFile, $output) = @_;
  my $tmpFile = qq|$htmlFile.tmp|;
  my $fh = IO::File->new($tmpFile, 'w');
  die qq|Failed to open $tmpFile, $!, stopped| unless ($fh && $fh->opened);
  print $fh $output;
  $fh->close;

  # Atomic step
  copy $tmpFile, $htmlFile or
        carp qq|Failed to copy $tmpFile to $htmlFile: $!\n|;
  unlink $tmpFile;
}

sub readDir
{
  my $dir = shift;
  # Read all the log files. This should be done only once
  local *DIR;
  opendir DIR, $dir || die qq|Failed to open directory $dir, $!, stopped|;
  my @list = map { qq|$dir/$_| } readdir DIR;
  closedir DIR;

  grep -f, @list;
}

sub traverseDir
{
  my $dir = shift;
  my @list;
  my $traversal = sub
  {
    -f and push @list, $File::Find::name;
  };
  find $traversal, $dir;
  @list;
}

sub restoreInfo
{
  my $dbfile = shift;
  my $info = {};
  eval {
    $info = retrieve $dbfile;
  };
  carp qq|Error reading from $dbfile: $@| if $@;

  $info;
}

sub storeInfo
{
  my ($dbfile, $info) = @_;
  eval {
    store $info, $dbfile;
  };
  carp qq|Error storing back the $dbfile: $@| if $@;
}

sub getXMLParser
{
  my $xmlin = shift;
  my $xp;
  eval {
    $xp = XML::XPath->new(xml => $xmlin);
  };
  if ($@) {
    print STDERR qq|Error creating XML::XPath object: $@|;
    undef $xp;
  }
  $xp;
}

# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub fisher_yates_shuffle 
{
  my $array = shift;
  my $i;
  for ($i = @$array; --$i; ) {
    my $j = int rand ($i+1);
    next if $i == $j;
    @$array[$i,$j] = @$array[$j,$i];
  }
}

1;
__END__

# -- Documentation starts

=pod

=head1 NAME

BaseTools::Util - A collection of utility functions.

=head1 SYNOPSIS

  use BaseTools::Util qw/trim readFile/;
  my $content = readFile($infile);
  my @list    = readFile($infile); # wantarray

=head1 REQUIRES

  File::Find
  File::Copy
  Net::Domain
  POSIX
  Term::ANSIColor

=head1 INHERITANCE

none.

=head1 EXPORTS

  trim  
  getTime 
  debug 
  getCommandOutput
  readFile
  getHostname
  message
  writeHTML
  readDir
  traverseDir

=head1 DESCRIPTION

A collection of utility functions.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * trim ($str): $str

Remove leading and trailing spaces of a string and returns the modified string

=item * getTime($time): $fmt_timestamp

Converts a long integer into a formatted string

=item * debug ($arg): None

Prints a debug string by appending $arg

=item * getCommandOutput ($command): $content [@content]

Executes a command and returns the output either as a scalar string or as an array of output lines
depending on the context (caller)

=item * readFile  ($filename): $content [@content]

Read a file and returns the content either as a single string or as an array of output lines
depending on the context (caller)

=item * getHostname (None): $hostname

Executes Net::Domain::hostname and returns the B<hostname -s>

=item * message ($color, $text): None

Print a message string preceded by a time stamp that used Term::ANSIColor

    $color - Color of the time stamp that hints at the status (GREEN, RED, BLUE etc.)
    $text  - The message string

=item * writeHTML ($filename, $content): None

Save the HTML content in a file

    $filename - output file name
    $content  - HTML content to be saved
 
=item * readDir ($dirname): @list

Finds the files in a directory and returns the list

    $dirname - Directory name

=item * traverseDir ($dirname): @list

Finds the files in a directory recursively and returns the list of files

    $dirname - Directory name

=back 

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Util.pm,v1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
