#!/bin/sh
set -o nounset

# prepare the sql script 
# v1.2 30/05/2013 - Subir

PROGNAME=$(basename $0)
DIRNAME=$(dirname $0)

source $DIRNAME/common.sh

function usage
{
  cat <<EOF
Usage: $PROGNAME <options>

where options are:
  -b|--basedir       Base directory (D=/opt)
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
   jid        VARCHAR(64) NOT NULL PRIMARY KEY,
   status     CHAR(4)     NOT NULL,
   user       VARCHAR(16) NOT NULL,
   qtime      INT(10)     NOT NULL,
   queue      VARCHAR(16),
   ugroup     VARCHAR(16),
   acct_group VARCHAR(16),
   subject    VARCHAR(256),
   task_id    VARCHAR(256),
   grid_id    VARCHAR(128),
   exec_host  VARCHAR(64),
   rb         VARCHAR(64),
   ceid       VARCHAR(128),
   start      INT(10),
   end        INT(10),
   cputime    MEDIUMINT(7), 
   walltime   MEDIUMINT(7),
   mem        MEDIUMINT,
   vmem       MEDIUMINT,
   diskusage  MEDIUMINT,
   ex_st      MEDIUMINT(7),
   timeleft   MEDIUMINT(7),
   role       VARCHAR(255),
   grid_site  VARCHAR(15),
   jobdesc    VARCHAR(255),
   statusbit  MEDIUMINT(7),
   rank       SMALLINT(6),
   priority   MEDIUMINT(7)
);
describe jobinfo_summary;
CREATE TABLE jobinfo_timeseries
(
   jid        VARCHAR(64) NOT NULL PRIMARY KEY,
   timestamp  MEDIUMTEXT,
   mem        MEDIUMTEXT,
   vmem       MEDIUMTEXT,
   cpuload    MEDIUMTEXT,
   cpufrac    MEDIUMTEXT,
   diskusage  MEDIUMTEXT
);
describe jobinfo_timeseries;
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
GRANT ALL ON monitor.* TO '$user'@'$dbnode' IDENTIFIED BY '$pass';
GRANT ALL ON monitor.* TO '$user'@'$dbnode.$domain' IDENTIFIED BY '$pass';
EOF

# CE
ceList=; parseConfig CE_LIST $basedir ceList
[ $verbose -gt 0 ] && echo $ceList
parseConfig CE_USER     $basedir user
parseConfig CE_PASSWORD $basedir pass
[ "$pass" != "" ] || readPassword pass
for ce in $(echo $ceList | sed -e "s/,/ /g")
do
cat <<EOF
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO '$user'@'$ce' IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_summary TO '$user'@'$ce.$domain' IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO '$user'@'$ce' IDENTIFIED BY '$pass';
GRANT SELECT,INSERT,UPDATE ON monitor.jobinfo_timeseries TO '$user'@'$ce.$domain' IDENTIFIED BY '$pass';
EOF
done

# Web server; hopefully will be on the same domain as the DB Server
server=; parseConfig WEB_SERVER $basedir server
parseConfig MONITOR_USER $basedir user
parseConfig MONITOR_PASSWORD $basedir pass
cat <<EOF
GRANT SELECT ON monitor.* TO '$user'@'$server' IDENTIFIED BY '$pass';
GRANT SELECT ON monitor.* TO '$user'@'$server.$domain' IDENTIFIED BY '$pass';
FLUSH PRIVILEGES;
EOF

# Show the privileges
cat <<EOF
use mysql;
select user,host,password from user;
EOF

exit 0
