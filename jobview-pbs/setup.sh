#!/bin/sh
#set -o nounset

BASEDIR=/opt/jobview
if [ -z PERL5LIB ]; then
  export PERL5LIB=$BASEDIR/lib:$PERL5LIB
else
  export PERL5LIB=$BASEDIR/lib
fi
