#!/usr/bin/env perl
use strict;
use warnings;
use JSON;

use ConfigReader;
use AvailableServers;
use CompStatusParser;
use RRDsys;

my $jsonfile = q|server.json|;
sub create_rrd
{
  my $rrdH = shift;
  my $list = [
              'created', 
              'not_handled', 
              'handled', 
              'failed', 
              'output_requested',
              'in_progress'
  ];
  $rrdH->create($list);
}
sub createJSON
{
  my $list = shift;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $location = $config->{rrd}{location};

  my $jsval;
  eval {
    my $json = JSON->new(pretty => 1, delimiter => 1, skipinvalid => 1);
    $jsval = ($json->can('encode'))
	? $json->encode({ 'items' => $list })
	: $json->objToJson({ 'items' => $list });
  };
  print STDERR qq|JSON Problem likely!!, $@\n| and return if $@;

  my $file = qq|$location/$jsonfile|;
  open OUTPUT, qq|>$file| or die qq|Failed to open output file $file|;
  print OUTPUT $jsval;
  close OUTPUT;
}
sub main
{
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  
  my $timestamp = time;
  my $rrdH = RRDsys->new({ file => 'dummy.db' });
  my $parser = CompStatusParser->new;
  my $av_servers = AvailableServers->new;
  $av_servers->parse({ url => q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AnalysisOperationsServerList| });

  # prepare the CS list
  my @list = $av_servers->list;
  createJSON(\@list);

  for my $server (@list) {
    # RRD update
    my $path = $rrdH->rrdFile(qq|$server.rrd|);
    warn qq|$path not found, will create now| and create_rrd($rrdH) unless -r $path;
    
    my $webserver = $av_servers->webserver($server);
    my $baseurl = qq|http://$webserver:8888|;
    my $url = $baseurl . qq|/compstatus|;
    print ">>> processing CRAB Server <$server>, URL=<$url>\n";

    $parser->parse({ url => $url, verbose => $verbose });
    $parser->show;
    $rrdH->update([
       $timestamp,
       $parser->created || 0,
       $parser->not_handled || 0,
       $parser->handled || 0,
       $parser->failed || 0,
       $parser->output_requested || 0,
       $parser->in_progress || 0
    ]);
     
    # RRD - graph
    my $attr = 
    {
       fields => ['created', 'not_handled', 'handled', 'failed', 'output_requested','in_progress'],
       colors => ['#0000ff', '#ff8000','#00ff00', '#ff0000','#008080', '#00BBBB'],
      options => ['LINE2', 'LINE2','LINE2', 'LINE2','LINE2', 'LINE2'],
       titles => ['Created', 'Not Handled', 'Handled', 'Failed', 'Output_Requested','In Progress'],
       vlabel => qq|Jobs|,
         gtag => qq|statuswtime_$server|
    };
    $rrdH->graph($attr);
  }
}
main;
__END__
