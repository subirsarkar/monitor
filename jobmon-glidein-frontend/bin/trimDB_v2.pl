package main;

use strict;
use warnings;
use Collector::DBHandle;
use List::Util qw/max min/;

sub executeQuery
{
  my ($attr) = @_;
  my $dbh = $attr->{dbh};
  print STDERR q|Must pass a valid SQL SELECT statement| and return undef
    unless defined $attr->{query};
  
  my $query = $attr->{query};
  my $sth = $dbh->prepare($query);
  (defined $attr->{args}) ? $sth->execute(@{$attr->{args}}) : $sth->execute;

  my $list = [];
  return $list if defined $attr->{no_return};

  while (my $aref = $sth->fetchrow_arrayref) {
    my $item = $aref->[0];
    next unless defined $item;
    push @$list, $item;
  }
  $sth->finish;

  $list;
}
sub buildQuery
{
  my ($attr) = shift;
  my $verbose = $attr->{verbose} || 0;
  my $query  = $attr->{query_header};
  my $list   = $attr->{list};
  for (@$list) {
    $query .= q|?,|;
  }
  chop $query;
  $query .= q|)|;
  print join(" >>> ", q|buildQuery|, $query), "\n" if $verbose;
  $query;
}
sub find_diff
{
  my ($list1, $list2) = @_;
  my %dict1 = map { $_ => 1 } @$list1;
  my %dict2 = map { $_ => 1 } @$list2;
  my $list = [];
  for my $key (keys %dict2) {
    push @$list, $key unless exists $dict1{$key};
  }
  $list;
}
sub main {
  my ($ncount, $nlim, $verbose) = @_;
  $ncount = 1000 unless defined $ncount;
  $nlim = 10000 unless defined $nlim;
  $verbose = 1 unless defined $verbose;

  my $dbconn;
  eval {
    $dbconn = Collector::DBHandle->new;
  };
  $@ and die q|Failed to get a DB handle!|;

  my $dbh = $dbconn->dbh;
  my $query = buildQuery({query_header => q|SELECT DISTINCT(task_id) FROM jobinfo_summary WHERE status IN (|,
                                  list => ['R', 'Q'], 
                               verbose => 1});
  my $gTaskList = executeQuery({dbh => $dbh, query => $query, args => ['R', 'Q']});
  
  # get list of task_id
  $query = buildQuery({query_header => q|SELECT DISTINCT(task_id) FROM jobinfo_summary WHERE task_id NOT IN (|,
			       list => $gTaskList, 
                            verbose => 1});
  $query .= qq| LIMIT 10|;
  my $nTaskList = executeQuery({dbh => $dbh, query => $query, args => $gTaskList});

  # get list of jid
  $query = buildQuery({query_header => q|SELECT jid FROM jobinfo_summary WHERE task_id IN (|,
			       list => $nTaskList, 
                            verbose => 1});
  $query .= qq| LIMIT $nlim|;
  my @list = @{executeQuery({dbh => $dbh, query => $query, args => $nTaskList})};

  my $nitems = scalar @list;
  warn q|>>> No action needed!| and return unless $nitems;
  printf ">>> # of entries to remove: %d\n", $nitems;
  print join(',', @list), "\n" if $verbose;
  
  # task based deletion
  while ((my @slice = splice @list, 0, min(scalar(@list), $ncount))) {
    for my $tbl (qw/jobinfo_summary jobinfo_timeseries/) {
      printf qq|>>> Deleting %d out of %d entries from %s\n|, scalar @slice, $nitems, $tbl; 
  
      # trim jobinfo_summary
      my $query = buildQuery({query_header => qq|DELETE FROM $tbl WHERE jid IN (|,
	  		              list => \@slice,
                                   verbose => $verbose});
      executeQuery({dbh => $dbh, query => $query, args => \@slice, no_return => 1});

      # trim jobinfo_timeseries
      #$query = buildQuery({query_header => q|DELETE FROM jobinfo_timeseries WHERE jid IN (|,
      #		                   list => \@slice});
      #executeQuery({dbh => $dbh, query => $query, args => \@slice, no_return => 1});
    }
    $nitems = scalar @list;
  }

  print ">>> Now synchronize the two tables\n";
  my $jidListSummary    = executeQuery({dbh => $dbh, query => q|SELECT DISTINCT(jid) FROM jobinfo_summary|});
  my $jidListTimeSeries = executeQuery({dbh => $dbh, query => q|SELECT DISTINCT(jid) FROM jobinfo_timeseries|});
  my $nlist = find_diff($jidListSummary, $jidListTimeSeries);
  
  $nitems = scalar @$nlist;
  while ((my @slice = splice @$nlist, 0, min(scalar(@$nlist), $ncount))) {
    # trim jobinfo_timeseries
    printf qq|>>> Deleting %d out of %d entries from jobmon_timeseries\n|, scalar @slice, $nitems; 

    my $query = buildQuery({query_header => q|DELETE FROM jobinfo_timeseries WHERE jid IN (|,
      		                    list => \@slice});
    executeQuery({dbh => $dbh, query => $query, args => \@slice, no_return => 1});
    $nitems = scalar @$nlist;
  }
}
main;
__END__
