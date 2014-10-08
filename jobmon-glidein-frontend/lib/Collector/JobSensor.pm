package Collector::JobSensor;

use strict;
use warnings;
use Carp;

use DBI;
use Net::Domain qw/hostfqdn hostname/;
use List::Util qw/min max/;

use Collector::Util qw/trim avg show_message/;
use Collector::ConfigReader;
use Collector::JobStatus;
use Collector::DBHandle;

$Collector::JobSensor::VERSION = q|1.0|;

use constant _VSEP => q| |;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  my $config = Collector::ConfigReader->instance()->config;

  bless {
    config => $config,
    dbconn => {}
  }, $class;
}

sub normalize
{
  my ($list, $value) = @_;
  return $value if defined $value;
  return 0.0 unless defined $list;

  my $v = 0.0;
  eval {
    $v = avg([split /\s+/, trim $list]);
  };
  return $v;
}
sub dbConnected
{
  my $self = shift;
  $self->{dbconn} = Collector::DBHandle->new;

  return 0 unless defined $self->{dbconn}->dbh;
  return 1;
}
sub correctState
{
  my ($self, $jStatus, $states) = @_;
  my $config  = $self->{config};
  my $verbose = $config->{verbose} || 0;

  # Hostname is needed in order to select jobs only for this CE 
  my $ce = lc hostfqdn(); # use quotemeta in case $ce is used inside a regular expression

  my $query = q|SELECT jid,status FROM jobinfo_summary WHERE (|;
  for my $state (@$states) {
    $query .= qq|OR status="$state" |;
  }
  $query =~ s/OR//;
  $query .= q|)|; # must close the parenthesis
  print STDERR $query, "\n";

  my $dbh = $self->{dbconn}->dbh;
  my $sthq = $dbh->prepare($query);
  my $sthu = $dbh->prepare(q|UPDATE jobinfo_summary SET status=? WHERE jid=?|);

  $sthq->execute;
  my %jidList = map { $_ => 1 } $jStatus->joblist;
  while (my $aref = $sthq->fetchrow_arrayref()) {
    my ($jid, $status_db) = ($aref->[0], $aref->[1]);
    next if defined $jidList{$jid};
    ##print STDERR "JobSensor::correctState(): JID=$jid,DBSTATUS=$status_db,TO_STATUS=U\n";
    $sthu->execute('U', $jid);
  }
  $sthq->finish;
  $sthu->finish;
}

