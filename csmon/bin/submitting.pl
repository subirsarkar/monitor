#!/usr/bin/env perl

use strict;
use warnings;

use ConfigReader;
use AvailableServers;
use UserTaskParser;

sub main
{
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $nd = 7;
  print qq|>>> Tasks registered in the last $nd days and still in <submitting> state\n\n|;
  my $parser = UserTaskParser->new;
  my $av_servers = AvailableServers->new;
  $av_servers->parse({ url => q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AnalysisOperationsServerList| });
  for ($av_servers->list) {
    my $webserver = $av_servers->webserver($_);
    my $baseurl = qq|http://$webserver:8888|;
    my $url = $baseurl . qq|/usertask/?username=All&tasktype=All&length=$nd&span=days|;
    print ">>> CRAB Server <$_>" . (($verbose) ? ", URL=<$url>" : ''). "\n";

    $parser->parse({ url => $url, verbose => $verbose });
    $parser->summary({ baseurl => $baseurl });
  }
}
main;
__END__
