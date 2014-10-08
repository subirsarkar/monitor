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
use Collector::GridInfoCore;
use Collector::Util qw/restoreInfo
                       storeInfo
                       daemonize 
                       show_message/;

use constant MINUTE => 60;
#our ($quit, $interval, $pid);

# flush the buffer
$| = 1;

our $batchTypes =
{
  condor => qq|Collector::Condor::JobidList|
};

sub save
{
  my $dict = shift;

  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  # cached information
  print STDERR Data::Dumper->Dump([$dict], [qw/dict/]) if $verbose>0;
  my $infoFile = qq|$config->{baseDir}/jobmon/data/gridinfo.db|;
  my $tmpFile  = qq|$infoFile.tmp|;
  storeInfo($tmpFile, $dict) 
    or warn qq|Failed to save information in $tmpFile| and return;

  # Now copy to the permanent place in an atomic step
  copy $tmpFile, $infoFile 
    or warn qq|Failed to copy $tmpFile to $infoFile|;
}
sub collect
{
  my $dict = shift;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $verbose = $config->{verbose} || 0;
  my $lrms    = $config->{lrms}      || die qq|Batch system not specified in config.pl!, stopped|;
  my $class   = $batchTypes->{$lrms} || die qq|Batch system $lrms not supported!, stopped|;

  show_message qq|start - collecting Job Id and status|;
  my $obj = Collector::ObjectFactory->instantiate($class);
  my $jobInfo = $obj->list;          # a {JID, jobStatus} hash
  my $nTotalJobs = scalar keys(%$jobInfo);
  show_message qq| done - collecting Job Id and status|;

  # cached information
  my $infoFile = qq|$config->{baseDir}/jobmon/data/gridinfo.db|;

  # read the current file and store content in a list
  # we might avoid calls to jobsesc, role etc that do not really change with time
  my $jmap = restoreInfo($infoFile);
  my $cacheEntries = scalar keys %$jmap;
  
  my @nList = ();
  show_message qq|start - collecting information from cache with $cacheEntries entries|;
  while ( my ($jid, $status) = each %$jobInfo ) {
    ($status eq 'R' or $status eq 'Q') or next;
    print STDERR qq|>>> Processing JID=$jid, STATUS=$status ...\n| if $verbose;
    if (exists $jmap->{$jid}) {
      $dict->{$jid}{gridid}  = $jmap->{$jid}{gridid};
      $dict->{$jid}{rb}      = $jmap->{$jid}{rb};
      $dict->{$jid}{subject} = $jmap->{$jid}{subject};
      $dict->{$jid}{jobdesc} = $jmap->{$jid}{jobdesc};
      $dict->{$jid}{role}    = $jmap->{$jid}{role};
      $dict->{$jid}{gridce}  = $jmap->{$jid}{gridce};
      # For a running job compute timeleft in each iteration, to be precise
      # so skip setting any value

      # For a queued job, we need not be very precise about 'proxy timeleft'
      if ($status eq 'Q') {
        my $nv = 0;
        while ( my ($key,$val) = each %{$dict->{$jid}} ) {
          ++$nv unless defined $val;
        }

        $dict->{$jid}{timeleft}  = $jmap->{$jid}{timeleft};
        $dict->{$jid}{timestamp} = $jmap->{$jid}{timestamp}; 
        if (defined $dict->{$jid}{timeleft} and $dict->{$jid}{timeleft} > -1) {
          my $timenow = time();
          $dict->{$jid}{timeleft} -= $timenow - ($dict->{$jid}{timestamp} || $timenow);
          $dict->{$jid}{timestamp} = $timenow;

          # no need to check further in case the main parameters are already defined
          next unless $nv;
        }
      }
    }
    push @nList, $jid;    
  }
  show_message qq| done - collecting information from cache|;
  my $nJobs = scalar @nList;
  show_message qq|start - collecting Core Grid information for $nJobs out of $nTotalJobs jobs|;
  my $j = new Collector::GridInfoCore({ joblist => \@nList });
  show_message qq| done - collecting Core Grid information|;

  my $nent = 0;
  show_message qq|start - storing Grid information for $nTotalJobs jobs|;
  while ( my ($jid, $status) = each %$jobInfo ) {
    $dict->{$jid}{status} = $status;
    ($status eq 'R' or $status eq 'Q') or next;
    print STDERR qq|.| unless (++$nent)%10;
    show_message qq| jid $jid, status[$status]| if $verbose;
    $dict->{$jid}{gridid}    = $j->gridid($jid)   unless defined $dict->{$jid}{gridid};
    $dict->{$jid}{rb}        = $j->rb($jid)       unless defined $dict->{$jid}{rb};
    $dict->{$jid}{subject}   = $j->subject($jid)  unless defined $dict->{$jid}{subject};
    $dict->{$jid}{jobdesc}   = $j->jobdesc($jid)  unless defined $dict->{$jid}{jobdesc};
    $dict->{$jid}{role}      = $j->role($jid)     unless defined $dict->{$jid}{role};
    $dict->{$jid}{gridce}    = $j->gridce($jid)   unless defined $dict->{$jid}{gridce};
    $dict->{$jid}{timeleft}  = $j->timeleft($jid) unless (defined $dict->{$jid}{timeleft} and $dict->{$jid}{timeleft} > -1);
    $dict->{$jid}{timestamp} = time() if ($status eq 'Q' and not defined $dict->{$jid}{timestamp});
  }
  print qq|done\n|;
  save $dict;
  show_message qq| done - storing Grid information|;
}

sub main
{
  # name used to store pid/log etc.
  my $name = basename $0;
  $name =~ s/\.pl//;

  # initialize the ConfigReader
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $interval = $config->{gridinfoCache}{interval} || 20 * MINUTE;
  my $p_timeout  = $config->{gridinfoCache}{timeout} || 10 * MINUTE;
  my $pid_dir = (-d qq|$config->{baseDir}/jobmon/run|) 
               ? qq|$config->{baseDir}/jobmon/run| 
               :  q|/var/tmp|;

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
    show_message qq|signal $signal pulled! will quit|;
    ++$quit; 
    $interval = 0;
  };
  local $SIG{TERM} = $handler;
  local $SIG{INT}  = $handler;

  my $alarm_handler = sub 
  {
    my $signal = shift;
    print qq|\n|;
    show_message qq|signal $signal pulled! will save and retry|;
    die q|timeout|;
  };
  # now the main part
  # sit in an infinte loop
  # note that we're re-initialising the sensor each time - a la a cron job
  show_message qq|entering main|;
  until ($quit) {
    my $dict = {};
    eval {
      # install alarm handler
      local $SIG{ALRM} = $alarm_handler;

      # set timeout period
      alarm $p_timeout;

      # main part
      show_message qq|start collection|;
      collect $dict;
      show_message qq|done|;

      # must reset alarm in normal course
      alarm 0;
    };
    if ($@) {
      my $message = qq|$@ iteration skipped|;
      $message =~ s#\n##;
      show_message $message;

      # no need to reset in case alarm already triggered
      (($@ =~ /timeout/) ? save $dict : alarm 0);
    }
    sleep $interval;
  }
  alarm 0; # redundant
  show_message qq|leaving main|;
}

main;
__END__
