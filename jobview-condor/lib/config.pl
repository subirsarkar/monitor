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
         verbose => 1,
         baseDir => q|/opt/jobview_t2|, 
          domain => q|t2.ucsd.edu|,
            site => q|T2_US_UCSD|,
           batch => q|Condor|,
   batch_version => q|7.8.X|,  # not relevant anymore:-)
       collector => q|osg-gw-1.t2.ucsd.edu|, 
     schedd_list => [],        # if listed, will be used
     has_jobflow => 0,
        time_cmd => 1,
  show_cmd_error => 1,
      constraint => {
             'condor_q' => qq|SleepSlot =!= TRUE|,
        'condor_status' => qq|iam_sleep_slot==0|
      },
      show_table => {          # all but the user tables shown by default (value:1)
              ce => 1,
            user => 1,
        priority => 1
      },
   privacy_enforced => 0,
     groups_dnshown => ['cms', 'cmsprod', 'cmspa', 'other'],
    jobview_version => q|1.4.0|,
          group_map => {uscms => q|cms|, cmspp => q|cmsprod|},
  min_walltime_reqd => 10,     # mins; required for inclusion in CPU efficiency calculation
        run_offline => 0
};
$config->{html} = qq|$config->{baseDir}/html/overview.html|;
$config->{json} = {save => 1, file => qq|$config->{baseDir}/html/overview.json|};
$config->{xml}  = {save => 1, file => qq|$config->{baseDir}/html/overview.xml|};
$config->{xml_hf} = 
{
          save => 1, 
          file => qq|$config->{baseDir}/html/jobview.xml|, 
  show_joblist => 1,
       show_dn => 0
};

# internal file based DB, fine as default
$config->{db} = 
{
   jobinfo => qq|$config->{baseDir}/db/jobinfo.db|,
      slot => qq|$config->{baseDir}/db/slots.db|,
  priority => qq|$config->{baseDir}/db/condorprio.db|,
      novm => qq|$config->{baseDir}/db/missing_vm.txt|,
      dump => {
         condor_status_slots => qq|$config->{baseDir}/db/condor_status_slots.list|,
             condor_status_r => qq|$config->{baseDir}/db/condor_status_r.list|,
                  condor_q_r => qq|$config->{baseDir}/db/condor_q_r.list|,
                  condor_q_p => qq|$config->{baseDir}/db/condor_q_p.list|
      }   
};
# --------------------
# Section [RRD]
# --------------------
$config->{rrd} = 
{
     verbose => 1, 
    location => qq|$config->{baseDir}/db|,
          db => q|filen.rrd|,  # for global variables
        step => 180, # try to keep in sync with the cron job period
       width => 300,
      height => 100,
     comment => $config->{site},
  timeSlices =>
  [
    { ptag => 'lhour',  period =>      HOUR },
    { ptag => 'lday',   period =>       DAY },
    { ptag => 'lweek',  period =>   7 * DAY },
    { ptag => 'lmonth', period =>  30 * DAY },
    { ptag => 'lyear',  period => 365 * DAY }
  ],
  ceList => 
  [
    'osg-gw-2',
    'osg-gw-4',
    'osg-gw-6',
    'osg-gw-7'
  ], 
  groupList => 
  [ 
    'cms',     
    'cmsprod', 
    'osg', 
    'ucsdg', 
    'other', 
    'sbgrid',
    'cmspa'
  ]
};

$config;
__END__
