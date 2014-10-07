#!/usr/bin/env perl

use strict;
use warnings;

use constant MINUTE => 60;
use constant HOUR   => 60 * MINUTE;
use constant DAY    => 24 * HOUR;

# -----------------
# Section [general]
# -----------------
our $config = 
{ 
           verbose => 0, 
              site => q|SNS-Pisa|,
           baseDir => q|/opt/jobview|, 
            domain => q|sns.it|,
              lrms => q|pbs|,
      lrms_version => q||, # so far not used
           acctDir => q|/var/spool/pbs/server_priv/accounting|,  # accounting directory (batch system)
            jobDir => q|/var/spool/pbs/server_priv/jobs|,        # Job information directory (batch system)
        gridmapDir => q|/opt/edg/var/gatekeeper|,                # for JID->DN mapping
      dnmap_option => q|gridmap|,                                # other options: jobdef, external
       has_jobflow => 0,
          time_cmd => 1,
    show_cmd_error => 1,
          has_maui => 1,
       requires_su => 0,
      server_as_ce => 0,
        show_table => 
        {                 # show/hide certain tables
                 ce => 1,
               user => 0,
          fairshare => 1,
          localuser => 0 
        },
  privacy_enforced => 1,
    groups_dnshown => ['cms', 'cmsprd', 'theophys'],
   jobview_version => q|1.3.2|,
               doc => q|http://sarkar.web.cern.ch/sarkar/doc/pbs_jobview.html|
};
$config->{html}   = qq|$config->{baseDir}/html/overview.html|;
$config->{xml}    = {save => 1, file => qq|$config->{baseDir}/html/overview.xml|};
$config->{xml_hf} = {
                              save => 1, 
                              file => qq|$config->{baseDir}/html/jobview.xml|, 
                      show_joblist => 1,
                           show_dn => 0};
$config->{json}   = {save => 1, file => qq|$config->{baseDir}/html/overview.json|};
$config->{db} = 
{
     dnmap => qq|$config->{baseDir}/db/dnmap.db|, # should be on a shared filesystem for a multi-ce system
   jobinfo => qq|$config->{baseDir}/db/jobinfo.db|,
      slot => qq|$config->{baseDir}/db/slots.db|,
  priority => qq|$config->{baseDir}/db/prio.db|
};

# --------------------
# Section [RRD]
# --------------------
$config->{rrd} = 
{
             debug => 1, 
           enabled => 1, # not used yet
           rrdtool => q|/usr/bin/rrdtool|,
           comment => $config->{site},
          location => qq|$config->{baseDir}/db|,
                db => qq|filen.rrd|,
              step => 180,
             width => 300,
            height => 100,
        timeSlices =>                             # time period -> seconds map
        [
          { ptag => q|lhour|,  period =>      HOUR },
          { ptag => q|lday|,   period =>       DAY },
          { ptag => q|lweek|,  period =>   7 * DAY },
          { ptag => q|lmonth|, period =>  30 * DAY },
          { ptag => q|lyear|,  period => 365 * DAY }
        ],
   supportedGroups => 
   [ 
     'biomed',     
     'atlas', 
     'theophys' 
   ]
};

$config;
__END__
