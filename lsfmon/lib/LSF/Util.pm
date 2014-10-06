package LSF::Util;

use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK);

use strict;
use warnings;
use Carp;

use List::Util qw/min/;
use IO::File;
use IO::Uncompress::Gunzip qw/$GunzipError/;
use IO::Pipe;
use File::Basename;
use Net::Domain qw/hostname/;
use POSIX qw/setsid strftime/;
use Storable;
use File::Copy;
use XML::Writer;
use XML::Simple qw/:strict/;
use JSON qw/encode_json/;

require Exporter;
@ISA = qw(Exporter AutoLoader);
@EXPORT = qw( 
);
@EXPORT_OK = qw(
          createHTML
           createXML
           writeData
  createHappyFaceXML
          createJSON
                trim  
             getTime 
               debug 
           commandFH
    getCommandOutput
          filereadFH
            readFile
           writeFile
         getHostname
           findGroup
           storeInfo
         restoreInfo
        show_message
          sortedList
);
$LSF::Util::VERSION = q|0.5|;

# Remove whitespace from the start and end of the string
sub trim
{
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
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
sub writeJobFlow
{
  my ($writer, $params) = @_;
  my ($s,$d,$c) = map { LSF::Util::trim $_ } (split /\|/, $params->{jobflow});
  my $href = 
  {
     submitted => $s,
    dispatched => $d,
     completed => $c
  };
  $writer->startTag(q|jobflow|, timerange => $params->{timerange});
  for my $k (sort keys %$href) {
    $writer->startTag($k);
    $writer->characters((exists $href->{$k} ? $href->{$k} : '-'));
    $writer->endTag($k);
  }
  $writer->endTag(q|jobflow|);
}
sub createHTML
{
  my ($file, $content) = @_;
  my $tmpFile = qq|$file.tmp|;
  my $fh = IO::File->new($tmpFile, 'w');
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
  my $xs = XML::Simple->new;
  my $fh = IO::File->new($file, 'w');
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  my $xml = $xs->XMLout($dict, XMLDecl => 1,
                                 NoAttr => 1, 
                                KeyAttr => $key_attr,
                               RootName => $root_name,
                             OutputFile => $fh);
  $fh->close;
}
sub createHappyFaceXML
{
  my ($dict, $config, $params) = @_;
  croak q|Application wide configuration must be available!| unless defined $config;

  my $verbose = $config->{verbose} || 0;

  # Open the output XML file
  my $file = $config->{overview}{xml_hf}{file} || qq|$config->{baseDir}/html/jobview.xml|;
  my $fh = IO::File->new($file, 'w');
  croak qq|Failed to open output file $file, $!, stopped| unless defined $fh;

  # Create a XML writer object
  my $writer = XML::Writer->new(OUTPUT => $fh, 
                             DATA_MODE => 'true', 
                           CHECK_PRINT => 1,
                           DATA_INDENT => 2);
  $writer->xmlDecl;

  # Make the xml syntax happy by creating a <JobList> tag
  # that will be eventually closed in the destructor
  $writer->startTag(q|jobinfo|);

  # header
  $writer->startTag(q|header|);
  writeData($writer, $dict->{header});
  $writer->endTag(q|header|);
   
  $writer->startTag(q|summaries|);

  # Overall Summary
  my $period = $config->{jobflow}{period} || 3600;
  $writer->startTag(q|summary|, group => q|all|);
  my $jobinfo = $dict->{jobs};
  my $jobflow = delete $jobinfo->{jobflow};
  writeData($writer, $jobinfo);
  writeJobFlow($writer, {jobflow => $jobflow, timerange => $period} ) 
    if defined $jobflow;
  $writer->endTag(q|summary|);
 
  # Group Summary    
  my $groupinfo = $dict->{grouplist}{group};  
  print Data::Dumper->Dump([$groupinfo], [qw/groupinfo/]) if $verbose>1;
  for my $group (sort keys %$groupinfo) {
    $writer->startTag(q|summary|, group => $groupinfo->{$group}{name}, parent => q|all|);
    delete $groupinfo->{$group}{name};
    my $jobflow = delete $groupinfo->{$group}{jobflow};
    writeData($writer, $groupinfo->{$group});
    writeJobFlow($writer, {jobflow => $jobflow, timerange => $period} ) 
      if defined $jobflow;
    $writer->endTag(q|summary|);
  }
  $writer->endTag(q|summaries|);

  # optionally individual jobs
  my $showJobs = $config->{overview}{xml_hf}{show_joblist} || 0;
  if ($showJobs) {
    my $joblist = $params->{joblist} || {};
    my $showDN = $config->{overview}{xml_hf}{show_dn} || 0;
    $writer->startTag(q|jobs|);
    while ( my ($jid, $job) = each %$joblist ) {
      my $group = $job->GROUP;
      my $status = $job->STATUS;
      warn q|either group or job status undefined| 
        and next unless (defined $group and defined $status);
      $writer->startTag(q|job|, group => $group, status => $status);
      my $cputime  = $job->CPUTIME  || 0;
      my $walltime = $job->WALLTIME || 0;
      my $ratio = min(1, (($walltime>0) ? $cputime/$walltime : 0));

      #<state>[running|pending|held|waiting|suspended|exited]</state>
      my $ce = $job->UI_HOST;
      $ce = (defined $ce) ? (split m#/#, $ce)[0] : 'undef';
      my $jobinfo = 
      {
              id => $jid,
           state => $job->LSTATUS,
          status => $status,
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
    my $jobflow = delete $ceinfo->{$ce}{jobflow};
    writeData($writer, $ceinfo->{$ce});
    writeJobFlow($writer, {jobflow => $jobflow, timerange => $period} ) 
      if defined $jobflow;
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
    my $jobflow = delete $userinfo->{$dn}{jobflow};
    writeData($writer, $userinfo->{$dn});
    writeJobFlow($writer, {jobflow => $jobflow, timerange => $period} ) 
      if defined $jobflow;
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
  my $fh = IO::File->new($file, 'w');
  $fh->opened or die qq|Failed to open $file, $!, stopped|;

  my $jsobj = JSON->new->utf8->allow_nonref;
  my $json = $jsobj->pretty->encode($dict); # pretty-printing
  print $fh $json;
  $fh->close;
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
    return (wantarray ? () : q||);
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open command pipe for $command| if $verbose;
    $$ecode = 2;
    return (wantarray ? () : q||);
  }
  if ($fh->eof) {
    carp q|ERROR. end-of-file reached too soon!| if $verbose;
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

  my $fh = IO::Uncompress::Gunzip->new($filename);
  unless (defined $fh && $fh) {
    carp qq|ERROR. Failed to create file handle for $filename| if $verbose;
    ###IO::Uncompress::Gunzip failed: $GunzipError
    return undef;
  }
  unless ($fh->opened) {
    carp qq|ERROR. Failed to open $filename| if $verbose;
    return undef;
  }
  if ($fh->eof) {
    carp q|WARNING. End-of-File reached too soon!| if $verbose;
    $fh->close and return undef; 
  }

  $fh;
}
sub readFile
{
  my ($filename, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $fh = IO::Uncompress::Gunzip->new($filename);
  unless ($fh && $fh->opened) {
    carp qq|ERROR. Failed to open $filename, $!| if $verbose;
    ###IO::Uncompress::Gunzip failed: $GunzipError
    return (wantarray ? () : q||);
  }
  if ($fh->eof) {
    carp q|WARNING. End-of-File reached too soon!| if $verbose;
    $fh->close;
    return (wantarray ? () : q||);
  }
  my @content = <$fh>;
  $fh->close;
  return (wantarray ? @content : join '', @content);
}
sub writeFile
{
  my ($file, $content) = @_;
  my $fh = IO::File->new($file, 'w');
  $fh->opened or die qq|Failed to open $file, $!, stopped|;
  print $fh $content;
  $fh->close;
}
sub getHostname 
{
  return (split /\./, hostname())[0];
}

sub findGroup 
{
  my $user = shift;
  my $gid = (getpwnam($user))[3];
  return undef unless $gid;
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

1;
__END__
