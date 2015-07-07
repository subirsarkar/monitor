#!/bin/sh
#set -o nounset

RHOST=phedex.pi.infn.it
CERTDIR=$HOME/cert
RECIPIENTS="subir.sarkar@cern.ch"

function isHostAlive() {
  nt=$1
  ping -c $nt $RHOST 1> /dev/null 2> /dev/null
  if [ "$?" -ne 0 ]; then
    echo $RHOST does not respond, exiting ....
    return 1
  fi
  return 0
}

function getTar() {
  let "nt = $1"
  let "kt = 0"
  scp -F $HOME/.ssh/ssh_config phedex@$RHOST:~/gridcert/mytar.tgz $CERTDIR/; let "err = $?"
  while [ $err -ne 0 ]
  do
     echo Could not copy the tar file successfully! trying again in 30 secs
     let "kt += 1"
     if [ $kt -eq $nt ]; then
       echo Bailing out of scp after $nt attempts.....
       return 2
     fi
     sleep 30 
     scp -F $HOME/.ssh/ssh_config phedex@$RHOST:~/gridcert/mytar.tgz $CERTDIR/; let "err = $?"
  done
  return 0
}

function checkmd5sum() {
  cd $CERTDIR
  tar xzvf mytar.tgz
  csum1=`head -1 proxy_r.cert.md5sum | awk '{print $1}'`
  csum2=`md5sum proxy_r.cert | awk '{print $1}'`
  if [ "$csum1" != "$csum2" ]; then 
    echo md5sum do not match! Expected=$csum1, Got=$csum2
    return 3
  fi
  return 0
}

function showInfo() {
  cd $CERTDIR
  cp proxy_r.cert proxy.cert
  source /afs/cern.ch/project/gd/LCG-share/sl3/etc/profile.d/grid_env.sh
  export X509_USER_PROXY=$CERTDIR/proxy.cert
  voms-proxy-info -all
  return $?
}

# First of all check if the remote machine is up, if not give up
isHostAlive 10
status=$?
if [ $status -ne 0 ]; then 
  echo "$RHOST does not respond" | \
    mail -s "ALARM. `date`: Proxy renewal on cmstkstorage Failed!" $RECIPIENTS
  exit $status; 
fi

# Now get the tarball with the refreshed proxy
getTar 10
status=$?
if [ $status -ne 0 ]; then 
  echo "could not copy tarball from $RHOST" | \
    mail -s "ALARM. `date`: Proxy renewal on cmstkstorage Failed!" $RECIPIENTS
  exit $status; 
fi

# now check integrity
checkmd5sum
status=$?
if [ $status -ne 0 ]; then 
  echo "md5sum mismatch" | \
    mail -s "ALARM. `date`: Proxy renewal on cmstkstorage Failed!" $RECIPIENTS
  exit $status; 
fi

# We are done; show voms-proxy-info
showInfo
status=$?
echo -- Last updated at `date` --
echo ---
exit $status
