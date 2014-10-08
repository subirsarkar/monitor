#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Config;
use File::Basename;
use POSIX qw/strftime/;

use Collector::ConfigReader;
use Collector::NodeSensor;
use Collector::Util qw/daemonize show_message/;

# flush the buffer
$| = 1;

our ($quit, $interval, $pid);

# name used to store pid/log etc.
our $name = basename $0;
$name =~ s/\.pl//;

sub collect
{
  my $ns = new Collector::NodeSensor;
  $ns->createXML;
  $ns->storeXML;
}

sub main
{
  # initialize the ConfigReader
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  $interval = $config->{nodesensor}{interval}  || 600; # seconds
  my $range = $config->{nodesensor}{randomize} || 10; # seconds
  $interval += int(rand($range));

  my $pid_dir = (-d qq|$config->{baseDir}/jobmon/run|) 
        ? qq|$config->{baseDir}/jobmon/run| 
        : qq|/var/tmp|;

  # become a daemon
  my $pid_file = qq|$pid_dir/$name.pid|;
  my $log_file = $config->{baseDir}.qq|/jobmon/log/$name.log|;
  $pid = daemonize($pid_file, $log_file);

  # any value other than 0 will quit the loop 
  $quit = 0;

  # install signal handlers. 
  defined $Config{sig_name} || die qq|no sigs?, stopped|;
  my $handler = sub {
    my $signal = shift;
    print "signal $signal pulled!\n";
    $quit++; 
    $interval = 0;
  };
  local $SIG{TERM} = $handler;
  local $SIG{INT}  = $handler;

  # now the main part
  # sit in an infinte loop
  # note that we're re-initialising the sensor each time - a la a cron job
  until ($quit) {
    eval {
      show_message qq|start collection|;
      collect;
      show_message qq|done|;
    };
    warn qq|skipping this iteration because:\n $@| if $@;
    sleep $interval;
  }
  show_message qq|leaving main|;
}

main;
__END__
