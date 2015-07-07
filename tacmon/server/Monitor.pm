package Monitor;

use vars qw/$XMLDIR/;

use strict;
use warnings;

use IO::File;

use lib qw (/home/cmstac/lib/perl5 /home/cmstac/monitor/bin);
use XML::XPath;
use XML::XPath::XMLParser;
use WebPage qw(getURL);

use constant DEBUG => 0;
$XML::XPath::SafeMode = 1;  # Enable
$XMLDIR = qq[/home/cmstac/monitor/data];

sub setRun($$);
sub getRun($);
sub getFileName($);
sub sendDetList($);
sub sendRunList($);
sub sendShiftSummaryInfo($);
sub sendRunSummaryInfo($);
sub sendFileInfo($$);
sub sendDBSInfo($$);
sub sendLocalRawFileInfo($);
sub sendLocalEdmFileInfo($);
sub sendCastorRawFileInfo($);
sub sendCastorEdmFileInfo($);
sub sendDBSRawInfo($);
sub sendDBSRecoInfo($);
sub sendLastUpdateTime($);

# static
sub getParser($);
sub getRunListFromRS;
sub getDetList;
sub getRunList($);
sub getTime ($);

sub new 
{
  my ($pkg, $cgi) = @_;
  my $self = {cgi => $cgi};
  bless $self, $pkg;
}

sub setRun($$)
{
  my ($self,$run) = @_;
  $self->{run} = $run;
}

sub getRun($)
{
  my $self = shift;
  $self->{run};
}

sub getFileName($)
{
  my $self = shift;
  my $run = $self->{run};
  $XMLDIR.qq[/run_].$run.qq[.xml];
}

sub getParser($)
{
  my $xmlin = shift;
  my $xp;
  eval
  {
    $xp = new XML::XPath(filename => $xmlin);
  };
  if ($@)
  {
    print STDERR "Error creating XML::XPath object: $@";
    undef $xp;
  }
  $xp;
}

