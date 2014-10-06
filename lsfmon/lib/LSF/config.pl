#!/usr/bin/env perl
# ------------------------------------------------------------------
# Configuration file in Perl itself
# Please adjust parameters in app.cfg
#
# version 1.2 28/04/2010
# author: S. Sarkar - INFN-Pisa
# ------------------------------------------------------------------

use strict;
use warnings;

use constant MINUTE => 60; # seconds
use constant HOUR   => 60 * MINUTE;
use constant DAY    => 24 * HOUR;

# -----------------
# Section [general]
# -----------------
our $config = 
{ 
         verbose => 0,
         baseDir => q|/usr/local/hpc-tools/lsfmon_v2.0.0|,                 # installtion dir
            site => q|Pisa|, 
         samname => q|INFN-HPC|,                 # well, essentially a more qualified name
           batch => q|LSF|,                      # batch information
   batch_version => q|9.0|,
     use_bugroup => 1,                            # use bgroup to map user -> group (default: 0)
    cluster_type => 'hpc',
  show_cmd_error => 1,                            # show shell command execution error (default: /dev/null)
        time_cmd => 1,                            # check certain command execution timing
   queues_toskip => [],                           # exclude from accounting
  lsfmon_version => q|2.0.0|,
      lsfmon_doc => q|http://sarkar.web.cern.ch/sarkar/doc/lsfmon.html|
};

# ------------------
#  User Group
# ------------------
$config->{group} = 
{
  groupinfo_file => qq|$config->{baseDir}/db/group_info.txt|,
  groupinfo_db   => qq|$config->{baseDir}/db/groupinfo.db|
};

# ------------------
# Section [overview]
# ------------------
$config->{overview} = 
{
       verbose => 0,
       infoDir => q|/usr/local/lsf/work/INFN-HPC/logdir/info|,  # needed to find user DN
  max_file_age => 7,
      template => qq|$config->{baseDir}/tmpl/overview.hpc.html.tmpl|, # INPUT template file, should not be changed
    template_queue => qq|$config->{baseDir}/tmpl/overview.queue.hpc.html.tmpl|, # INPUT template file, should not be changed
        # if you change name of any of the 4 files, please update bin/overview.sh accordingly
          html => qq|$config->{baseDir}/html/overview.html|,      # always create the html 
           xml => {                             # optionally create xml and json also
                  save => 1, 
                  file => qq|$config->{baseDir}/html/overview.xml|
                },
        xml_hf => {                           # HappyFace compatible XML
                  save => 1, 
                  file => qq|$config->{baseDir}/html/jobview.xml|
                },
          json => {
                  save => 1, 
                  file => qq|$config->{baseDir}/html/overview.json|
                },
    html_queue => qq|$config->{baseDir}/html/overview.queue.html|,      # always create the html 
        dbFile => qq|$config->{baseDir}/db/dnmap.db|, # cache for the JID -> User DN mapping
        slotDB => qq|$config->{baseDir}/db/slots.db|, # store max slots ever seen
         bjobs => {                                                  
               # use cached info from last iteration if the current one fails.
              dbfile => qq|$config->{baseDir}/db/bjobs.db|,
           max_jobs  => 2000      # for an enormous farm, do _not_ try bjobs -r -l on all the
                                  #  jobs at once; do it in steps of max_jobs jobs. experimental
         },
  hosts_toskip => [         # these hosts are shown by bhosts but they are not WNs
                  ],
    show_table => {         # show/hide certain tables
              group => 1,
                 ce => 1,
             userdn => 1,
               user => 1,
          fairshare => 1,
         localusers => 1 
    },
  privacy_enforced => 0,        # privacy options, if enabled DN of only groups_dnshown groups shown
    groups_dnshown => ['cms', 'theophys', 'theoinfn', 'theodip'],
         filter_ce => 0,        # optionally exclude some CEs
      ce_whitelist => []
};

# ------------------
# Section [jobflow]
# ------------------
$config->{jobflow} = 
{
  verbose => 3,
   period => 3600               # extending the period will involve LSF reconfig
};

# -------------
# Section [RRD]
# -------------
$config->{rrd} = 
{
     verbose => 0, 
     enabled => 1,                          # redundant, not used yet
    location => qq|$config->{baseDir}/db|,
          db => {global => q|filen.rrd|, jobslots => q|jobslots.rrd|, all_queues => q|allqueues.rrd|}, # for global parameters
        step => 180,                        # update frequency
       width => 300,                        # image width and height
      height => 100,
     comment => $config->{samname},
  timeSlices =>                             # time period -> seconds map
  [
    { ptag => q|lhour|,  period =>      HOUR },
    { ptag => q|lday|,   period =>       DAY },
    { ptag => q|lweek|,  period =>   7 * DAY },
    { ptag => q|lmonth|, period =>  30 * DAY },
    { ptag => q|lyear|,  period => 365 * DAY }
  ]
};

