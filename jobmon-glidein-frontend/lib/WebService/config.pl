#!/usr/bin/env perl

use strict;
use warnings;

our $cfg = 
{
           baseDir => qq|/opt|,
             debug => 0,                                          # debug option                               
            domain => qq|sns.it|,                                 # the domain may be specified
         usedomain => 0,                                          # Should be 1 for backward compatibility 
  privacy_enforced => 0,
   has_jobpriority => 1,
            nlines => 600,                                        # _not_ used
      private_tabs => [q|jobdir|, q|workdir|, q|log|, q|error|],
          vo2group => {
                        q|glast.org| => q|glast|
                      },
         ugroup2vo => {
                           cmsit => q|cms|,
                         theodip => q|theophys|,
                        theoinfn => q|theophys|
                      },
            admins => {                                           # List the admin DNs
               site => [
                 q|/C=IT/O=INFN/OU=Personal Certificate/L=Pisa/CN=Subir Sarkar|
               ],
               cms => [
                 q|/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=sarkar/CN=389393/CN=Subir Sarkar|
               ]
            }
};
$cfg->{dbcfg}     = qq|$cfg->{baseDir}/jobmon/etc/.my.cnf|;       # mysql login detail
$cfg->{vomapfile} = qq|$cfg->{baseDir}/jobmon/data/mapping.db|;   # specify the location of the dn2vo mapfile

$cfg;                                                             # must return the ref
__END__
