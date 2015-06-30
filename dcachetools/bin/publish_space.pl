#!/usr/bin/env perl
package main;

use strict;
use warnings;
use IO::File;
use Getopt::Long;
use POSIX qw/strftime ctime gmtime/;
use XML::Writer;
use MIME::Lite;

use BaseTools::Util qw/readFile/;
use BaseTools::ConfigReader;
use dCacheTools::Space;
use dCacheTools::PoolManager;
use dCacheTools::Info::PoolGroup;

use constant MB2BY => 1.0*1024**2;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $site    = undef;
our @volist  = ();
our $se      = undef;
our $xmlfile = q|vospace.xml|;
our $webserver = undef;

sub usage
{
  print <<HEAD;
Gather VO Space usage in an XML file

The command line options are

-v|--verbose    display debug information                           (D=false)
-h|--help       show help on this tool and quit                     (D=false)
--site          Site name                                           (D=config)
--se            Fully specified name of the storage element         (D=config)
--xmlfile       Output XML file                                     (D=vospace.xml)
--webserver     dCache webserver, same as the se unless specified   (D=$se)
--vo            List of VOs to account for (--vo=vo1 --vo=vo2 etc.) (D=qw/cms/)

Example usage:
perl -w $0 --site=INFN-PISA --se=cmsdcache.pi.infn.it --vo=cms --vo=atlas
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions    'verbose+' => \$verbose,
                    'help' => \&usage,
                  'site=s' => \$site,
                    'se=s' => \$se,
                    'vo=s' => \@volist,
               'xmlfile=s' => \$xmlfile,
             'webserver=s' => \$webserver;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $admin_node = $config->{admin}{node};
  defined $se or $se = $admin_node;
  defined $site or $site = $config->{site};
  defined $webserver or $webserver = $se;
}

sub writeData
{
  my ($writer, $href) = @_;
  for my $k (sort keys %$href) {
    $writer->startTag($k);
    $writer->characters((defined $href->{$k}) ? $href->{$k} : '?');
    $writer->endTag;
  }
}
sub createXML
{
  # We do not need the detailed info
  my $pm = dCacheTools::PoolManager->instance({ parse_all => 0 });
  my @pgrouplist = $pm->pgrouplist;  

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->config;
  my $has_info_service = $config->{has_info_service} || 0;

  # Open the output XML file
  my $xmlout = IO::File->new($xmlfile, 'w');
  die qq|Failed to open $xmlfile, $!, stopped| unless defined $xmlout;
  
  # Create a XML writer object
  my $writer = XML::Writer->new(OUTPUT => $xmlout, 
                             DATA_MODE => 1,
                           DATA_INDENT => 2);
  $writer->xmlDecl('','yes');
  
  $writer->startTag(q|site|, name => $site);
  my $now = time;
  $writer->startTag(q|SE|, name => $se, timestamp => $now);
  my ($g_total, $g_free) = (0,0);
  for my $vo (@pgrouplist) {
    my $info = {};
    if ($has_info_service) {
      my $pg = dCacheTools::Info::PoolGroup->new({ webserver => $webserver, name => $vo });
      $info->{total} = $pg->total;
      $info->{free}  = $pg->free;
    }
    else {
      my $obj = dCacheTools::Space->new({ webserver => $webserver, pgroup => $vo });
      my $usage = $obj->getUsage;
      $info->{total} = $usage->{total} * MB2BY; # web numbers are in MB
      $info->{free}  = $usage->{free} * MB2BY;
    }
    $info->{used} = $info->{total} - $info->{free};
    $g_total += $info->{total};
    $g_free  += $info->{free};

    next if scalar @volist and grep { !/$vo/ } @volist; 
    $writer->startTag(q|VO|, name => $vo);
    $writer->startTag(q|class|, name => q|total|);
    writeData($writer, {used => $info->{used}, free => $info->{free}});
    $writer->endTag; # class
    $writer->endTag; # VO
  }
  writeData($writer, {free => $g_free, size => $g_total});
  # close the SE
  $writer->endTag;
  
  chop(my $t = `date`);
  writeData($writer, {date => $t});  
  # close the site tag
  $writer->endTag;
  
  # close the writer and the filehandle
  $writer->end;
  $xmlout->close;
}
sub sendXML
{
  my $ecode = 0;
  chop(my $data = readFile($xmlfile, \$ecode));
  warn qq|Failed to read $xmlfile\n| and return if $ecode;

  my $subject = qq|$site |. time();
 
  my $msg = MIME::Lite->new(
                    From => 'subir.sarkar@pi.infn.it',
                      To => 'grid-services@pi.infn.it,subir.sarkar@cern.ch',
                 Subject => $subject,
                    Data => $data
            );
  MIME::Lite->send(q|smtp|, q|smtp.pi.infn.it|, Timeout=>120, Debug=>0);
  $msg->send;
}
sub main
{
  readOptions;

  createXML;

  my $hour = (localtime(time()))[2];
  return if $hour%12;

  sendXML;
}
main;
__END__
<date>Thu Feb 12 02:25:01 CET 2009</date>
