package RunInfo;

use vars qw/$XMLDIR $CASTORDIR $CASTORDIR_RAW $CASTORDIR_EDM $web_site/;

use strict;
use warnings;

use Data::Dumper;
use IO::File;
use File::Copy;
use Storable;

use lib qw(/home/cmstac/lib/perl5 /home/cmstac/monitor/bin);
use XML::Writer;
use Util qw(_trim _debug getTime);
use WebPage qw(getURL);

sub getLocalRawFileInfo($);
sub getLocalEdmFileInfo($);
sub getCastorRawFileInfo($);
sub getCastorEdmFileInfo($);
sub getDBSInfo($$);
sub getRunSummaryInfo($);
sub writeData($$);
sub writeData2($$$);
sub writeData3($$$);
sub saveXML($);
sub existsXML($);

use constant DEBUG => 0;
$XMLDIR = qq[/home/cmstac/monitor/data];
$CASTORDIR = qq[/castor/cern.ch/cms];
$CASTORDIR_RAW = $CASTORDIR.qq[/testbeam/TAC];
$CASTORDIR_EDM = $CASTORDIR.qq[/store/TAC];
$web_site = qq[http://cmsmon.cern.ch/cmsdb/servlet/RunSummaryTIF];

sub new
{
  my ($pkg, $run, $disk, $det) = @_;
  my $mapFile = qq[/$disk/EDMProcessed/$det/fileMap.txt];

  # Open the output XML file
  my $xmlfile = $XMLDIR.qq[/run_].$run.qq[.xml];
  my $tmpfile = $XMLDIR.qq[/run_].$run.qq[.xml.tmp];
  my $xmlout = new IO::File(">$tmpfile");
  die "Cannot open $tmpfile, $!" if not defined $xmlout;

  # Create a XML writer object
  my $writer = new XML::Writer(OUTPUT => $xmlout,
                            DATA_MODE => 'true',
                          DATA_INDENT => 2);
  $writer->xmlDecl('iso-8859-1');
  $writer->startTag('RunInfo');
  my $self = {
       run => $run,
      disk => $disk,
       det => $det,
   fileMap => $mapFile,
   tmpfile => $tmpfile,
   xmlfile => $xmlfile,
        fh => $xmlout,
    writer => $writer
  };
  bless $self, $pkg;
}

sub getRunSummaryInfo($)
{
  my $self = shift;

  my $run = $self->{run};  
  my $content = WebPage::getURL($web_site, {RUN => $run, TEXT => 1, DB => 'cms_pvss_tk'});
  my @lines = split /\n/, $content;
  return if scalar(@lines) != 2;

  my @tags   = split /\t/, $lines[0];
  my @values = split /\t/, $lines[1];
  return if scalar(@tags) != scalar(@values);

  my $dict = {};
  for (0..$#tags-1) {
    $dict->{$tags[$_]} = $values[$_];
  }
  # Now add info to the xml file
  my $writer = $self->{writer};
  $writer->startTag("RunSummary");
  $self->writeData($dict);
  $writer->endTag;
}

sub getLocalRawFileInfo($)
{
  my $self = shift;
  my $run = $self->{run};
  my $mapFile = $self->{fileMap};

  # Set here the type of run from the directory name
  my $command = qq[cat $mapFile | grep $run | awk '{print \$2}'];
  my $aref = Util::getCommandOutput($command);

  # Now add info to the xml file
  $self->writeData2("RawFiles", $aref);
}

sub getLocalEdmFileInfo($)
{
  my $self = shift;
  my $run = $self->{run};
  my $mapFile = $self->{fileMap};

  # Set here the type of run from the directory name
  my $command = qq[cat $mapFile | grep $run | awk '{print \$1}'];
  my $aref = Util::getCommandOutput($command);

  # Now add info to the xml file
  $self->writeData2("EdmFiles", $aref);
}

sub getCastorRawFileInfo($)
{
  my $self = shift;
  my $run = $self->{run};
  my $disk = $self->{disk};
  my $mapFile = $self->{fileMap};

  # Set here the type of run from the directory name
  my $command = qq[cat $mapFile | grep $run | awk '{print \$2}' |];
  $command .= qq[ sed -e s#/$disk## | awk -v var=$CASTORDIR_RAW '{print var\$1}'];
  my $aref = Util::getCommandOutput($command);

  $command = qq[nsls -l ].join(" ", @$aref);
  $aref = Util::getCommandOutput($command);

  # Now add info to the xml file
  $self->writeData2("CastorRawFiles", $aref);
}

sub getCastorEdmFileInfo($)
{
  my $self = shift;
  my $run = $self->{run};
  my $disk = $self->{disk};
  my $mapFile = $self->{fileMap};

  # Set here the type of run from the directory name
  my $command = qq[cat $mapFile | grep $run | awk '{print \$1}' |];
  $command .= qq[ sed -e s#/$disk/EDMProcessed## | awk -v var=$CASTORDIR_EDM '{print var\$1}'];
  my $aref = Util::getCommandOutput($command);

  $command = qq[nsls -l ].join(" ", @$aref);
  $aref = Util::getCommandOutput($command);

  # Now add info to the xml file
  $self->writeData2("CastorEdmFiles", $aref);
}

sub getDBSInfo($$)
{
  my ($self,$tag) = @_;

  my $run = $self->{run};
  my $command = sprintf "%s %d %s", qq[/home/cmstac/monitor/bin/checkDBSDLS.sh], $run, uc($tag);
  my $aref = Util::getCommandOutput($command);

  # Now add info to the xml file
  $self->writeData3(qq[DBS].$tag, $aref);
}

sub writeData($$) 
{
  my ($self, $href) = @_;
  my $writer = $self->{writer};
  foreach my $k (sort keys %$href)
  {
    $writer->startTag($k);
    $writer->characters((defined $href->{$k}) ? $href->{$k} : '?');
    $writer->endTag;
  }
}

sub writeData2($$$) 
{
  my ($self, $tag, $aref) = @_;
  my $writer = $self->{writer};

  $writer->startTag($tag);
  for my $l (@$aref) {
    $writer->startTag('file');
    $writer->characters($l);
    $writer->endTag;
  }
  $writer->endTag;
}

sub writeData3($$$) 
{
  my ($self, $tag, $aref) = @_;
  my $writer = $self->{writer};

  my $text = join ("\n", @$aref);
  $writer->startTag($tag);
  $writer->characters($text);
  $writer->endTag;
}

sub saveXML($) 
{
  my $self = shift;
  $self->getRunSummaryInfo;
  $self->getLocalRawFileInfo;
  $self->getCastorRawFileInfo;
  $self->getLocalEdmFileInfo;
  $self->getCastorEdmFileInfo;
  $self->getDBSInfo("Raw");
  $self->getDBSInfo("Reco");
}

sub existsXML($)
{
  my $run = shift;
  my $xmlfile = $XMLDIR.qq[/run_].$run.qq[.xml];
  print $xmlfile, "\n" if DEBUG;
  return 1 if -e $xmlfile;

  return 0;
}

sub DESTROY 
{
  my $self = shift;
  my $writer = $self->{writer};
  my $fh     = $self->{fh};

  $writer->endTag;
  $writer->end;

  # Close the XML file
  $fh->close;

  my $tmpfile = $self->{tmpfile};
  my $xmlfile = $self->{xmlfile};

  # Atomic step
  copy($tmpfile, $xmlfile) or  
        warn "Couldn't copy $tmpfile to $xmlfile: $!\n";
  unlink($tmpfile);
}

1;
__END__

package main;

my  $run  = shift || 7296;
my $disk = shift || 'data3';
my  $det = shift || 'TIBTOB';
my $obj = new RunInfo($run, $disk, $det);
$obj->saveXML;
