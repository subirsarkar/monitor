#!/usr/bin/env perl
package main;

use strict;
use warnings;

use LSF::ConfigReader;
use LSF::RRDsys;

sub main
{
  # done only once
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $enableCPUEff = $config->{rrd}{enableCPUEff} || 0;

  my $location = $config->{rrd}{location};
  my $file     = $config->{rrd}{db};

  -r qq|$location/$file| and return;
  my $rrd = LSF::RRDsys->new({ file => $file });
  my $list = ['totalCPU','freeCPU','runningJobs','pendingJobs'];
  push @$list, 'cpuEfficiency' if $enableCPUEff;
  $rrd->create($list);
}

# Execute
main;
__END__
