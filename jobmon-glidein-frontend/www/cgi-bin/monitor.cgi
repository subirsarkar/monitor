#!/bin/sh
set -o nounset

appdir=/opt/jobmon
# Now the executable
program=$appdir/bin/monitor.pl
[ -r $program ] && perl -T -Mlib=$appdir/lib $program

exit $?
