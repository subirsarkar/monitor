#!/usr/bin/env perl
package main;

use strict;
use warnings;

use LSF::ConfigReader;
use LSF::RRDsys;

# done only once
sub main
{
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $enableCPUEff = $config->{rrd}{enableCPUEff} || 0;
  my $location = $config->{rrd}{location};
  my $groupList = $config->{rrd}{supportedGroups} || [];

  my $list = ['runningJobs', 'pendingJobs'];
  push @$list, 'cpuEfficiency' if $enableCPUEff;

  for my $group (@$groupList) {
    my $file = qq|$location/$group.rrd|;
    -r $file and next;
    my $rrd = LSF::RRDsys->new({ file => qq|$group.rrd| });
    $rrd->create($list);
  }
}

# Execute
main;
__END__
