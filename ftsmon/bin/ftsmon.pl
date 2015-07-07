#!/usr/bin/env perl

package main;

# Declaration of globals
use vars qw/$verbose $server $help $channel @states $xmlfile/;
use vars qw/$instance $endpoint $INFO $min2ms/;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use IO::File;
use File::Basename;
use Storable;

use lib qw(/home/phedex/lib/perl5 /opt/glite/lib/perl5/site_perl/5.8.0/ /home/phedex/bin);
use XML::Writer;
use GLite::Data::FileTransfer;
use DBConnection;
use Util qw(_trim _debug getTime);

sub getOptions;
sub usage;
sub writeData($$);
sub getStorageInfo;
sub match;
sub _main;

use constant DEBUG => 0;
# Command line options with Getopt::Long
$verbose  = '';
$help     = '';
@states   = ();
$channel  = '';
$xmlfile  = qq[/home/phedex/bin/test.xml];
$server   = qq[fts.cr.cnaf.infn.it];
$instance = qq[Dev];
$INFO     = qq[/home/phedex/bin/info.dat];
$min2ms   = 60000.0;

my $pool2dir =
{
   'cmsdcache1_1' => ["cmsdcache1", "/storage/d1"],
   'cmsdcache1_2' => ["cmsdcache1", "/storage/panasas"],
   'cmsdcache2_1' => ["cmsdcache2", "/storage/d2"],
   'cmsdcache2_2' => ["cmsdcache2", "/storage/r1"],
   'cmsdcache2_3' => ["cmsdcache2", "/storage/r2"]
};

sub usage () {
  print <<HEAD;
  Query the file transfer status and report all the results in an XML file

  The command line options are

  --verbose   (D=noverbose)
  --help      show help on this tool and quit (D=nohelp)
  --ftsserv   The FTS Server (D=fts.cr.cnaf.infn.it)
  --states    A list of job states, either as --states=Active --states=Pending or/and as
                                             --states=Active,Pending,... (D=All)
  --channel   Transfer Channel (D='All')
  --instance  DB Instance (D='Dev')
  --xmlfile   The output XML file (D='test.xml')

  Example usage:
  perl -w ftsmon.pl --channel=STAR-PISA --states=Active,Pending --xmlfile=mon.xml

Subir Sarkar
28/10/2006 17:15 hrs
HEAD

exit 0;
}

sub getOptions {
  # Extract command line options
  GetOptions 'verbose!'   => \$verbose,
             'help!'      => \&usage,
             'ftsserv=s'  => \$server,
             'states=s'   => \@states,
             'channel=s'  => \$channel,
             'instance=s' => \$instance,
             'xmlfile=s'  => \$xmlfile;

  @states = split /,/, join(',', @states);
  @states = ('Submitted', 'Pending', 'Active') if !scalar @states;
  print "Arglist:: ", join (":", join (",", @states), $channel, $xmlfile), "\n" if DEBUG;
  $channel = '' if $channel eq 'All';

  $endpoint = "https://".$server.":8443/glite-data-transfer-fts/services/FileTransfer";
}