# --------------------
# Section [accounting]
# --------------------
$config->{accounting} = 
{
          verbose => 0,
         read_all => 1,
            debug => { enabled => 0, max_files => 4 }, # if enabled, reads only the last max_files 
                                            # accounting files used to debug new feature, bug fixes
      infoDirList => # LSF accounting directories
      [
        qq|/usr/local/lsf/work/INFN-HPC/logdir|
      ],
         htmlFile => qq|$config->{baseDir}/html/accounting.html|,       # output html
  template_period => qq|$config->{baseDir}/tmpl/acct_period.html.tmpl|, # template files
    template_full => qq|$config->{baseDir}/tmpl/acct_overall.html.tmpl|,
         save_xml => 1,
        skip_root => 1,                                        # exclude jobs run as root 
           dbFile => qq|$config->{baseDir}/db/acctinfo.db|,
     sortby_field => q|walltime|, # sort the tables by this 'column'
                                  # possible values: 'jobs', 'sjobs', 'success_rate',
                                  # 'walltime', 'cputime', 'cpueff', 'walltime_share', 'avgwait'
       timeSlices => 
       [
         { ptag => q|l3hour|,  period =>    3 * HOUR, label => q|last 3 hours|,   minJobs =>   1 },
         { ptag => q|l6hour|,  period =>    6 * HOUR, label => q|last 6 hours|,   minJobs =>   1 },
         { ptag => q|l12hour|, period =>   12 * HOUR, label => q|last 12 hours|,  minJobs =>   2 },
         { ptag => q|lday|,    period =>         DAY, label => q|last 24 hours|,  minJobs =>  10 },
         { ptag => q|lweek|,   period =>     7 * DAY, label => q|last week|,      minJobs =>  20 },
         { ptag => q|lmonth|,  period =>    30 * DAY, label => q|last month|,     minJobs =>  50 },
         { ptag => q|l3month|, period =>    90 * DAY, label => q|last 3 months|,  minJobs => 100 },
         { ptag => q|l6month|, period =>   180 * DAY, label => q|last 6 months|,  minJobs => 300 },
         { ptag => q|lyear|,   period =>   365 * DAY, label => q|last year|,      minJobs => 500 },
         { ptag => q|lfull|,   period => 99999 * DAY, label => q|full period|,    minJobs => 500 }
       ]
};

# --------------------
# Section [plotcreator]
# --------------------
$config->{plotcreator} = 
{
   # We assign colors statically for major VOs/Groups. The fleeting groups 
   # are assigned color randomly in each iteration from a pool of 256 colors 
   colorDict =>
   {
        thdevel => q|#b84c82|,
          npqcd => q|#52a489|,
       theorici => q|#9745ab|,
          sissa => q|#0000ff|,
            aae => q|#5580d5|,
         fluent => q|#b89cc2|,
        biophys => q|#31627b|,
         qcdlat => q|#30a051|,
      fieldturb => q|#82a489|,
         ninpha => q|#e745ab|,
           wsip => q|#7600ff|,
         indark => q|#7780d5|,
         abacus => q|#d84c82|
   },
   defaultColor => q|#ca940c|, # in case a VO/group still does not have a color assigned
   image =>                    # Image properties
   {
          pie => { 
                verbose => 0, 
                  width => 200, # width and height of the resulting image
                 height => 180, 
            max_entries => 10   # max number of entries to be shown
          },
          bar => { 
                  verbose => 0, 
                    width => 210, 
                   height => 180, 
              max_entries => 12,  # max number of entries to be shown
               axis_space => -40, # even if we opt not to show the axis labels, 
                                  # space is reserved and axis title is placed beyond that
                                  # default 8, adjust to bring the title back closer to the axis
               text_space => 4,   # space between axis and title
            max_label_len => 8    # truncate long groupname to max_label_len 
                                  # chacracters (although labels are not shown)
          },
      legends => { 
        verbose => 0, 
          width => 520, 
         height =>  80, 
         max_re => 4,   # Maximum number of entries per row   
          xstep => 105, # adjust in order to prevent a groupname overlap with the next entry
          ystep => 18   # crucial for long group names
      }
   },
   font => {                # for historical reason, we use an external font (default: arial)
         dir => qq|$config->{baseDir}/fonts|, 
       names => [
                 q|LiberationSerif-Regular.ttf|, 
                 q|arial.ttf|,
                 q|Vera.ttf|
               ],
     default => 1 # index (of arial.ttf)
   },
   minReq =>      # VOs/Groups not satisfying the condition(s) are clubbed as 'others' (in %)
   {
         common => 1, 
       jobShare => 1, 
     wtimeShare => 1, 
         cpuEff => 10, 
        avgWait => 0.05 # > 1% of the maximum shown
   }
};

# Must return the reference
$config;
__END__
