package Util;

use strict;
use warnings;
use Carp;
use Storable;

use IO::File;
use IO::Pipe;
use File::Basename;
use POSIX qw/setsid strftime/;
use Net::Domain qw/hostname/;

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
              trim  
           getTime 
             debug 
      show_message
         commandFH
  getCommandOutput
        filereadFH
          readFile
       getHostname
         findGroup
         storeInfo
       restoreInfo
        create_rrd     
        update_rrd
      create_graph 
);
$Util::VERSION = q|0.7|;

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

sub debug
{
  my $index = shift;
  print STDERR "DEBUG ".$index."...\n";
}

sub commandFH
{
  my ($command, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $pipe = IO::Pipe->new;
  $pipe->reader($command);
  unless (defined $pipe) {
    carp qq|ERROR. command pipe failed for $command, $!| if $verbose;
    return undef;
  }
  if ($pipe->eof) {
    carp qq|Unexpected EOF for command: $command| if $verbose;
    $pipe->close and return undef;
  }
  $pipe;
}
# by default command error goes to /dev/null
# pass show_error > 0 in order to send command error to stderr
sub getCommandOutput
{
  my ($command, $ecode, $show_error, $verbose) = @_;  # exit code should be passed by reference
  my $opt = (defined $show_error and $show_error>0) ? '' : q|2>/dev/null|;
  $verbose = 0 unless defined $verbose;

  my $fh = IO::File->new(qq[$command $opt |]);
  unless (defined $fh and $fh) {
    carp qq|$command failed!, $!| if $verbose;
    $$ecode = 1;
    return (wantarray ? () : qq||);
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open command pipe for $command| if $verbose;
    $$ecode = 2;
    return (wantarray ? () : qq||);
  }
  if ($fh->eof) {
    carp qq|ERROR. end-of-file reached too soon!| if $verbose;
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
    return undef
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open $filename| if $verbose;
    return undef
  }
  if ($fh->eof) {
    carp qq|WARNING. End-of-File reached too soon!| if $verbose;
    $fh->close and return undef;
  }

  $fh;
}
sub readFile
{
  my ($filename, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $fh = IO::File->new($filename, 'r');
  unless ($fh && $fh->opened) {
    carp qq|ERROR. Failed to open $filename, $!| if $verbose;
    return (wantarray ? () : qq||);
  }
  if ($fh->eof) {
    carp qq|WARNING. End-of-File reached too soon!| if $verbose;
    $fh->close;
    return (wantarray ? () : qq||);
  }
  my @content = <$fh>;
  $fh->close;
  return (wantarray ? @content : join "", @content);
}

sub getHostname 
{
  my $host = (split /\./, hostname())[0];
  lc $host;
}

sub findGroup
{
  my $user = shift;
  my $gid = (getpwnam($user))[3];
  return qq|?| unless $gid;
  (getgrgid($gid))[0];
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
sub show_message
{
  my $message = shift;
  my $stream  = shift || *STDOUT;
  print $stream strftime(qq|%Y-%m-%d %H:%M:%S|, localtime), qq|: $message.\n|;
}

1;
__END__
