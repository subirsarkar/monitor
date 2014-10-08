#!/bin/sh
set -o nounset

function readPassword
{
  stty_orig=`stty -g`
  echo Enter password:
  stty -echo
  read secret
  stty $stty_orig
  eval "$1=$secret"
}
# Adapted(!) from a dCache function
function parseConfig 
{
  key=$1
  basedir=$2
  cfg_file=$basedir/jobmon/install/jobmon.cfg
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
  [ "$result" != "" ] || return 1

  eval "$3=$result"

  return 0
}
function my_cnf
{
  basedir=$1
  user=$2
  pass=
  [ $# -gt 2 ] && pass=$3
  cfg_tmpl=$basedir/jobmon/install/.my.cnf.tmpl
  [ -r $cfg_tmpl ] || { echo ERROR. $cfg_tmpl not found, stopped!; return 1; }
  cfg=$basedir/jobmon/etc/.my.cnf

  server=; parseConfig DB_SERVER $basedir server
  domain=; parseConfig DOMAIN    $basedir domain
  server=$server'.'$domain
  sed -e "s/DBUSER/$user/" \
      -e "s/DBPASS/$pass/" \
      -e "s/DBSERVER/$server/" $cfg_tmpl > $cfg

  return 0
}
function toLower {
  echo $1 | tr "[:upper:]" "[:lower:]" 
} 
function toUpper {
  echo $1 | tr "[:lower:]" "[:upper:]" 
} 
