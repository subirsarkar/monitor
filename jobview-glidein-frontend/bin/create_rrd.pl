#!/usr/bin/env perl
package main;

use strict;
use warnings;

use ConfigReader;
use RRDsys;

sub main
{
  # done only once
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $file = qq|$config->{rrd}{db}|;
  my $rrd = RRDsys->new({ file => $file });
  $rrd->create(['totalCPU', 
                'freeCPU', 
                'totalJobs', 
                'runningJobs', 
                'pendingJobs', 
                'heldJobs', 
                'cpuEfficiency', 
                'leffJobs', 
                'nUsers']);
}

# Execute
main;
__END__
