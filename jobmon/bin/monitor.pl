#!/usr/bin/env perl -T

package main;

use strict;
use warnings;

use Config;
use POSIX qw/strftime/;
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;

BEGIN {
  my $logfile = qq|/tmp/jobmoncgi.log|;
  use CGI::Carp qw/carpout/;
  open LOG, qq|>>$logfile| or die qq|failed to open $logfile: $!, stopped|;
  carpout(\*LOG);
}
END {
  close LOG;
}

use WebService::MonitorUtil qw/show_message/;
use WebService::Monitor;
use constant MINUTE => 60;
sub main
{
  $ENV{'PATH'} = qq|/bin:/usr/bin|;
  delete @ENV{qw/IFS CDPATH ENV BASH_ENV/};

  # check support for signals 
  defined $Config{sig_name} || die qq|no sigs?, stopped|;
  eval {
    # Create the Monitor object so that we can use the object
    # to close DB connection in case of abnormal exit
    my $app = new WebService::Monitor( PARAMS => { cfg_file => './config.pl' } );

    my $handler = sub 
    { 
      show_message qq|alarm pulled, close DB connection and exit|;
      $app->teardown;

      die qq|Forced death!|;
    };
    local $SIG{KILL} = $handler;
    local $SIG{ALRM} = $handler;
    alarm 5 * MINUTE;

    # Now onto regular business
    $app->run;
  };
  $@ and warn $@;

  # Before leaving cancel the alarm anyway irrespective of if 
  # the application succeeded/died.
  alarm 0;
}

main;
__END__
