package RunLocation;

use vars qw/$XMLDIR/;

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Copy;

use lib qw(/home/cmstac/lib/perl5 /home/cmstac/monitor/bin);
use XML::Writer;
use Util qw(_trim);
use WebPage qw(getURL);

sub createMap($$);
use constant DEBUG => 0;

$XMLDIR = qq[/home/cmstac/monitor/data];
sub new
{
  my ($pkg,$nrun) = @_;

  # Open the output XML file
  my $xmlfile = $XMLDIR.qq[/runMap.xml];
  my $tmpfile = $XMLDIR.qq[/runMap.xml.tmp];
  my $xmlout = new IO::File(">$tmpfile");
  die "Cannot open $tmpfile, $!" if not defined $xmlout;

  # Create a XML writer object
  my $writer = new XML::Writer(OUTPUT => $xmlout,
                            DATA_MODE => 'true',
                          DATA_INDENT => 2);
  $writer->xmlDecl('iso-8859-1');
  $writer->startTag('RunMap');
  my $self = {
     nrun  => $nrun,
       fh  => $xmlout,
   tmpfile => $tmpfile,
   xmlfile => $xmlfile,
    writer => $writer
  };
  bless $self, $pkg;
}

sub createMap($$)
{
  my ($self, $files) = @_;

  my $dict = {};
  for my $file (@$files) {
    next if !-e $file;
    open INPUT, "<$file" or die qq[Cannot open $file, $!];
    while (<INPUT>) {
      chomp;
      my $file = (split)[0];
      my ($disk, $det, $base) = (split m#\/#, $file)[1,3,-1];
      print join (" ", $disk, $det, $base), "\n" if DEBUG; 
      my $runPart = (split /_/, $base)[0];
      my $run = -1;
      if ($runPart =~ /EDM(\d+)/) {
        $run = $1;
      }
      elsif ($runPart =~ /tif\.(\d+)\.A.testStorageManager/) {
        $run = $1;
      }
      next if ($run < 1400 || $run > 9999); # Note the hardcode LIMIT
      $dict->{sprintf("%d",$run)} = [$disk, $det] if not exists $dict->{$run};
    }
    close INPUT;
  } 
  # Check the latest run from RunSummary
  my $site = qq[http://cmsmon.cern.ch/cmsdb/servlet/LatestRun];
  my $lrun = WebPage::getURL($site, {USERPREFIX => 'trackertif'});

  print "lrun=$lrun\n" if DEBUG;
  my @runList = sort {$b <=> $a} keys %$dict;
  if ($lrun ne '' and int($lrun) > $runList[0]) { 
    $dict->{sprintf("%d",$lrun)} = ['?', '?'];
    unshift @runList, $lrun;
  }

  # Now add data to the xml file
  my $writer = $self->{writer};
  my $nrun = $self->{nrun};
  @runList = @runList[0..$nrun-1] if $nrun > -1;
  for my $run (@runList) {
    my $disk = $dict->{$run}[0];
    my $det  = $dict->{$run}[1];
    next if ($disk eq '?' && $det eq '?');
    $writer->startTag("Run", value => $run,
                              disk => $disk,
                               det => $det);
    $writer->endTag;
  }
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
