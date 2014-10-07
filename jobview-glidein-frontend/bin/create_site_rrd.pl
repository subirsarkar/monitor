#!/usr/bin/env perl
package main;

use strict;
use warnings;

use ConfigReader;
use RRDsys;
use Data::Dumper;
use Util qw/restoreInfo/;

sub main
{
  # done only once
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $ce2site_file = $config->{db}{ce2site};
  die qq|Problem with $ce2site_file!| unless (defined $ce2site_file and -r $ce2site_file);
  my $info = restoreInfo($ce2site_file);

  for my $site (values %$info) {
    my $file = qq|$config->{baseDir}/db/$site.rrd|;
    my $rrd = RRDsys->new({ file => $file });
    $rrd->create(['totalJobs', 
                  'runningJobs', 
                  'pendingJobs', 
                  'heldJobs', 
                  'cpuEfficiency', 
                  'leffJobs', 
                  'nUsers']);
  } 
}

# Execute
main;
__END__