sub getBitWord
{
  my ($walltime, $cputime, $cpuload, $timeleft) = @_;
  my $bitw = 0;
  eval {
    if ($walltime > 1800) {  # 30 minutes
      $bitw |= (1 << 0) if $cputime/$walltime < 0.01;
      $bitw |= (1 << 1) if $cputime/$walltime < 0.3;
      my @list = (split /\s+/, trim $cpuload);
      @list = grep { $_ ne '?' } @list;
      if (scalar @list > 3) {
        my ($nload_flag, $hload_flag) = (0,0);
        for (@list[-3,-2,-1]) {
          ++$nload_flag if $_ < 0.01;
          ++$hload_flag if $_ > 1.0;
        }
        $bitw |= (1 << 2) if $nload_flag; 
        $bitw |= (1 << 3) if $hload_flag; 
      }
    }
  };
  carp qq|JobSensor::getBitWord() failed becasue $@| if $@;
  $bitw |= (1 << 4) if (defined $timeleft and $timeleft < 1800);
  $bitw;
}
sub fetch
{
  my $self = shift;
  my $config = $self->{config};
  my $verbose = $config->{verbose} || 0;
  my $ce_reqd = $config->{ce_required} || 0;

  # select
  my $dbh = $self->{dbconn}->dbh;
  my $sthqa = $dbh->prepare(q|SELECT COUNT(jid) FROM jobinfo_summary WHERE jid=?|);
  my $sthqb = $dbh->prepare(
    q|SELECT status,exec_host,start,role,jobdesc,grid_id,rb,subject,ceid 
        FROM jobinfo_summary 
          WHERE jid=?|
  );
  my $sthqc = $dbh->prepare(
    q|SELECT timestamp,mem,vmem,cpuload,cpufrac,diskusage 
        FROM jobinfo_timeseries 
          WHERE jid=?|
  );

  # update
  my $sthua = $dbh->prepare(
    q|UPDATE jobinfo_summary SET cputime=?,walltime=?,mem=?,vmem=?,diskusage=?,statusbit=? WHERE jid=?|
  );
  my $sthub = $dbh->prepare(q|UPDATE jobinfo_summary SET end=?,ex_st=? WHERE jid=?|);
  my $sthuc = $dbh->prepare(q|UPDATE jobinfo_summary SET status=?,timeleft=? WHERE jid=?|);
  my $sthud = $dbh->prepare(q|UPDATE jobinfo_summary SET exec_host=?,start=? WHERE jid=?|);
  my $sthue = $dbh->prepare(q|UPDATE jobinfo_summary SET role=?,jobdesc=? WHERE jid=?|);
  my $sthuf = $dbh->prepare(q|UPDATE jobinfo_summary SET grid_id=?,rb=? WHERE jid=?|);
  my $sthug = $dbh->prepare(q|UPDATE jobinfo_summary SET ceid=?,grid_site=? WHERE jid=?|);
  my $sthuh = $dbh->prepare(q|UPDATE jobinfo_summary SET subject=? WHERE jid=?|);
  my $sthui = $dbh->prepare(
    q|UPDATE jobinfo_timeseries 
         SET timestamp=?,mem=?,vmem=?,cpuload=?,cpufrac=?,diskusage=? WHERE jid=?|
  );
  my $sthuj = $dbh->prepare(
    q|UPDATE jobinfo_summary SET mem=?,vmem=?,diskusage=?,statusbit=? WHERE jid=?|
  );
  my $sthuk = $dbh->prepare(q|UPDATE jobinfo_summary SET rank=?,priority=? WHERE jid=?|);

  # insert
  my $sthia = $dbh->prepare(
    q|INSERT INTO jobinfo_summary 
       (jid,user,ugroup,acct_group,queue,task_id,qtime,start,end,status,cputime,walltime,
          exec_host,ex_st,ceid,subject,grid_id,rb,timeleft,role,jobdesc,grid_site,rank,priority)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)|
  );
  my $sthib = $dbh->prepare(
    q|INSERT INTO jobinfo_timeseries (jid) VALUES(?)|
  );
  
  # get job status
  my $js = Collector::JobStatus->new({ dbconn => $self->{dbconn} });

  # before proceeding look at Running and Queued entries in the DB
  # which somehow exited abnormally in between 2 iterations but could not be traced
  $self->correctState($js, ['R', 'Q']);

  my $info = $js->info;
  while ( my ($jid) = each %$info ) {
    my $user  = $js->USER($jid);
    my $qtime = $js->QTIME($jid);
    my $local_id = $js->LOCAL_ID($jid);

    # get values that will be needed to build the statusBit
    my $cputime  = $js->CPUTIME($jid)  || 0;
    my $walltime = $js->WALLTIME($jid) || 0;

    # cpu efficiency
    my $frac;
    eval {
      $frac = max $cputime*1.0/$walltime, 0.0;
    };
    $frac = 0.0 if $@;
    my $timeleft = $js->TIMELEFT($jid); 
    my $gridce   = $js->GRID_CE($jid);

    my $job_isready = (defined $user and defined $qtime) ? 1 : 0;
    $job_isready = 0 if ($ce_reqd and not defined $gridce); # optionally wait until the CEid is available

    # is the job already registered?
    $sthqa->execute($jid);
    my ($count) = $sthqa->fetchrow_array;
    if ($count > 0) {
      # jid found, we should update certain fields
      # first of all check if the job is still running
      $sthqb->execute($jid);
      my ($status_db, $exec_host, $start, $role, $jobdesc, $gridid, $rb, $subject, $ceid) 
        = $sthqb->fetchrow_array;
      next if $status_db eq 'E'; # job is already over, no need to update

      # in case any of role/jobdescription still unknown, try to store again
      $sthue->execute($js->ROLE($jid), $js->JOBDESC($jid), $jid) 
         unless (defined $role and defined $jobdesc);

      # similarly try for grid_id, ceid and subject separately
      $sthuf->execute($js->GRID_ID($jid), 
                      $js->RB($jid), $jid) unless (defined $gridid and defined $rb);
      $sthug->execute($gridce, $js->GRID_SITE($jid), $jid) unless defined $ceid;
      $sthuh->execute($js->SUBJECT($jid), $jid) unless defined $subject;

      # what is the current job status?
      my $status_now = $js->STATUS($jid);
      if ($status_now eq 'Q') {
        $sthuk->execute($js->RANK($jid), $js->PRIORITY($jid), $jid);
      }
      elsif ( ($status_now eq 'R') or (($status_db eq 'R') and ($status_now eq 'E')) ) {
        my $host = $js->EXEC_HOST($jid);
        print STDERR qq|jid=$jid,status_db=$status_db,status_now=$status_now,|.
                     qq|dbhost=$exec_host,host=$host\n| if $verbose;

        # find the current value of mem, vmem, cpuload, 
        # cpu-efficiency and disk-usage and append new values
        $sthqc->execute($jid);
        my ($timestamp, $mem, $vmem, $cpuload, $cpufrac, $diskusage) 
          = $sthqc->fetchrow_array;
        my ($c_mem, $c_vmem, $c_diskusage) 
          = ($js->MEM($jid) || 0, 
             $js->VMEM($jid) || 0,
             $js->DISKUSAGE($jid) || 0);
        my $n_mem       = normalize $mem, $c_mem;
        my $n_vmem      = normalize $vmem, $c_vmem;
        my $n_cpuload   = normalize $cpuload, $js->CPULOAD($jid);
        my $n_cpufrac   = normalize $cpufrac, $frac;
        $n_cpufrac      = sprintf qq|%7.5f|, $n_cpufrac;
        my $n_diskusage = normalize $diskusage, $c_diskusage;

        $mem       .= _VSEP.$n_mem;
        $vmem      .= _VSEP.$n_vmem;
        $cpuload   .= _VSEP.$n_cpuload;
        $cpufrac   .= _VSEP.$n_cpufrac;
        $diskusage .= _VSEP.$n_diskusage;
  
        # now prepare the status BIT word
        my $bitw = getBitWord($walltime, $cputime, $cpuload, $timeleft);

        # time difference from start
        my $stime = $start || $js->START($jid);
        my $timeseg = (defined $stime) ? time() - $stime : 0;
        $timestamp .= _VSEP.$timeseg;

        # update
        $sthua->execute($cputime, $walltime, max($c_mem, 0.0), 
                        max($c_vmem, 0.0), max($c_diskusage, 0.0), $bitw, $jid);
        $sthui->execute($timestamp, $mem, $vmem, $cpuload, $cpufrac, $diskusage, $jid);
        unless ( defined $exec_host and defined $start ) {
          my $wn = $js->EXEC_HOST($jid);
          $sthud->execute($wn, $js->START($jid), $jid);
        }
        $sthub->execute($js->END($jid), $js->EX_ST($jid), $jid) if $status_now eq 'E';
      }

      # the following must be updated for all jobs
      $sthuc->execute($status_now, $timeleft, $jid);
    }
    elsif ($job_isready) {
      my $host   = $js->EXEC_HOST($jid);
      my $status = $js->STATUS($jid);
      my $start  = $js->START($jid);
      $sthia->execute($jid,
                      $user,
                      $js->GROUP($jid),
                      $js->ACCT_GROUP($jid),
                      $js->QUEUE($jid),
                      $js->TASK_ID($jid),
                      $qtime,
                      $start,
                      $js->END($jid),
                      $status,
                      $cputime,
                      $walltime,
                      $host,
                      $js->EX_ST($jid),
                      $js->GRID_CE($jid),
                      $js->SUBJECT($jid),
                      $js->GRID_ID($jid),
                      $js->RB($jid),
                      $timeleft,
                      $js->ROLE($jid),
                      $js->JOBDESC($jid),
                      $js->GRID_SITE($jid),
                      $js->RANK($jid),
                      $js->PRIORITY($jid)
      );
      $sthib->execute($jid);
      if ($status eq 'R') {
        my $mem       = $js->MEM($jid) || 0.0;
        my $vmem      = $js->VMEM($jid) || 0.0;
        my $diskusage = $js->DISKUSAGE($jid) || 0.0;
        my $cpuload   = $js->CPULOAD($jid) || 0.0;
        my $bitw = getBitWord($walltime, $cputime, $cpuload, $timeleft);
        my $timestamp = time() - ($start || 0);
        $frac = sprintf qq|%7.5f|, $frac;

        $sthui->execute($timestamp, $mem, $vmem, $cpuload, $frac, $diskusage, $jid);
        $sthuj->execute($mem, $vmem, $diskusage, $bitw, $jid);
      }
    }
  }
  
  # We are done with this iteration, so close all the active handles
  $sthqa->finish;
  $sthqb->finish;
  $sthqc->finish;
  
  $sthua->finish;
  $sthub->finish;
  $sthuc->finish;
  $sthud->finish;
  $sthue->finish;
  $sthuf->finish;
  $sthug->finish;
  $sthuh->finish;
  $sthui->finish;
  $sthuj->finish;
  $sthuk->finish;
  
  $sthia->finish;
  $sthib->finish;
}

1;
__END__
