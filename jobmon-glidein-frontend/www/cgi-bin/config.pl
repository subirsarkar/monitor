#!/usr/bin/env perl

use strict;
use warnings;

our $cfg = 
{
           baseDir => q|/opt|,
             debug => 128,                                          # debug option                               
            domain => q|t2.ucsd.edu|,                             # the domain may be specified
         usedomain => 0,                                          # Should be 1 for backward compatibility 
  privacy_enforced => 1,
   has_jobpriority => 0,
            admins => {                                           # List the admin DNs
               cms => [
                 q|/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=sdutta/CN=389392/CN=Suchandra Dutta|,
                 q|/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=sarkar/CN=389393/CN=Subir Sarkar|,
                 q|/DC=org/DC=doegrids/OU=People/CN=Sanjay Padhi 496075|,
                 q|/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=belforte/CN=373708/CN=Stefano Belforte|,
                 q|/C=IT/O=INFN/OU=Personal Certificate/L=Trieste/CN=Stefano Belforte|,
                 q|/DC=org/DC=doegrids/OU=People/CN=Igor Sfiligoi 673872|,
                 q|/DC=org/DC=doegrids/OU=People/CN=Frank Wuerthwein 699373|
               ],
               site => [
                 q|/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=sarkar/CN=389393/CN=Subir Sarkar|
               ]
            }
};
$cfg->{dbcfg}     = qq|$cfg->{baseDir}/jobmon/etc/.my.cnf.monitor|; # mysql login detail
$cfg->{vomapfile} = qq|$cfg->{baseDir}/jobmon/data/mapping.db|;     # specify the location of the dn2vo mapfile

$cfg;                                                               # must return the ref
__END__
