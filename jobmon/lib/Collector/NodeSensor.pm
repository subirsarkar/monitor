package Collector::NodeSensor;

use strict;
use warnings;
use Carp;

use DBI;
use IO::File;
use File::Copy;
use File::Basename;

use XML::Writer;

use Collector::ConfigReader;
use Collector::ObjectFactory;
use Collector::NodeInfo;
use Collector::Util qw/getHostname/;
use Collector::DBHandle;

$Collector::NodeSensor::VERSION = q|1.0|;

our $batchAttr =
{
     lsf => q|Collector::LSF::NodeInfo|,
     pbs => q|Collector::PBS::NodeInfo|,
  condor => q|Collector::Condor::NodeInfo|
};

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  # read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  bless {
    config => $config,
    dbconn => new Collector::DBHandle()
  }, $class;
}

sub writeData
{
  my ($writer, $tag, $data) = @_;
  $writer->startTag($tag);
  $writer->characters($data);
  $writer->endTag;
}
sub writeData2
{
  my ($writer, $tag, %data) = @_;
  $writer->startTag($tag, %data);
  $writer->endTag;
}
sub createXML
{
  my $self = shift;
  my $config = $self->{config};

  my $xmldir  = $config->{xmldir};
  my $lrms    = $config->{lrms} || croak qq|Batch system not specified in config.pl!|;
  my $verbose = $config->{verbose} || 0;

  my $host = getHostname();
  my $xmlfile = qq|$xmldir/$host.xml|; 
  my $tmpfile = qq|$xmlfile.tmp|; 

  my $fh = new IO::File $tmpfile, 'w';
  croak qq|Failed to open output file $tmpfile, $!, stopped| 
     unless (defined $fh && $fh->opened);

  # Create a XML writer object
  my $writer = new XML::Writer(OUTPUT => $fh,
                            DATA_MODE => 'true',
                          DATA_INDENT => 2);
  $writer->xmlDecl('iso-8859-1');
  $writer->startTag(q|info|);

  my $class = $batchAttr->{$lrms} || croak qq|Batch system $lrms not supported, stopped|;
  my $obj = Collector::ObjectFactory->instantiate($class);
  my $list = $obj->jobids;
  for my $jid (@$list) {
    print STDERR ">>> Processing JID=$jid\n" if $verbose;
    $writer->startTag(q|jid|, value => $jid);
  
    # Load
    writeData($writer, q|load|, sprintf("%7.5f", $obj->getLoad($jid)));
    writeData($writer, q|diskusage|, $obj->getDiskUsage($jid));
    my $href = $obj->getJobMemory($jid);
    writeData2($writer, q|jobmem|, %$href);

    # Processes
    my $text = $obj->getProcesses($jid);
    writeData($writer, q|ps|, $text);
  
    # Workdir listing
    $text = $obj->listWorkDir($jid);
    writeData($writer, q|workdir|, (defined $text ? $text : '?'));
    
    # Jobdir listing
    $text = $obj->listJobDir($jid);
    writeData($writer, q|jobdir|, (defined $text ? $text : '?'));

    # Job tracking
    $text = $obj->jobTracking($jid, qq|log|);
    writeData($writer, q|log|, (defined $text ? $text : '?'));
  
    $text = $obj->jobTracking($jid, qq|error|);
    writeData($writer, q|error|, (defined $text ? $text : '?'));
  
    # </jid>
    $writer->endTag;
  }
  
  # Top and other info
  my $text = Collector::NodeInfo->getTop;
  writeData($writer, q|top|, $text);
  
  # Memory, swap memory etc.
  my $aref = Collector::NodeInfo->getMemory;
  writeData2($writer, q|mem|, total => $aref->[0], 
                               used => $aref->[1],
                               free => $aref->[2]);

  $aref = Collector::NodeInfo->getSwap;
  writeData2($writer, q|swap|, total => $aref->[0], 
                                used => $aref->[1],
                                free => $aref->[2]);
  
  $aref = Collector::NodeInfo->getTotalLoad;
  writeData2($writer, q|totalload|, min_1 => $aref->[0],
                                    min_5 => $aref->[1],
                                   min_15 => $aref->[2]);
  
  # </info>
  $writer->endTag;

  # close the writer and the filehandle
  $writer->end;
  $fh->close;

  # Atomic step
  copy $tmpfile, $xmlfile or
        carp qq|Failed to copy $tmpfile to $xmlfile: $!\n|;
  unlink $tmpfile;
}

sub storeXML
{
  my $self = shift;
  my $config = $self->{config};

  my $host = getHostname();
  my $xmldir  = $config->{xmldir};
  my $inputFile = qq|$xmldir/$host.xml|;
  my $bname = basename $inputFile;

  my $dbh = $self->{dbconn}->dbh;

  # Find if the file already exists
  my $stha = $dbh->prepare(q|SELECT COUNT(name) from wninfo WHERE name=?|);
  $stha->execute($bname);
  my ($count) = $stha->fetchrow_array;
  $stha->finish;

  # decide on insert/update 
  my $sthb = ($count) 
        ? $dbh->prepare(q|UPDATE wninfo SET type=?,size=?,timestamp=?,data=? WHERE name=?|)
        : $dbh->prepare(q|INSERT INTO wninfo (type,size,timestamp,data,name) VALUES(?,?,?,?,?)|);

  # Read file content, get file size and current time
  my $var;
  open(my $fh, $inputFile) or croak qq|Cannot open $inputFile, $!, stopped|;
  my $bytes = read ($fh, $var, -s $fh);
  close $fh;

  $sthb->execute('text/xml', $bytes, time(), $var, $bname);

  # We are done with this iteration, so close all the active handles
  $sthb->finish;
}

1;
__END__
