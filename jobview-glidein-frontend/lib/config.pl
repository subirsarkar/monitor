#!/usr/bin/env perl

use strict;
use warnings;

use constant MINUTE => 60; ## seconds
use constant HOUR   => 60 * MINUTE;
use constant DAY    => 24 * HOUR;

# -----------------
# Section [general]
# -----------------
our $config = 
{ 
          server => q|UCSD glidein Frontend|,
            site => q|T2_US_UCSD|,
         baseDir => q|/opt/jobview|, 
       collector => q|glidein-collector.t2.ucsd.edu|, 
          schedd => q|glidein-2.t2.ucsd.edu|,
         verbose => 0,
        time_cmd => 1,
  show_cmd_error => 1,
     remove_role => 1,
      show_table => {
           userce => 1,
         priority => 1
      }
};
$config->{html} = qq|$config->{baseDir}/html/overview.html|;
$config->{xml}  = {save => 1, file => qq|$config->{baseDir}/html/overview.xml|};
$config->{json} = {save => 1, file => qq|$config->{baseDir}/html/overview.json|};
$config->{db} = 
{
   ce2site => qq|$config->{baseDir}/db/ce2site.db|,
   jobinfo => qq|$config->{baseDir}/db/jobinfo.db|,
      slot => qq|$config->{baseDir}/db/slots.db|,
  priority => qq|$config->{baseDir}/db/condorprio.db|,
      novm => qq|$config->{baseDir}/db/missing_vm.txt|
};

# --------------------
# Section [RRD]
# --------------------
$config->{rrd} = 
{
     verbose => 0, 
     enabled => 1,
    location => qq|$config->{baseDir}/db|,
          db => qq|file.rrd|,
        step => 360,
       width => 300,
      height => 100,
  timeSlices =>
  [
    { ptag => 'lhour',  period =>      HOUR },
    { ptag => 'lday',   period =>       DAY },
    { ptag => 'lweek',  period =>   7 * DAY },
    { ptag => 'lmonth', period =>  30 * DAY },
    { ptag => 'lyear',  period => 365 * DAY }
  ],
     comment => $config->{server}
};

$config;
__END__
