#!/bin/sh
set -o nounset

# prepare/deploy config.pl 
# v1.1 11/07/2009 - Subir Sarkar

PROGNAME=$(basename $0)
DIRNAME=$(dirname $0)

source $DIRNAME/common.sh

function usage
{
  cat <<EOF
Usage: $PROGNAME installtype <options>
installtype: ce,wn,webservice - must be specified

where options are:
  -b|--basedir       Base directory (D=/opt)
  -v|--verbose       Turn on debug statements (D=false)
  -h|--help          This message

  example: $PROGNAME webservice --verbose
EOF

  exit 1
}

[ $# -gt 0 ] || usage

# Initialise, get the disk name
installtype=$1
shift

echo $installtype | grep "^-" >/dev/null
[ $? -gt 0 ] || usage

basedir=/opt
let "verbose = 0"
while [ $# -gt 0 ]; do
  case $1 in
    -b | --basedir )        shift
                            basedir=$1
                            ;;
    -v | --verbose )        let "verbose = 1"
                            ;;
    -h | --help )           usage
                            ;;
     * )                    usage
                            ;;
  esac
  shift
done

# Read jobmon.cfg
domain=; parseConfig DOMAIN $basedir domain
if [ "$installtype" == "webservice" ]; then
  echo ">>> preparing web service config.pl"
  jobprio=0; parseConfig JOB_PRIORITY $basedir jobprio
  CONFIG=$basedir/jobmon/lib/WebService/config.pl
  CONFIG_TMPL=$basedir/jobmon/install/config_webservice.pl.tmpl
  sed -e s#BASEDIR#$basedir#g     \
      -e s#DOMAIN#$domain#        \
      -e s#JOB_PRIORITY#$jobprio# \
        $CONFIG_TMPL > $CONFIG

  echo ">>> preparing monitor.cgi"
  CGI=$basedir/jobmon/bin/monitor.cgi
  CGI_TMPL=$basedir/jobmon/install/monitor.cgi.tmpl
  sed -e s#BASEDIR#$basedir#g $CGI_TMPL > $CGI
  chmod 755 $CGI

  for script in $(echo voUserList.sh launch_voUserList.sh); do
    echo ">>> prepare $script"
    SCRIPT=$basedir/jobmon/bin/$script
    sed -i -e s#BASEDIR#$basedir#g $SCRIPT
  done  

  echo ">>> installing voUserList.cron"
  CRON=/etc/cron.d/voUserList.cron
  CRON_TMPL=$basedir/jobmon/install/voUserList.cron.tmpl
  sed -e s#BASEDIR#$basedir#g $CRON_TMPL > $CRON
  service crond restart
  touch /etc/crontab

else  
  # ce,wn
  # Collector config
          site=; parseConfig           SITE $basedir site
          lrms=; parseConfig           LRMS $basedir lrms
  lrms_version=; parseConfig   LRMS_VERSION $basedir lrms_version
        jobdir=; parseConfig        JOB_DIR $basedir jobdir
       acctdir=; parseConfig ACCOUNTING_DIR $basedir acctdir
   gridmap_dir=; parseConfig    GRIDMAP_DIR $basedir gridmap_dir
     ce_string=; parseConfig        CE_LIST $basedir ce_string
     master_ce=; parseConfig      MASTER_CE $basedir master_ce
   
  ceList=
  if [ "$ce_string" != "" ]; then
    ceList=$(echo $ce_string | sed -e "s/,/','/g")
    ceList="'"$ceList"'"
  fi
  CONFIG_DIR=$basedir/jobmon/etc/Collector
  DEFAULT_CONFIG_DIR=$basedir/jobmon/lib/Collector
  mkdir -p $CONFIG_DIR
  CONFIG_TMPL=$basedir/jobmon/install/config_collector.pl.tmpl
  sed -e s#BASEDIR#$basedir#g         \
      -e s#SITE#$site#                \
      -e s#DOMAIN#$domain#            \
      -e s#LRMS#$lrms#                \
      -e s#RELEASE#$lrms_version#     \
      -e s#JOBDIR#$jobdir#            \
      -e s#ACCOUNTING_DIR#$acctdir#   \
      -e s#GRIDMAP_DIR#$gridmap_dir#  \
      -e s#LIST_OF_CE#$ceList#        \
      -e s#MASTER_CE#$master_ce#      \
         $CONFIG_TMPL > $CONFIG_DIR/config.pl
  cp $CONFIG_DIR/config.pl $DEFAULT_CONFIG_DIR/config.pl
fi

exit 0
