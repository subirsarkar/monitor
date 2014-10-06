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
          site=; parseConfig           SITE site
      sam_name=; parseConfig      SAM_NAME sam_name
      lcg_name=; parseConfig       LCG_NAME lcg_name
       basedir=; parseConfig       BASE_DIR basedir
        cltype=; parseConfig   CLUSTER_TYPE cltype
        batchv=; parseConfig  BATCH_VERSION batchv
        jobdir=; parseConfig    LSF_JOB_DIR jobdir
       acctdir=; parseConfig   LSF_ACCT_DIR acctdir
        webdir=; parseConfig        WEB_DIR webdir
   overview_fn=; parseConfig  OVERVIEW_FILE overview_fn
  happyface_fn=; parseConfig HAPPYFACE_FILE happyface_fn

# script template
for tmpl in $(echo overview.sh.tmpl accounting.sh.tmpl)
do
  file=$(echo $tmpl | sed -e 's#.tmpl##')
  sed -e s#BASE_DIR#$basedir#g \
      -e s#WEB_DIR#$webdir# $tmpl \
      -e s#OVERVIEW_FILE#$overview_fn#g \
      -e s#HAPPYFACE_FILE#$happyface_fn#g > ../bin/$file
  chmod a+x ../bin/$file
done
sed -e s#BASE_DIR#$basedir#g setup_lsfmon.tmpl > ../bin/setup_lsfmon

# cron template
for tmpl in $(echo overview.cron.tmpl accounting.cron.tmpl)
do
  file=$(echo $tmpl | sed -e 's#.tmpl##')
  sed -e s#BASE_DIR#$basedir#g $tmpl > ../cron/$file
done

# finally config.pl
sed -e s#SITE#$site#            \
    -e s#SAM_NAME#$sam_name#    \
    -e s#LCG_NAME#$lcg_name#    \
    -e s#BASE_DIR#$basedir#g    \
    -e s#CLUSTER_TYPE#$cltype#  \
    -e s#BATCH_VERSION#$batchv# \
    -e s#LSF_JOB_DIR#$jobdir#   \
    -e s#LSF_ACCT_DIR#$acctdir# \
    -e s#OVERVIEW_FILE#$overview_fn# \
    -e s#HAPPYFACE_FILE#$happyface_fn# \
    config.pl.tmpl > ../lib/LSF/config.pl

exit 0
