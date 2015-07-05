#!/bin/sh
set -o nounset

tryagain=1

RHOST=phedex.pi.infn.it
TMPFILE=/var/www/html/ftsmon/test.xml.1
FNLFILE=/var/www/html/ftsmon/test.xml

# First of all check if the remote machine is up, if not give up
ping -c 5 $RHOST 1> /dev/null 2> /dev/null
if [ "$?" -ne 0 ]; then
  echo $RHOST does not respond, exiting ....
  exit 1
fi

# Now onto real task
while [ $tryagain -eq 1 ]
do
  scp -q -p phedex@$RHOST:/home/phedex/monitor/bin/test.xml $TMPFILE
  if tail -5 $TMPFILE | grep '</JobList>' > /dev/null
  then
    tryagain=0
  else
    echo ERROR. The source file is being created .. try again in a while
    sleep 10
  fi
done

cp $TMPFILE $FNLFILE
chmod 644 $FNLFILE

# Update Perl library path
LIBDIR=/var/www/cgi-bin/ftsmon
if [ -z PERL5LIB ]; then
  export PERL5LIB=$LIBDIR:$PERL5LIB
else
  export PERL5LIB=$LIBDIR
fi
# update local DB
perl -w /var/www/cgi-bin/ftsmon/store.pl

echo -- Last Updated: `date` ---
exit 0
