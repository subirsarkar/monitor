#!/bin/sh
set -o nounset

cfg_file=./app.cfg

# Adapted(!) from a dCache function
function parseConfig 
{
  key=$1
  result=$(cat $cfg_file 2>/dev/null | \
  perl -e "
    while (<STDIN>) { 
       s/\#.*$// ;                        # Remove comments
       s/\s*$// ;                         # Remove trailing space
       if ( s/^\s*${key}\s*=*\s*//i ) {   # Remove key and equals
          print;                          # Print if key found
          last;                           # Only use first appearance
       }
    }
  ")
  eval "$2=$result"
  return 0
}

function toLower {
  echo $1 | tr "[:upper:]" "[:lower:]" 
} 
function toUpper {
  echo $1 | tr "[:lower:]" "[:upper:]" 
} 

# Read app.cfg
   site_domain=; parseConfig      SITE_DOMAIN site_domain
     site_name=; parseConfig        SITE_NAME site_name
       basedir=; parseConfig         BASE_DIR basedir
        batchv=; parseConfig    BATCH_VERSION batchv
        webdir=; parseConfig          WEB_DIR webdir
   overview_fn=; parseConfig    OVERVIEW_FILE overview_fn
  happyface_fn=; parseConfig   HAPPYFACE_FILE happyface_fn
    cron_email=; parseConfig       CRON_EMAIL cron_email
   condor_coll=; parseConfig CONDOR_COLLECTOR condor_coll

# script template
sed -e s#BASE_DIR#$basedir#g            \
    -e s#WEB_DIR#$webdir#               \
    -e s#OVERVIEW_FILE#$overview_fn#g   \
    -e s#HAPPYFACE_FILE#$happyface_fn#g \
    overview.sh.tmpl > ../bin/overview.sh
chmod a+x ../bin/overview.sh

# script that creates the RRD files
sed -e s#BASE_DIR#$basedir#g create_rrd.sh.tmpl > ../bin/create_rrd.sh
chmod a+x ../bin/create_rrd.sh

# jobview setup
sed -e s#BASE_DIR#$basedir#g setup_jobview.tmpl > ../setup_jobview

# cron template
sed -e s#BASE_DIR#$basedir#g -e s#CRON_EMAIL#$cron_email# overview.cron.tmpl > ../cron/overview.cron

# finally config.pl
sed -e s#BASE_DIR#$basedir#g            \
    -e s#SITE_DOMAIN#$site_domain#      \
    -e s#SITE_NAME#$site_name#          \
    -e s#BATCH_VERSION#$batchv#         \
    -e s#CONDOR_COLLECTOR#$condor_coll# \
    -e s#OVERVIEW_FILE#$overview_fn#g   \
    -e s#HAPPYFACE_FILE#$happyface_fn#g \
    config.pl.tmpl > ../lib/config.pl

exit 0
