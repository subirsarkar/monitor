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
   baseDir => q|/afs/cern.ch/cms/LCG/crab/csmon|, 
   verbose => 0,
   servers => { # redundant because we now get the list dynamically
                   bari => { baseurl => q|http://crab1.ba.infn.it:8888|, enabled => 1},
     slc5ucsd_glidein_2 => { baseurl => q|http://glidein-2.t2.ucsd.edu:8888|, enabled => 1},
          ucsd_submit_2 => { baseurl => q|http://submit-2.t2.ucsd.edu:8888|,  enabled => 1},
       slc5cern_vocms21 => { baseurl => q|http://vocms21.cern.ch:8888|, enabled => 1},
        slc5caf_vocms22 => { baseurl => q|http://vocms22.cern.ch:8888|, enabled => 0},
           cern_vocms58 => { baseurl => q|http://vocms58.cern.ch:8888|, enabled => 1},
                   desy => { baseurl => q|http://t2-cms-cs0.desy.de:8888|, enabled => 1}
  },
  server_blacklist => [
     'vocms104'
  ],
  color_code => {
      tasklist => {notice => 20, warning => 50},
      msgqueue => {notice => 500, warning => 1000}
  }
};
# --------------------
# Section [RRD]
# --------------------
$config->{rrd} = 
{
       verbose => 0, 
       rrdtool => q|/afs/cern.ch/cms/LCG/crab/rrdtool/bin/rrdtool|,
      location => qq|$config->{baseDir}/db|,
          step => 180,
         width => 600,
        height => 200,
    timeSlices =>
    [
      { ptag => 'lhour',  period =>      HOUR },
      { ptag => 'lday',   period =>       DAY },
      { ptag => 'lweek',  period =>   7 * DAY },
      { ptag => 'lmonth', period =>  30 * DAY },
      { ptag => 'lyear',  period => 365 * DAY }
    ],
       comment => q|CRAB Server|
};

$config;
__END__
