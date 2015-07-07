#!/usr/bin/env perl

package main;

# Declaration of globals
use vars qw/$verbose $force $help $age $xmlfile $nrun_max $skip_n @detlist/;
use vars qw/$XMLDIR $XMLIN/;

use strict;
use warnings;
use Getopt::Long;
use Storable;

use lib qw(/home/cmstac/lib/perl5 /home/cmstac/monitor/bin);
use XML::XPath;
use XML::XPath::XMLParser;
use RunInfo;

use constant DEBUG => 0;
$XML::XPath::SafeMode = 1;  # Enable
$XMLDIR = qq[/home/cmstac/monitor/data];

sub getOptions;
sub usage;
sub createXML;
sub main;

# Command line options with Getopt::Long
$verbose  = '';
$help     = '';
$age      = 30;
$force    = '';
$xmlfile  = $XMLDIR.qq[/runMap.xml];
$nrun_max = 10E5;
$skip_n   = -1;
@detlist  = ();

sub usage () 
{
  print <<HEAD;
  Creates XML files for TAC monitoring

  The command line options are

  --verbose (D=noverbose)
  --help    Show help on this tool and quit (D=nohelp)
  --age     File older than age should be recreated (D=30)
  --force   Force creation of the xml file
  --xml     Specify the input XML file
  --nrun    Process only the first n runs and exit, generally used with --force (D=-1 or none)
  --skip    Skip the first n runs and process the rest(D=0)
  --detlist Process only a subset of detectors

  Example usage:
  perl -w createRunInfo.pl --force --nrun=10

Subir Sarkar
13/04/2007 09:15 hrs
HEAD

exit 0;
}

sub getOptions 
{
  # Extract command line options
  GetOptions 'verbose!'  => \$verbose,
             'help!'     => \&usage,
             'age=i'     => \$age,
             'force!'    => \$force,
             'xml=s'     => \$xmlfile,
             'nrun=i'    => \$nrun_max,
             'skip=i'    => \$skip_n,
             'detlist=s' => \@detlist;

  @detlist = join (',', @detlist) if scalar(@detlist)>1;
  @detlist = split /,/, join(',', @detlist);
  print join("\n", @detlist), "\n" if DEBUG;
}
sub createXML
{
  my $xp;
  eval
  {
    $xp = new XML::XPath(filename => $xmlfile);
  };
  die qq[Error creating XML::XPath object: $@] if ($@);

  my $nodeset = $xp->find(
    qq{/RunMap/Run/\@value}
  );
  my $irun = 0;
  for my $node ($nodeset->get_nodelist)
  {
    # Decide if this run needes to be processed
    $irun++;
    next if $irun < $skip_n;   
    last if $irun > $nrun_max;

    my $run = $node->string_value;
    next if (!$force && RunInfo::existsXML($run));

    # go ahead
    my $disk = $xp->findvalue(
      qq{/RunMap/Run[\@value="$run"]/\@disk}
    );
    my $det = $xp->findvalue(
      qq{/RunMap/Run[\@value="$run"]/\@det}
    );
    next if ($disk eq '?' or $det eq '?');
    next if (scalar(@detlist)>0 && !grep(/$det/, @detlist));

    print "Processing run ", join(":", $run, $disk, $det), "\n";
    my $obj = new RunInfo($run, $disk, $det);
    $obj->saveXML;
  }
  $xp->cleanup;
}

sub main
{
  getOptions;
  createXML;  
}

main;
