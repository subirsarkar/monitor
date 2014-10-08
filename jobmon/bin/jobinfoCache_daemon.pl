#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;

use Config;
use IO::File;
use File::Copy;
use File::Basename;
use POSIX qw/strftime/;

use Collector::ConfigReader;
use Collector::ObjectFactory;
use Collector::Util qw/daemonize 
                       storeInfo
                       show_message/;

# flush the buffer
$| = 1;

our $batchTypes =
{
     lsf => qq|Collector::LSF::JobList|,
     pbs => qq|Collector::PBS::JobList|,
  condor => qq|Collector::Condor::JobList|
};

sub collect
{
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $infoFile = qq|$config->{baseDir}/jobmon/data/jobs.db|;
  my $tmpFile  = qq|$infoFile.tmp|;

  my $lrms = $config->{lrms} || die qq|Batch system no specified in config.pl!, stopped|;
  my $class = $batchTypes->{$lrms} || die qq|Batch system $lrms not supported!, stopped|;
  my $obj = Collector::ObjectFactory->instantiate($class);
  my $list = $obj->jobinfo;

  print STDERR Data::Dumper->Dump([$list], [qw/joblist/]) if $verbose;
  storeInfo($tmpFile, $list) or return;

  # atomic step
  copy $tmpFile, $infoFile or warn qq|Failed to copy $tmpFile to $infoFile!!|;
}

sub main
{
  # name used to store pid/log etc.
  my $name = basename $0;
  $name =~ s/\.pl//;

  # initialize the ConfigReader
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $interval   = $config->{jobinfoCache}{interval} || 600; # second
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
  defined $Config{sig_name} || die qq|no sigs?, stopped|;
  my $handler = sub 
  {
    my $signal = shift;
    print "Signal $signal pulled, will quit!\n";
    ++$quit; 
    $interval = 0;
  };
  local $SIG{TERM} = $handler;
  local $SIG{INT}  = $handler;

  # now the main part
  # sit in an infinte loop
  # note that we're re-initialising the sensor each time - a la a cron job
  show_message qq|entering main|;
  until ($quit) {
    eval {
      show_message qq|start collection|;
      collect;
      show_message qq|done|;
    };
    warn qq|iteration skipped, reason:\n [$@]\n| if $@;
    sleep $interval;
  }
  show_message qq|leaving main|;
}

main;
__END__
