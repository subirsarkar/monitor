#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Config;
use File::Basename;
use POSIX qw/strftime/;

use Collector::ConfigReader;
use Collector::JobSensor;
use Collector::Util qw/daemonize show_message/;

# flush the buffer
$| = 1;

sub collect
{
  my $js = Collector::JobSensor->new;
  # We try thrice for successful DB connection and then give up
  my $ecode = 0;
  my $nattempts = 0;
  until ($ecode = $js->dbConnected) {
    last if ++$nattempts > 2;
    sleep 10;
  }
  show_message qq|Failed to connect to DB, giving up after $nattempts attempts ..| 
    and return unless $ecode;

  $js->fetch;
}

sub main
{
  # name used to store pid/log etc.
  my $name = basename $0;
  $name =~ s/\.pl//;

  # initialize the ConfigReader
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $interval = $config->{jobsensor}{interval} || 600; # second

  my $pid_dir = (-d qq|$config->{baseDir}/jobmon/run|) 
       ? qq|$config->{baseDir}/jobmon/run| 
       : qq|/var/tmp|;

  # become a daemon
  my $pid_file = qq|$pid_dir/$name.pid|;
  my $log_file = qq|$config->{baseDir}/jobmon/log/$name.log|;
  my $pid = daemonize($pid_file, $log_file);

  # any value other than 0 will quit the loop 
  my $quit = 0;

  # install signal handlers. 
  defined $Config{sig_name} || die q|no sigs?, stopped|;
  my $handler = sub 
  { 
    my $signal = shift;
    print qq|signal $signal pulled, will quit!\n|;
    ++$quit; 
    $interval = 0; 
  };
  local $SIG{TERM} = $handler;
  local $SIG{INT}  = $handler;

  # now the main part
  # sit in an infinte loop
  # note that we're re-initialising the sensor each time - a la a cron job
  show_message q|entering main|;
  until ($quit) {
    eval {
      show_message q|start collection|;
      collect;
      show_message q|done|;
    };
    warn qq|iteration skipped, reason:\n [$@]\n| if $@;
    sleep $interval;
  }
  show_message q|leaving main|;
}

main;
__END__
