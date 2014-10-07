#!/usr/bin/env perl
package main;

use strict;
use warnings;

use Collector::ConfigReader;
use Collector::RRDsys;

sub main
{
  # done only once
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $file = qq|$config->{rrd}{db}|;
  my $rrd = new Collector::RRDsys({ file => $file });
  $rrd->create(['totalCPU', 'freeCPU', 'runningJobs', 'pendingJobs', 'cpuEfficiency']);
}

# Execute
main;
__END__
