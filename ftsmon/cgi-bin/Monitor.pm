package Monitor;

use strict;
use warnings;

use File::Basename;
use Storable;

use XML::Writer;
use XML::XPath;
use XML::XPath::XMLParser;
use Util;

our $XMLIN = '/var/www/html/ftsmon/test.xml';
our $INFO  = '/var/www/html/ftsmon/info.dat';
$XML::XPath::SafeMode = 1;  # Enable

sub new 
{
  my $pkg = shift;
  my $xp;
  eval {
    $xp = new XML::XPath(filename => $XMLIN);
  };
  if ($@) {
    print STDERR "Error creating XML::XPath object: $@";
    undef $xp;
  }

  # Create a XML writer object
  my $writer;
  eval {
    $writer = new XML::Writer(DATA_MODE   => 'true',
                              DATA_INDENT => 2);
  };
  if ($@) {
    print STDERR "Error creating XML::Writer object: $@";
    undef $writer;
  }

  my $self = 
  {
    xpath   => $xp,
    writer  => $writer
  };
  bless $self, $pkg;
}

sub valid 
{
  my $self = shift;
  return 0 if (!defined $self->{xpath} || !defined $self->{writer});
  return 1;
}

sub getChannelList 
{
  my ($self, $state_aref) = @_;
  my $xp = $self->{xpath};

  my $h = {};
  for my $state (@$state_aref) {
    my $nodeset = $xp->find(
      qq|/JobList/JobStatus[\@status="$state"]/channelName|
    );
    foreach my $node ($nodeset->get_nodelist) {
      $h->{$node->string_value}++;
    }
  }
  $h;
}

sub sendChannelList 
{
  my ($self, $q, $state_aref) = @_;
  print $q->header(-type => "text/xml", -expires => "-1d");
  $self->writeData($self->getChannelList($state_aref), 'channels', 'channel');
  $self->endDocument;
}

sub sendTimestamp 
{
  my ($self, $q) = @_;
  my $xp = $self->{xpath};
  print $q->header( -type => "text/plain", -expires => "-1d" );

  my $st = $xp->findvalue(qq{/JobList/LastUpdate});
  $st = '?' if not defined $st; 
  print $st;
}

sub getJobList 
{
  my ($self, $state_aref, $channel) = @_;
  my $xp = $self->{xpath};

  my $h = {};
  for my $state (@$state_aref) {
    my $nodeset = $xp->find(
      qq{/JobList/JobStatus[\@channel="$channel"][\@status="$state"]/jobID}
    );
    foreach my $node ($nodeset->get_nodelist) {
      $h->{$node->string_value}++;
    }
  }
  $h;
}

sub sendJobList 
{
  my ($self, $q, $state_aref, $channel) = @_;
  print $q->header( -type => "text/xml", -expires => "-1d" );
  $self->writeData($self->getJobList($state_aref, $channel), 'jobs', 'job');
  $self->endDocument;
}

sub sendFileList 
{
  my ($self, $q, $requestID) = @_;
  my ($xp, $writer) = ($self->{xpath}, $self->{writer});

  my @tags = (
    'channelName',
    'clientDN',
    'jobStatus',
    'numFiles',
    'priority',
    'submitTime',
    'voName'
  );
  print $q->header( -type => "text/xml", -expires => "-1d" );
  $writer->startTag('doc');

  # List of Files; add file status also for easy navigation
  my $fileList = {};
  my $nodeset = $xp->find(
    qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File/destSURL}
  );
  foreach my $node ($nodeset->get_nodelist) {
    my $name = basename($node->string_value);
    my $value = $xp->findvalue(
      qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File[\@name="$name"]/transferFileState}
    );
    $name .= " [".$value."]";
    $fileList->{$name}++;
  }
  $self->writeData($fileList, 'files', 'file');

  # Job Status
  my $jobStatus = {};
  $nodeset = $xp->find(
    qq{/JobList/JobStatus[\@id="$requestID"]}
  );
  foreach my $node ($nodeset->get_nodelist) {
    for my $child ($node->getChildNodes) {
      my $name = $child->getLocalName;
      next unless defined $name;
      $jobStatus->{$name} = $child->string_value if (grep /$name/, @tags);
    }
  }
  # Add source (srm) server name 
  if (exists $jobStatus->{channelName}) {
    my $cname = $jobStatus->{channelName};
    my $tmp = $xp->findvalue(
      qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File[\@index="0"]/sourceSURL}
    );
    my $host = '?';
    if (defined $tmp) {
      $tmp =~ m#^srm://(.*):8443(?:.*)#;
      $host = $1;
    }
    $cname .= " [".$host."]";
    $jobStatus->{channelName} = $cname;
  }
  if (exists $jobStatus->{submitTime}) {
    my $time = $jobStatus->{submitTime};
    $time = substr($time, 0, length($time)-3);
    $jobStatus->{submitTime} = Util::getTime($time);
  }

  # Find [Active,Pending,Failed] entries
  if (exists $jobStatus->{jobStatus}) {
    my $href = {};
    $nodeset = $xp->find(
      qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File/transferFileState}
    );
    foreach my $node ($nodeset->get_nodelist) {
      my $name = $node->string_value;
      $href->{$name}++;
    }
    my $value = $jobStatus->{jobStatus}.' [';
    for my $key (sort keys %$href) {
      $value .= $key.' = '.$href->{$key}.', ';
    }
    $value = substr($value,0,length($value)-2);
    $value .= ']';
    $jobStatus->{jobStatus} = $value;
  }  

  $self->writeData2($jobStatus, 'status');

  $writer->endTag;
  $self->endDocument;
}

