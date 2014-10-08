#!/bin/sh
##set -o nounset

[ -r /etc/profile.d/grid-env.sh ] && source /etc/profile.d/grid-env.sh

baseDir=BASEDIR

# Update Perl library path
APPDIR=$baseDir/jobmon
if [ -n "$PERL5LIB" ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi

# refresh host proxy
grid-proxy-init -certdir /etc/grid-security/ \
                -cert    /etc/grid-security/hostcert.pem \
                -key     /etc/grid-security/hostkey.pem
grid-proxy-info -all

# Now the executable
program=$APPDIR/bin/voUserList.pl
[ -r $program ] && perl -w $program $baseDir

exit $?
