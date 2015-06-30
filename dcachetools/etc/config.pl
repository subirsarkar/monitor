use strict;
use warnings;

use constant MINUTE => 60; 
use constant HOUR   => 60 * MINUTE;
use constant DAY    => 24 * HOUR;

my $dbname = 
{
     pnfs => q|companion|,
  chimera => q|chimera|
};

our $cfg = 
{
           verbose => 0,
           baseDir => q|/opt/dcachetools|,
            domain => q|pi.infn.it|,
              node => q|T2_IT_Pisa|,
              site => q|INFN-PISA|,
          pnfsroot => q|/pnfs/pi.infn.it/data|,
         namespace => q|pnfs|,
             admin => {
                        node => q|cmsdcache|, 
                        port => 22223,
                        user => q|admin|,
                       debug => 0, 
                       proto => q|API|,
                    identity => q|/root/.ssh/identity|,  
                     timeout => 600, 
                       delay => 1000,  # microseconds
               discard_error => 1
             },
       PoolManager => {activityMarker => 1000},
          skip_vos => ['biomed'],
  has_info_service => 1,
       mover_types => ['default','wan']
};
$cfg->{dbconfig} = 
{
   dbd => q|Pg|,
  name => $dbname->{$cfg->{namespace}},
  host => q|localhost|,
  user => q|srmdcache|,
  pass => q|srmdcache|
};
$cfg->{cache_dir} = qq|$cfg->{baseDir}/cache|;
$cfg->{webserver} = $cfg->{admin}{node};
$cfg->{lookup_remotegsiftp} = 0;
$cfg->{resourceDB} = 
{
   server => qq|$cfg->{baseDir}/db/server.db|,
  gridftp => qq|$cfg->{baseDir}/db/gridftp.db|
};

# --------------------
# Section [RRD]
# --------------------
$cfg->{rrd} = 
{
     verbose => 0, 
     rrdtool => q|/usr/bin/rrdtool|,
    location => qq|$cfg->{baseDir}/db|,
     comment => $cfg->{site},
          db => q|global.rrd|,
        step => 300,
       width => 300,
      height => 120,
  timeSlices =>
  {
     lhour => [q|lhour|,      HOUR,  q|hour|],
     lday  => [q|lday|,        DAY,  q|day|],
     lweek => [q|lweek|,   7 * DAY,  q|week|],
    lmonth => [q|lmonth|, 30 * DAY,  q|month|],
     lyear => [q|lyear|, 365 * DAY,  q|year|]
  },
  supportedVOs => ['cms', 'theophys']
};

# Must return the reference
$cfg;