sub getStorageInfo 
{
  my ($self, $requestID, $filename) = @_;
  my $xp = $self->{xpath};

  my $nodeset = $xp->find(
    qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File[\@name="$filename"]/StorageInfo}
  );
  Monitor->getNodeInfo($nodeset);
}
sub getFTSInfo 
{
  my ($self, $requestID, $filename) = @_;
  my $xp = $self->{xpath};

  my $nodeset = $xp->find(
    qq{/JobList/JobStatus[\@id="$requestID"]/FileStatus/File[\@name="$filename"]}
  );
  my $h = Monitor->getNodeInfo($nodeset);
  delete $h->{StorageInfo} if exists $h->{StorageInfo};
  $h;
}
sub getFileStatus 
{
  my ($self, $requestID, $filename) = @_;
  my $h    = $self->getFTSInfo($requestID, $filename);
  my $newh = $self->getStorageInfo($requestID, $filename);
  if (! %$newh) {
    # At this point load the storedinfo
    eval {
      my $storedinfo = retrieve($INFO) if -e $INFO;
      my $destSURL = $h->{destSURL};
      my $tag = (split m#/pnfs/pi\.infn\.it/data/cms#, $destSURL)[-1];
      $newh = $storedinfo->{$tag};
    };
    print STDERR "Error reading from file: $@" if $@;
  }
  Monitor->appendInfo($h, $newh);
  $h;
}
sub sendFileStatus 
{
  my ($self, $q, $requestID, $filename) = @_;
  print $q->header( -type => "text/xml", -expires => "-1d" );
  $self->writeData2($self->getFileStatus($requestID, $filename), 'doc');
  $self->endDocument;
}

sub getAllFileList 
{
  my ($self, $state_aref) = @_;
  my $xp = $self->{xpath};  

  # List of Files; add file status also for easy navigation
  my $fileList = {};

  # Mind that the states should be all to get the channel/Job list and not $state_aref
  # as passed from by the caller
  my $valid_states = ['Submitted','Active','Pending'];
  my $channelList = $self->getChannelList($valid_states);

  for my $channel (sort keys %$channelList) {
    my $jobList = $self->getJobList($valid_states, $channel);
    for my $jid (sort keys %$jobList) {
      for my $state (@$state_aref) {
        my $nodeset = $xp->find(
          qq{/JobList/JobStatus[\@id="$jid"]/FileStatus/File[\@status="$state"]/destSURL}
        );
        foreach my $node ($nodeset->get_nodelist) {
          my $name = basename($node->string_value);
          $name .= " [".$jid.":".$channel."]";
          $fileList->{$name}++;
        }
      }
    }
  }
  $fileList;
}

sub sendAllFileList 
{
  my ($self, $q, $state_aref) = @_;
  print $q->header( -type => "text/xml", -expires => "-1d" );
  $self->writeData($self->getAllFileList($state_aref), 'files', 'file');
  $self->endDocument;
}

sub getNodeInfo
{
  my ($pkg, $nodeset) = @_;
  my $h = {};
  foreach my $node ($nodeset->get_nodelist) {
    for my $child ($node->getChildNodes) {
      my $name = $child->getLocalName;
      next unless defined ($name);
      $h->{$name} = $child->string_value;
    }
  }
  $h;
}

sub appendInfo 
{
  my ($pkg, $h, $oh) = @_;
  foreach my $k (keys %$oh) {
    $h->{$k} = $oh->{$k};
  }
}
sub writeData 
{
  my ($self, $href, $tago, $tagi) = @_;
  my $writer = $self->{writer};

  $writer->startTag($tago); 
  foreach my $k (sort keys %$href) {
    $writer->startTag($tagi);
    $writer->characters($k);
    $writer->endTag;
  }
  $writer->endTag;
}

sub writeData2 
{
  my ($self, $href, $tag) = @_;
  my $writer = $self->{writer};

  $writer->startTag($tag); 
  foreach my $k (sort keys %$href) {
    $writer->startTag($k);
    $writer->characters($href->{$k});
    $writer->endTag;
  }
  $writer->endTag;
}

sub endDocument 
{
  my $self = shift;
  my $writer = $self->{writer};
  $writer->end;
}

sub DESTROY 
{
  my $self = shift;
  my $xp = $self->{xpath};
  $xp->cleanup;
}

1;

__END__
Alternate way:
$h->{XML::XPath::XMLParser::as_string($node)}++;

sendAllFilesList - <file>name jobid channelname</file>
