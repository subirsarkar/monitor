#!/usr/bin/env perl

package main;

use strict;
use warnings;

use CGI::Carp qw/fatalsToBrowser/;
BEGIN {
  use CGI::Carp qw(carpout);
  open LOG, ">>/tmp/ftsmoncgi.log" or die "Unable to open ftsmoncgi.log: $!\n";
  carpout(\*LOG);
}
use CGI qw/:standard/;

use lib qw(/var/www/cgi-bin/ftsmon);
use Monitor;

my $cgi = new CGI;
my $command = $cgi->param('command');
$command = 'channellist' if not defined $command;

my @stateList = $cgi->param('state');
@stateList = ('Submitted','Pending','Active') if !scalar @stateList;

my $mon = new Monitor;
exit 1 if !$mon->valid;

if ($command eq 'channellist') {
  $mon->sendChannelList ($cgi, \@stateList);
}
elsif ($command eq 'joblist') {
  my $channel = $cgi->param('channel');
  $mon->sendJobList ($cgi, \@stateList, $channel);
}
elsif ($command eq 'filelist') {
  my $jobid = $cgi->param('jobid');
  $mon->sendFileList ($cgi, $jobid);
}
elsif ($command eq 'filestatus') {
  my $jobid = $cgi->param('jobid');
  my $name  = $cgi->param('filename');
  $mon->sendFileStatus ($cgi, $jobid, $name);
}
elsif ($command eq 'timestamp') {
  $mon->sendTimestamp ($cgi);
}
elsif ($command eq 'allfiles') {
  $mon->sendAllFileList ($cgi, \@stateList);
}

__END__
