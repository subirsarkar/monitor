#!/bin/sh
#set -o nounset

# Update Perl library path
APPDIR=/opt/jobmon
export JOBMON_CONFIG_DIR=$APPDIR/etc/Collector
if [ -z PERL5LIB ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi
[ -r /etc/profile.d/lsf.sh ] && source /etc/profile.d/lsf.sh
[ -r /etc/profile.d/globus.sh ] && source /etc/profile.d/globus.sh
[ -r /etc/profile.d/edg.sh ]    && source /etc/profile.d/edg.sh

# Now the executable
program=$APPDIR/bin/gridinfoCache_daemon.pl
[ -r $program ] && perl $program

exit $?