sub getRunListFromRS
{
  my $web_site = qq[http://cmsmon.cern.ch/cmsdb/servlet/RunSummaryTIF];
  my $content = WebPage::getURL($web_site, {'RUN_BEGIN' => 0, 'RUN_END' => 999999, 'TEXT' => 1, 'DB' => 'cms_pvss_tk'});
  my @lines = split /\n/, $content;
  shift(@lines);
  my @runList = ();
  for my $l (@lines) {
     my ($run) = split /\t/, $l;
     push (@runList, $run);
  }
  \@runList;
}


sub getDetList
{
  my $xmlfile = $XMLDIR.qq[/runMap.xml];
  my $xp = Monitor::getParser($xmlfile);
  return [] if not defined $xp; 

  my $nodeset = $xp->find(
    qq{/RunMap/Run/\@det}
  );
  my $href = {};
  for my $node ($nodeset->get_nodelist)
  {
    $href->{$node->string_value}++;
  }
  # Cleanup
  $xp->cleanup;

  my @list = sort keys %$href;
  unshift @list, qq[All Detectors];
  \@list;
}

sub sendDetList($)
{
  my $self = shift;
  my $cgi = $self->{cgi};
  print $cgi->header( -type => "text/plain", -expires => "-1d" );

  my @detList = @{Monitor::getDetList()};
  my $len = scalar @detList;
  my $n   = 0;
  my $response = "{\n\"dets\":[\n";
  for my $det (@detList) {
    if ($n == $len-1) {
      $response .= "\'$det\'";
    }
    else {
      $response .= "\'$det\', ";
    }
    $response .= "\n" if ($n != 0 && $n%10 == 0);
    $n++;
  }
  $response .= "\n]}\n";
  print STDOUT $response;
  print STDERR $response if DEBUG;
}

sub getRunList($)
{
  my $dtype = shift;
  my $xmlfile = $XMLDIR.qq[/runMap.xml];
  my $xp = Monitor::getParser($xmlfile);
  return [] if not defined $xp; 

  my $query;
  if (lc($dtype) eq 'all') {
    $query = qq{/RunMap/Run/\@value};
  }
  else {
    $query = qq{/RunMap/Run[\@det="$dtype"]/\@value};
  } 
  my $nodeset = $xp->find($query);
  my @list = ();
  for my $node ($nodeset->get_nodelist)
  {
    push @list, $node->string_value;
  }
  # Cleanup
  $xp->cleanup;

  \@list;
}

sub sendRunList($)
{
  my $self = shift;
  my $cgi = $self->{cgi};
  my $dtype = $cgi->param('dtype');
  $dtype = 'all' if not defined $dtype;

  print $cgi->header( -type => "text/plain", -expires => "-1d" );

  my @runList = @{Monitor::getRunList($dtype)};
  my $len = scalar @runList;
  my $n   = 0;
  my $response = "{\n\"runs\":[\n";
  for my $run (@runList) {
    if ($n == $len-1) {
      $response .= "$run";
    }
    else {
      $response .= "$run, ";
    }
    $response .= "\n" if ($n != 0 && $n%10 == 0);
    $n++;
  }
  $response .= "\n]}\n";
  print STDOUT $response;
  print STDERR $response if DEBUG;
}

sub sendShiftSummaryInfo($)
{
  my $self = shift;
  my $cgi = $self->{cgi};
  print STDOUT $cgi->header( -type => "text/plain", -expires => "-1d" );
  print STDOUT join ("\n", ("Hello", "World"));
}

sub sendRunSummaryInfo($)
{
  my $self = shift;
  my $cgi = $self->{cgi};
  print $cgi->header( -type => "text/plain", -expires => "-1d" );
  
  my $xp = Monitor::getParser($self->getFileName());
  return if not defined $xp; 

  my @tagList = qw(
  RUN
  PARTITION
  RUNMODE
  STARTTIME
  STOPTIME
  NEVENTS
  STATENAME
  APVMODE
  FEDMODE
  SUPERMODE
  FECV
  FEDV
  SYSTEM);

  my @list = ();
  for my $tag (@tagList) {
    my $value = $xp->findvalue(qq{/RunInfo/RunSummary/$tag});
    push @list, $value;
  }
  # Cleanup
  $xp->cleanup;

  print STDOUT join ("\t", @list);
}

sub sendFileInfo($$)
{
  my ($self, $tag) = @_;
  my $cgi = $self->{cgi};

  print STDOUT $cgi->header( -type => "text/plain", -expires => "-1d" );
  my $xp = Monitor::getParser($self->getFileName());
  return if not defined $xp; 

  my $nodeset = $xp->find(qq{/RunInfo/$tag/file});
  my @fileList = ();
  for my $node ($nodeset->get_nodelist)
  {
    my $value = $node->string_value;
    $value =~ s/\s+/ /g;
    push @fileList, $value if length($value)>0;
  }
  # Cleanup
  $xp->cleanup;

  my $response = "{\n\"files\":[\n";
  for my $file (@fileList) {
    $response .= ",\'$file\'";
  }
  $response =~ s/,//;
  $response .= "\n]}\n";
  print STDOUT $response;
  print STDERR $response if DEBUG;
}

sub sendDBSInfo($$)
{
  my ($self, $tag) = @_;
  my $cgi = $self->{cgi};

  print STDOUT $cgi->header( -type => "text/plain", -expires => "-1d" );
  my $xp = Monitor::getParser($self->getFileName());
  return if not defined $xp; 

  my $nodeset = $xp->find(qq{/RunInfo/$tag});
  my @list = ();
  for my $node ($nodeset->get_nodelist)
  {
    push @list, $node->string_value;
  }
  # Cleanup
  $xp->cleanup;

  print STDOUT join ("\n", @list);
}

sub sendLocalRawFileInfo($)
{
  my $self = shift;
  $self->sendFileInfo("RawFiles");
}

sub sendLocalEdmFileInfo($)
{
  my $self = shift;
  $self->sendFileInfo("EdmFiles");
}

sub sendCastorRawFileInfo($)
{
  my $self = shift;
  $self->sendFileInfo("CastorRawFiles");
}

sub sendCastorEdmFileInfo($)
{
  my $self = shift;
  $self->sendFileInfo("CastorEdmFiles");
}

sub sendDBSRawInfo($)
{
  my $self = shift;
  $self->sendDBSInfo("DBSRaw");
}

sub sendDBSRecoInfo($)
{
  my $self = shift;
  $self->sendDBSInfo("DBSReco");
}

sub sendLastUpdateTime($) 
{
  my $self = shift;
  my $xmlfile = $self->getFileName();
  my $mtime = (stat $xmlfile)[9];
  my $fmt = Monitor::getTime($mtime);

  my $cgi = $self->{cgi};
  print STDOUT $cgi->header( -type => "text/plain", -expires => "-1d" );
  print STDOUT $fmt;
  print STDERR $fmt if DEBUG;
}

sub getTime ($)
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

1;
__END__
