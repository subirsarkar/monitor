#!/usr/bin/env perl
package main;

use strict;
use warnings;

use ConfigReader;
use RRDsys qw/create_rrd/;

sub main
{
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $rrdH = RRDsys->new;

  # Global RRD 
  my $file = $config->{rrd}{db} || q|filen.rrd|;
  create_rrd($rrdH, {filename => $file, global => 1}) unless -r $rrdH->filepath($file);

  # Group RRDs
  my $groupList = $config->{rrd}{groupList} || [];
  for my $group (@$groupList) {
    my $file = qq|$group.rrd|;
    create_rrd($rrdH, {filename => $file, global => 0}) unless -r $rrdH->filepath($file);
  }

  # CE RRDs
  my $ceList = $config->{rrd}{ceList} || [];
  for my $ce (@$ceList) {
    my $file = qq|$ce.rrd|;
    create_rrd($rrdH, {filename => $file, global => 0}) unless -r $rrdH->filepath($file);
  }
}

# Execute
main;
__END__
