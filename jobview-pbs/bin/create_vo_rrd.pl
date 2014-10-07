#!/usr/bin/env perl
package main;

use strict;
use warnings;

use Collector::ConfigReader;
use Collector::RRDsys;

# done only once
sub main
{
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $voList = $config->{rrd}{supportedGroups};

  for my $vo (@$voList) {
    my $rrd = new Collector::RRDsys({ file => qq|$vo.rrd| });
    $rrd->create(['runningJobs', 'pendingJobs', 'cpuEfficiency']);
  }
}

# Execute
main;
__END__
