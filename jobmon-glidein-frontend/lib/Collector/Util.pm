package Collector::Util;

use strict;
use warnings;
use Carp;
use Storable;

use IO::File;
use IO::Pipe;
use File::Basename;
use Net::Domain qw/hostname/;
use POSIX qw/setsid strftime/;
use List::Util qw/sum max/;

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
              trim  
           getTime 
             debug 
            escape 
  getCommandOutput
         commandFH
          readFile
        filereadFH
       getHostname
         findGroup
            isSLC4
              nCPU
               avg
         daemonize
      show_message
         storeInfo
       restoreInfo
        sortedList 
      importFields
);
$Collector::Util::VERSION = q|0.5|;

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

  my $fh = IO::File->new(qq/$command $opt |/);
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

  my $fh = IO::File->($filename, 'r');
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
  return (wantarray ? @content : join '', @content);
}
sub escape
{
  my $text = shift;  # Reference to the string
  $$text =~ s/&/\&amp;/g;
  $$text =~ s/</\&lt;/g;
  $$text =~ s/>/\&gt;/g;
  $$text =~ s/\*/\&#42;/g;
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
  return undef unless $gid;
  (getgrgid($gid))[0];
}

sub isSLC4
{
  chop(my $r = `uname -r`);
  return 1 if $r =~ /2.6/;
  return 0;
}

sub nCPU
{
  chop(my $n = `cat /proc/cpuinfo | grep '^processor' | wc -l`);
  return $n;
}

sub avg
{
  my $lref = shift;
  my @list = grep {$_ ne '?' && $_ != -1} @$lref;

  my $len = scalar @list;
  return 0.0 unless $len;

  my $sum = sum @list;
  my $avg = max $sum/$len, 0.0;
  $avg;
}

# Perl daemon process - Lincon D. Stein, Network Programming in Perl
sub open_pid_file
{
  my $file = shift;
  if (-r $file) {  # oops.  pid file already exists
    my $pid = read_pid_file($file);
    croak qq|Process already running with PID $pid| if kill 0 => $pid;
    carp  qq|Removing PID file for defunct process $pid.\n|;
    croak qq|Failed to unlink PID file $file| unless -w $file && unlink $file;
  }
  return IO::File->new($file, O_WRONLY|O_CREAT|O_EXCL, 0644)
    or croak qq|Failed to create $file: $!|;
}

sub read_pid_file
{
  my $file = shift;
  my $fh = IO::File->new($file, 'r');
  croak qq|Failed to open $file, $!| unless ($fh and $fh->opened);
  my $pid = <$fh>;
  $fh->close;
  trim $pid;
}

sub be_daemon
{
  my ($logfile, $reset_path) = @_;

  chdir '/'                   or croak qq|Failed to chdir to /: $!|;
  open STDIN,  qq|/dev/null|  or croak qq|Failed to read /dev/null: $!|;
  open STDOUT, qq|>$logfile|  or croak qq|Failed to write to $logfile: $!|;
  open STDERR, qq|>&STDOUT|   or croak qq|Failed to set stderr to stdout: $!|;
  defined(my $pid = fork)     or croak qq|Can't fork: $!|;
  exit if $pid;               # parent dies
  setsid                      or croak qq|Can't start a new session: $!|;
  umask 0;                    # forget file mode creation mask

  # Optionally set the basic environment variables here
  $ENV{PATH} = qq|/bin:/sbin:/usr/bin:/usr/sbin| if $reset_path;

  # return the new PID which should eventually be saved in the PID file
  $$;
}

sub daemonize 
{
  my $pidfile = shift || qq|/opt/jobmon/run/(basename $0).pid|;
  my $logfile = shift || qq|/dev/null|;

  # if the named PID file exits and the PID is valid (running), issue a message and quit
  # if the named PID file exits and the PID is stale unlink it and create a new one
  # if the PID file does not exists create a new one
  my $fh = open_pid_file($pidfile);

  # a short message to STDERR before it is taken off
  print STDERR qq|$0 starting, PID will be stored in $pidfile\n|;

  my $pid = be_daemon($logfile, 0);
  print $fh $pid;
  $fh->close;

  $pid;
}

sub show_message
{
  my $message = shift;
  my $stream  = shift || *STDOUT;
  print $stream strftime(qq|%Y-%m-%d %H:%M:%S|, localtime), qq|: $message.\n|;
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
  carp qq|Error storing back the $dbfile: $@| and return 0 if $@;
  return 1;
}

sub sortedList
{
  my $params = shift;
  croak q|input filelist not found!| unless defined $params->{files};
  $params->{path} = q|unknown| unless defined $params->{path};
  my @files = @{$params->{files}};

  my @sorted_list = ();
  eval {
    my %dict = map { $_ => -M $_ } @files;
    my $n_valid = grep { defined $dict{$_} } keys %dict;
    die unless $n_valid == scalar @files;
    @sorted_list = sort { $dict{$b} <=> $dict{$a} } keys %dict;
  };
  carp qq|>>> Failed to read files at $params->{path}| and return @files if $@;
  @sorted_list;
}

sub importFields
{
  map { $_ => 1 }
  qw/JID
     GRID_ID
     LOCAL_ID
     TASK_ID
     USER
     GROUP
     ACCT_GROUP
     QUEUE
     STATUS
     LSTATUS
     QTIME
     START
     END
     RANK
     PRIORITY
     EXEC_HOST
     CPUTIME
     WALLTIME
     MEM
     VMEM
     DISKUSAGE
     EX_ST
     CPULOAD
     JOBDESC
     ROLE
     GRID_CE
     GRID_SITE
     GATEKEEPER
     FQAN
     RB
     SUBJECT
     TIMELEFT/;
}

1;
__END__
