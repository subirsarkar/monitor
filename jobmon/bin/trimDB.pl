package main;

use strict;
use warnings;
use Collector::DBHandle;

sub main
{
  my $days = shift || 30;
  
  my $dbconn = new Collector::DBHandle;
  my $dbh = $dbconn->dbh;
  my $timestamp = time() - $days * 24 * 60 * 60;
  my $query = qq|SELECT jid FROM jobinfo_summary WHERE status='E' AND (end=-1 OR end<?)|;
  my $sth = $dbh->prepare($query);
  $sth->execute($timestamp);
  
  # get list of JIDs
  my @list = ();
  while ( my $aref = $sth->fetchrow_arrayref() ) {
    push @list, $aref->[0];
  }
  $sth->finish;
  my $nitems = scalar @list;
  warn qq|No action needed!| and return unless $nitems;
  print "Items: ", $nitems, "\n";
  print join(',', @list), "\n";
  
  # trim jobinfo_summary
  $query = qq|DELETE FROM jobinfo_summary WHERE status='E' AND (end=-1 OR end<?)|;
  $sth = $dbh->prepare($query);
  $sth->execute($timestamp);
  $sth->finish;
  
  # trim jobinfo_timeseries
  $query = qq|DELETE from jobinfo_timeseries WHERE jid=|. join (" OR jid=", map { '?' } @list);
  $sth = $dbh->prepare($query);
  $sth->execute(@list);
  $sth->finish;
}
my $days = shift || 30;
main($days);
__END__