sub getStorageInfo {
  # Read stored info about the expected size
  my $storedinfo = {};
  eval {
    $storedinfo = retrieve($INFO);
  };
  print "Error reading from file: $@" if $@;

  # Get the list of valid files from dCache
  my $h = {};
  my $command = qq(ssh root\@cmsdcache /bin/cat /root/bin/activeTransfers.list 2>/dev/null | \
                    awk '{if (NF>10 && \$10!=\"?\") print \$0}' |);
  open INPUT, "$command" or die "Cannot execute $command, $!";
  chomp(my @data = <INPUT>); 
  close INPUT;
  for (@data)  
  {
    next if /^$/;   # blank line
    my @f = split /\s+/, _trim($_);
    my $command = pop @f;  # Recently we have added a way to recognise I/O method (STOR, ERET etc.)
                           # which should be irrelevant here
    my $name = pop @f;
    $h->{_trim($name)} = \@f;
    print join (",", @f), "\n" if DEBUG;
  }

  # Now prepare the array of files for which we need to connect to the DB
  my @arr = ();
  for my $file (sort keys %$h) 
  {
    if (exists $storedinfo->{$file}) {
      next if (defined $storedinfo->{$file}[0] && defined $storedinfo->{$file}[1]);
    }
    push(@arr, $file);
  }

  if (scalar(@arr)>0) 
  {
    # Once list is ready, easy to connect to the DB and get the size (and CRC)
    my $conn   = new DBConnection($ENV{"HOME"}."/SITECONF/Pisa/PhEDEx/DBParam:$instance/PISA"); 
    my $dbinfo = $conn->query(\@arr); 
    for my $f (sort keys %$dbinfo) {
      my $dbsize = (defined $dbinfo->{$f}[0]) ? $dbinfo->{$f}[0] : 0;
      my $crc    = (defined $dbinfo->{$f}[1]) ? $dbinfo->{$f}[1] : 0;
      $storedinfo->{$f} = [$dbsize, $crc];
    } 
  }
  
  my $info = {};
  for my $file (sort keys %$h) 
  {
    my $filesize_db = $storedinfo->{$file}[0];
    $filesize_db = (defined $filesize_db) ? int($filesize_db) : 0;

    my $f    = $h->{$file};
    my $size = int($f->[4]);
    my $perc = ($filesize_db>0) ? $size*100/$filesize_db : 0.0;
    my $progress = sprintf "%7.2g%% (%D of %U Bytes)", $perc, $size, $filesize_db;

    $info->{$file}{CreationTime} = getTime($f->[6]);
    $info->{$file}{Progress}     = $progress;
    $info->{$file}{GridFtpCell}  = $f->[5];
    $info->{$file}{LastUpdated}  = sprintf "%7.2f mins", int($f->[7])/$min2ms;
    $info->{$file}{MoverID}      = $f->[0];
    $info->{$file}{PnfsId}       = $f->[2];
    my $pool = $f->[3];
    my $str = $pool." [".$pool2dir->{$pool}[0].":".$pool2dir->{$pool}[1]."/pool/data]";
    $info->{$file}{Pool}         = $str;
    $info->{$file}{RemoteHost}   = $f->[8];
    $info->{$file}{LocalHost}    = $f->[9];
  }

  eval {
    store($storedinfo, $INFO);
  };
  print "Error writing to file: $@" if $@;

  $info;
}

sub writeData($$) {
  my ($writer, $href) = @_;
  foreach my $k (sort keys %$href) 
  {
    $writer->startTag($k);
    $writer->characters((defined $href->{$k}) ? $href->{$k} : '?');
    $writer->endTag;
  }
}

sub match {
  my ($file, $info) = @_;
  for my $f (sort keys %$info) 
  {
    next if ($f eq '?');  # safety measure
    print $f, " ", $file->{destSURL}, "\n" if DEBUG;
    return $info->{$f} if ($file->{destSURL} =~ m#$f#);
  }
  return {};
}
sub _main {
  getOptions;

  # Get a handle to the transfer
  my $transfer = new GLite::Data::FileTransfer($endpoint);
  die "Null Transfer object" if not defined $transfer;

  my $jobs = $transfer->listRequests(\@states, $channel);

  # Open the output XML file
  my $xmlout = new IO::File(">$xmlfile");
  die "Cannot open $xmlfile, $!" if not defined $xmlout;

  # Create a XML writer object
  my $writer = new XML::Writer(OUTPUT => $xmlout, 
                            DATA_MODE => 'true', 
                          DATA_INDENT => 2);

  my $storageinfo = getStorageInfo();

  $writer->xmlDecl('UTF-8');
  $writer->startTag("JobList");
  for my $job (@$jobs) 
  {
    my $requestID = $job->{jobID};
    my $status  = $transfer->getTransferJobStatus($requestID);  # Job
    my $fstatus = $transfer->getFileStatus($requestID, 0, 100); # Individual Files
    $status->{channelName} = 'Unknown' if not defined $status->{channelName};
    $writer->startTag("JobStatus", id => $requestID, 
                              channel => $status->{channelName}, 
                               status => $status->{jobStatus});
    writeData($writer, $status);
    $writer->startTag("FileStatus");
    my $index = 0;
    for my $file (@$fstatus) 
    {
      $writer->startTag("File", index => $index++, 
                                 name => basename($file->{destSURL}),
                               status => $file->{transferFileState}
                       );
      writeData($writer, $file);

      # Now add storage information another level deep
      $writer->startTag("StorageInfo");
      writeData($writer, match($file, $storageinfo));
      $writer->endTag;

      $writer->endTag;
    }
    $writer->endTag;
    $writer->endTag;
  }
  $writer->startTag('LastUpdate');
  $writer->characters(getTime(time));
  $writer->endTag;

  $writer->endTag;
  $writer->end;

  # Close the XML file
  $xmlout->close;
}

_main;

__END__
