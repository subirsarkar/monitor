package Collector::Util;

use strict;
use warnings;
use Carp;
use Storable;
use IO::File;
use File::Copy;
use File::Basename;
use File::stat;
use POSIX qw/setsid strftime/;
use Net::Domain qw/hostname/;
use List::Util qw/min max/;
use XML::Writer;
use XML::Simple qw/:strict/;
use JSON;
use XML::XPath;
use XML::XPath::XMLParser;
$XML::XPath::SafeMode = 1;  # Enable     

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
                trim  
        show_message
             getTime 
               debug 
           commandFH
    getCommandOutput
          filereadFH
            readFile
         getHostname
           findGroup
           storeInfo
         restoreInfo
            file_age
        updateSlotDB
           getParser
        show_message
          createHTML
           createXML
           writeData
  createHappyFaceXML
          createJSON
          sortedList
          read_dnmap
);
$Collector::Util::VERSION = '0.5';

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
  print STDERR qq|DEBUG $index ...\n|;
}

sub commandFH
{
  my ($command, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $pipe = new IO::Pipe;
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

  my $fh = new IO::File qq[$command $opt |];
  unless (defined $fh and $fh) {
    carp qq|$command failed!, $!| if $verbose;
    $$ecode = 1;
    return (wantarray ? () : q||);
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open command pipe for $command| if $verbose;
    $$ecode = 2;
    return (wantarray ? () : q||);
  }
  if ($fh->eof) {
    carp qq|ERROR. end-of-file reached too soon!| if $verbose;
    $$ecode = 3;
    $fh->close;
    return (wantarray ? () : q||);
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

  my $fh = new IO::File $filename, 'r';
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

  my $fh = new IO::File $filename, 'r';
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

sub file_age
{
  my $file = shift;
  -r $file or return -1; 
  time() - stat($file)->mtime;
}

sub updateSlotDB
{
  my $slots = shift;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $slotDB = $config->{db}{slot};
  return $slots unless defined $slotDB;

  my $nent = 0;
  if ( -r $slotDB ) {
    my $info = restoreInfo($slotDB);
    my $nel  = $info->{slots};

    storeInfo($slotDB, {slots => $slots} ) if $slots > $nel;
    $nent = max $nel, $slots;
  }
  else {
    storeInfo($slotDB, {slots => $slots} );
    $nent = $slots;
  }
  $nent;
}

sub getParser
{
  my $attr = shift;
  my $xp;
  eval {
    $xp = new XML::XPath(%$attr);
  };
  if ($@) {
    print STDERR qq[Error creating XML::XPath object: $@];
    undef $xp;
  }
  $xp;
}

sub createHTML
{
  my ($file, $content) = @_;
  my $tmpFile = qq|$file.tmp|;
  my $fh = new IO::File $tmpFile, 'w';
  $fh->opened or die qq|Failed to open $tmpFile, $!, stopped|;
  print $fh $content;
  $fh->close;

  # Atomic step
  # use a temporary file and then copy to the final in an atomic step
  # Slightly irrelavant in this case
  copy $tmpFile, $file or
    warn qq|Failed to copy $tmpFile to $file: $!\n|;
  unlink $tmpFile;
}
sub createXML
{
  my ($file, $dict, $key_attr, $root_name) = @_;
  my $xs = new XML::Simple;
  my $fh = new IO::File $file, 'w';
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  my $xml = $xs->XMLout($dict, XMLDecl => 1,
                                 NoAttr => 1, 
                                KeyAttr => $key_attr,
                               RootName => $root_name,
                             OutputFile => $fh);
  $fh->close;
}
sub writeData
{
  my ($writer, $href) = @_;
  for my $k (sort keys %$href) {
    $writer->startTag($k);
    $writer->characters((exists $href->{$k} ? $href->{$k} : '-'));
    $writer->endTag($k);
  }
}
sub createHappyFaceXML
{
  my ($dict, $config, $params) = @_;
  croak qq|Application wide configuration must be available!| unless defined $config;
  my $verbose = $config->{verbose} || 0;

  # Open the output XML file
  my $file = $config->{xml_hf}{file} || qq|$config->{baseDir}/html/jobview.xml|;
  my $fh = new IO::File $file, 'w';
  die qq|Failed to open output file $file, $!, stopped| unless defined $fh;

  # Create a XML writer object
  my $writer = new XML::Writer(OUTPUT => $fh, 
                            DATA_MODE => 'true', 
                          CHECK_PRINT => 1,
                          DATA_INDENT => 2);
  $writer->xmlDecl;

  $writer->startTag(q|jobinfo|);
  # header
  $writer->startTag(q|header|);
  writeData($writer, $dict->{header});
  $writer->endTag(q|header|);
   
  $writer->startTag(q|summaries|);

  # Overall Summary
  $writer->startTag(q|summary|, group => q|all|);
  my $jobinfo = $dict->{jobs};
  writeData($writer, $jobinfo);
  $writer->endTag(q|summary|);
 
  # Group Summary    
  my $groupinfo = $dict->{grouplist}{group};  
  print Data::Dumper->Dump([$groupinfo], [qw/groupinfo/]) if $verbose>1;
  for my $group (sort keys %$groupinfo) {
    $writer->startTag(q|summary|, group => $groupinfo->{$group}{name}, parent => q|all|);
    delete $groupinfo->{$group}{name};
    writeData($writer, $groupinfo->{$group});
    $writer->endTag(q|summary|);
  }
  $writer->endTag(q|summaries|);

  # optionally individual jobs
  my $showJobs = $config->{xml_hf}{show_joblist} || 0;
  if ($showJobs) {
    my $joblist = $params->{joblist} || {};
    my $showDN = $config->{xml_hf}{show_dn} || 0;
    $writer->startTag(q|jobs|);
    while ( my ($jid, $job) = each %$joblist ) {
      my $group = $job->GROUP;
      my $status = $job->STATUS;
      warn q|either group or job status undefined| 
        and next unless (defined $group and defined $status);
      $writer->startTag(q|job|, group => $group, status => $status);
      my $cputime  = $job->CPUTIME  || 0;
      my $walltime = $job->WALLTIME || 0;
      my $ratio = min 1, (($walltime>0) ? $cputime/$walltime : 0);

      #<state>[running|pending|held|waiting|suspended|exited]</state>
      my $ce = $job->GRID_CE;
      $ce = (defined $ce) ? (split m#/#, $ce)[0] : 'undef';
      my $jobinfo = 
      {
              id => $jid,
           state => $job->LSTATUS,
          status => $job->STATUS,
           group => $group,
         created => $job->QTIME || 'undef',  
           queue => $job->QUEUE || 'undef',
            user => $job->USER || 'undef',
              ce => $ce,
             end => $job->END || 'n/a'
      };
      $jobinfo->{dn} = $job->SUBJECT || 'local' if $showDN;
      if ($status eq 'R') {
        my $host = $job->EXEC_HOST;
        $host = (defined $host) ? (split /\@/, $host)[-1] : '?';
        $jobinfo->{cpueff}     = trim(sprintf(qq|%7.2f|, 100 * $ratio));
        $jobinfo->{cputime}    = int($cputime);
        $jobinfo->{cpupercent} = trim(sprintf(qq|%7.2f|, 100 * $ratio));
        $jobinfo->{exec_host}  = $host;
        $jobinfo->{walltime}   = int($walltime);
        $jobinfo->{start}      = $job->START || 'undef';
      }
      writeData($writer, $jobinfo);
      $writer->endTag(q|job|);
    }
    $writer->endTag(q|jobs|);
  }

  # finally everything else under <additional>
  $writer->startTag(q|additional|);

  # slots
  $writer->startTag(q|slots|);
  writeData($writer, $dict->{slots});
  $writer->endTag(q|slots|);

  # CE info    
  my $ceinfo = $dict->{celist}{ce};  
  print Data::Dumper->Dump([$ceinfo], [qw/ceinfo/]) if $verbose>1;
  $writer->startTag(q|celist|);
  for my $ce (sort keys %$ceinfo) {
    $writer->startTag(q|ce|, name => $ceinfo->{$ce}{name});
    delete $ceinfo->{$ce}{name};
    writeData($writer, $ceinfo->{$ce});
    $writer->endTag(q|ce|);
  }
  $writer->endTag(q|celist|);

  # User Info
  my $userinfo = $dict->{dnlist}{dn};  
  print Data::Dumper->Dump([$userinfo], [qw/userinfo/]) if $verbose>1;
  $writer->startTag(q|users|);
  for my $dn (sort keys %$userinfo) {
    $writer->startTag(q|dn|, name => $userinfo->{$dn}{name});
    delete $userinfo->{$dn}{name}; 
    writeData($writer, $userinfo->{$dn});
    $writer->endTag(q|dn|);
  }
  $writer->endTag(q|users|);
  $writer->endTag(q|additional|);
  $writer->endTag(q|jobinfo|);

  # close the writer and the filehandle
  $writer->end;
  $fh->close;
}
sub createJSON
{
  my ($file, $dict, $root_name) = @_;
  my $fh = new IO::File $file, 'w';
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  my $jsobj = new JSON(pretty => 1, delimiter => 0, skipinvalid => 1);
  my $json = ($jsobj->can('encode'))
    ? $jsobj->encode({ $root_name => $dict })
    : $jsobj->objToJson({ $root_name => $dict });
  print $fh $json;
  $fh->close;
}
sub show_message
{
  my $message = shift;
  my $stream  = shift || *STDOUT;
  print $stream strftime(qq|%Y-%m-%d %H:%M:%S|, localtime), qq|: $message.\n|;
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
sub read_dnmap
{
  my ($files, $dnmap, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  # Build a (JID, DN) map
  for my $file (@$files) {
    my $fh = filereadFH($file, $verbose);
    if (defined $fh) {
      while (<$fh>) {
        my ($jid, $dn) = (split /##/, trim $_);
        next unless defined $dn;
        $dnmap->{$jid} = $dn;
      }
      $fh->close;
    }
  }
}

1;
__END__
