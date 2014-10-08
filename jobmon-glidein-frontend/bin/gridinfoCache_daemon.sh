#!/bin/sh
#set -o nounset

# Update Perl library path
APPDIR=/opt/jobmon
export JOBMON_CONFIG_DIR=$APPDIR/etc/Collector
if [ -n "$PERL5LIB" ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi
[ -r /etc/profile.d/grid-env.sh ] && source /etc/profile.d/grid-env.sh

# Now the executable
program=$APPDIR/bin/gridinfoCache_daemon.pl
[ -r $program ] && perl $program

exit $?
