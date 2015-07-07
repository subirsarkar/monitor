#!/usr/bin/env perl

package main;

use strict;
use warnings;

use CGI qw/:standard/;
BEGIN {
  use CGI::Carp qw(carpout);
  open LOG, ">>/tmp/tacmoncgi.log" or die "Unable to open tacmoncgi.log: $!\n";
  carpout(\*LOG);
}
use CGI::Carp qw/fatalsToBrowser/;

use lib qw(/var/www/cgi-bin/tacmon);
use Monitor;

my $cgi = new CGI;
$cgi->autoEscape(1);

my $command = $cgi->param('command');
$command = 'detlist' if not defined $command;

my $run = $cgi->param('run');
$run = '?' if not defined $run;

print STDERR $command, " ", $run, "\n";
my $obj = new Monitor($cgi);

if ($command eq 'detlist') {
  $obj->sendDetList;
}
elsif ($command eq 'runlist') {
  $obj->sendRunList;
}
elsif ($run ne '?') {
  $obj->setRun($run);
  if ($command eq 'shiftsummary') {
    $obj->sendShiftSummaryInfo;
  }
  elsif ($command eq 'runsummary') {
    $obj->sendRunSummaryInfo;
  }
  elsif ($command eq 'localraw') {
    $obj->sendLocalRawFileInfo;
  }
  elsif ($command eq 'localedm') {
    $obj->sendLocalEdmFileInfo;
  }
  elsif ($command eq 'castorraw') {
    $obj->sendCastorRawFileInfo;
  }
  elsif ($command eq 'castoredm') {
    $obj->sendCastorEdmFileInfo;
  }
  elsif ($command eq 'dbsraw') {
    $obj->sendDBSRawInfo;
  }
  elsif ($command eq 'dbsreco') {
    $obj->sendDBSRecoInfo;
  }
  elsif ($command eq 'timestamp') {
    $obj->sendLastUpdateTime;
  }
}
__END__
