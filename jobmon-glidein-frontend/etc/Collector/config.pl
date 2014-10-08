#!/usr/bin/env perl

use strict;
use warnings;

use constant MINUTE => 60;
use constant HOUR   => 60 * MINUTE;

our $cfg = 
{
        baseDir => q|/opt|,                                                # Software installation directory
          site  => q|T2_US_UCSD|,                                          # Site
         domain => q|t2.ucsd.edu|,                                         # the domain may be specified
           lrms => q|condor|,                                              # batch system
   lrms_version => q|7.8.X|,                                               # batch version
#     constraint => {
#            'condor_q' => qq|SleepSlot =!= TRUE|,
#       'condor_status' => qq|iam_sleep_slot==0|
#     },
  queues_toskip => [],                                                     # local queues to be skipped
       nodeinfo => {nlines => 4000},                                       #
      cachelife => {jobinfo  =>  5 * MINUTE, gridinfo  => 20 * MINUTE},    #
     nodesensor => {interval => 10 * MINUTE, randomize => 20 },            #
      jobsensor => {interval => 10 * MINUTE},                              #
   jobinfoCache => {interval =>  5 * MINUTE},                              #
  gridinfoCache => {interval => 20 * MINUTE},                              #
          debug => 0,                                                      # debug option
        verbose => 0,                                                      # 
         voattr => {                                                       #
             cms => {
                 log => q|cmsRun1-main.sh-stdout.log|, 
               error => q|cmsRun1-main.sh-stderr.log| 
             },
             atlas => {
                 log => qq|RunTransform.log|, 
               error => qq|myapp.log|     
             },
             babar => {
                 log => q|simu(?:.*?).log|,         
               error => q|simu(?:.*?).batchout| 
             },
             cdf => {
                 log => q|job(?:.*?).out|,          
               error => q|job(?:.*?).err|       
             },
             lhcb => { 
                 log => q|job.output|,
               error => q|localEnv.log|
             },
             theophys => {
                 log => q|runQ.out|,
               error => q|runQ.err|
             }
	 }
};

$cfg->{collector} = q|glidein-collector.|.$cfg->{domain}; 
$cfg->{schedd}    = q|glidein-2|.$cfg->{domain};
$cfg->{dbcfg}     = qq|$cfg->{baseDir}/jobmon/etc/.my.cnf|;        # mysql login detail
$cfg->{xmldir}    = qq|$cfg->{baseDir}/jobmon/data|;               # data directory         
$cfg->{logfile}   = qq|$cfg->{baseDir}/jobmon/log/qstat_mon.log|;  # 
$cfg->{db}{jobinfo} = qq|$cfg->{baseDir}/jobmon/data/jobinfo.db|;

$cfg;
__END__
