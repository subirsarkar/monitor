#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw/min max/;
use LSF::Overview;
use LSF::JobList;

sub main
{
  # Find (overall,user,ce,group,host,dn) jobs
  my $jobs = LSF::JobList->new;
  my $joblist = $jobs->list; # returns a hash reference
  my @jList = sort keys %$joblist;

  # Build (JID,DN) map
  my $filemap = LSF::Overview->filemap;
  my $verbose = 0;
  my $dmap = LSF::Overview->buildMap({
    jidList => \@jList,
    filemap => $filemap,
    verbose => $verbose
  });

  printf "%12s%10s%10s%12s%8s%12s%8s %-s\n", 
    q|JID|, q|user|, q|CE|, q|host|, q|cputime|, q|walltime|, q|cpueff|, q|DN|;
  while ( my ($jx,$job) = each %$joblist ) {
    my $status = $job->STATUS;
    next if $status eq 'U';

    my $jid   = $job->JID;
    my $user  = $job->USER;
    my $ce    = $job->UI_HOST;
    my $group = $job->GROUP;
    my $host  = $job->EXEC_HOST || '?';

    # The following may not be clean enough; for the same user we should try to
    # avoid setting the same over and over again
    my $dn = $dmap->{$jid} || q|local-|.$user;
    $job->SUBJECT($dn);
    if ($status eq 'R') {
      my $cputime  = $job->CPUTIME  || 0.0;
      my $walltime = $job->WALLTIME || 0.0;
      my $ratio = min 1, (($walltime>0) ? $cputime/$walltime : 0);

      printf "%12d%10s%10s%12s%8d%12d%8.2f %s\n", $jid, $user, $ce, $host, $cputime, $walltime, $ratio*100, $dn
        if ($group eq 'cms' and ($walltime > 100000 && $ratio < 0.01));
    }
  }
}
main;
__END__
