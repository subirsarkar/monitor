#!/bin/sh
set -o nounset

# prepare the sql script 
# v1.1 11/07/2009 - Subir

PROGNAME=$(basename $0)
DIRNAME=$(dirname $0)

source $DIRNAME/common.sh

function usage
{
  cat <<EOF
Usage: $PROGNAME <options>

where options are:
  -b|--basedir       Base directory(D=/opt)
  -v|--verbose       Turn on debug statements (D=false)
  -h|--help          This message

  example: $PROGNAME --verbose
EOF

  exit 1
}

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

cat <<EOF
CREATE DATABASE monitor;
use monitor;
CREATE TABLE jobinfo_summary
(
   jid        INT UNSIGNED NOT NULL PRIMARY KEY,
   user       VARCHAR(16)           NOT NULL,
   ugroup     VARCHAR(16)           NOT NULL,
   queue      VARCHAR(16)           NOT NULL,
   jobname    VARCHAR(255),
   qtime      INT(10),
   start      INT(10),
   end        INT(10),
   status     CHAR(4),
   cputime    MEDIUMINT(7), 
   walltime   MEDIUMINT(7),
   mem        MEDIUMINT,
   vmem       MEDIUMINT,
   diskusage  MEDIUMINT,
   exec_host  VARCHAR(128),
   ex_st      MEDIUMINT(7),
   ceid       VARCHAR(128),
   subject    VARCHAR(255),
   grid_id    VARCHAR(128),
   rb         VARCHAR(128),
   timeleft   MEDIUMINT(7),
   role       VARCHAR(255),
   jobdesc    VARCHAR(255),
   statusbit  MEDIUMINT(7),
   rank       SMALLINT(6),
   priority   MEDIUMINT(7)
);
describe jobinfo_summary;
CREATE TABLE jobinfo_timeseries
(
   jid        INT UNSIGNED NOT NULL PRIMARY KEY,
   timestamp  MEDIUMTEXT,
   mem        MEDIUMTEXT,
   vmem       MEDIUMTEXT,
   cpuload    MEDIUMTEXT,
   cpufrac    MEDIUMTEXT,
   diskusage  MEDIUMTEXT
);
describe jobinfo_timeseries;
CREATE TABLE wninfo 
(
  type      VARCHAR(16)   NOT NULL,
  name      VARCHAR(64)   NOT NULL PRIMARY KEY,
  size      INT UNSIGNED  NOT NULL,
  timestamp INT UNSIGNED,
  data      MEDIUMBLOB    NOT NULL
);
describe wninfo;
EOF

# Find domain
domain=; parseConfig DOMAIN $basedir domain

# this could be an administrator user other than root
# ideally on the mysql server host
dbnode=; parseConfig DB_SERVER      $basedir dbnode
  user=; parseConfig ADMIN_USER     $basedir user
  pass=; parseConfig ADMIN_PASSWORD $basedir pass
[ "$pass" != "" ] || readPassword pass
cat <<EOF
GRANT ALL ON monitor.* TO $user@$dbnode IDENTIFIED BY '$pass';
GRANT ALL ON monitor.* TO $user@$dbnode.$domain IDENTIFIED BY '$pass';
EOF

# WN
wnPattList=; parseConfig WN_PATTERN $basedir wnPattList
[ $verbose -gt 0 ] && echo $wnPattList
parseConfig WN_USER     $basedir user
parseConfig WN_PASSWORD $basedir pass
[ "$pass" != "" ] || readPassword pass
for patt in $(echo $wnPattList | sed -e "s/,/ /g")
do
cat <<EOF
GRANT SELECT,INSERT,UPDATE ON monitor.wninfo TO $user@'$patt%' IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.wninfo TO $user@'$patt%.$domain' IDENTIFIED BY '$pass';
EOF
done

# CE
ceList=; parseConfig CE_LIST $basedir ceList
[ $verbose -gt 0 ] && echo $ceList
parseConfig CE_USER     $basedir user
parseConfig CE_PASSWORD $basedir pass
[ "$pass" != "" ] || readPassword pass
for ce in $(echo $ceList | sed -e "s/,/ /g")
do
cat <<EOF
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO $user@$ce IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO $user@$ce.$domain IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO $user@$ce IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO $user@$ce.$domain IDENTIFIED BY '$pass';
GRANT SELECT ON monitor.wninfo TO $user@$ce IDENTIFIED BY '$pass';
GRANT SELECT ON monitor.wninfo TO $user@$ce.$domain IDENTIFIED BY '$pass';
EOF
done

# Web server; hopefully will be on the same domain as the DB Server
server=; parseConfig WEB_SERVER $basedir server
parseConfig MONITOR_USER $basedir user
parseConfig MONITOR_PASSWORD $basedir pass
cat <<EOF
GRANT SELECT ON monitor.* TO $user@$server IDENTIFIED BY '$pass';
GRANT SELECT ON monitor.* TO $user@$server.$domain IDENTIFIED BY '$pass';
FLUSH PRIVILEGES;
EOF

# Show the privileges
cat <<EOF
use mysql;
select user,host,password from user;
EOF

exit 0
