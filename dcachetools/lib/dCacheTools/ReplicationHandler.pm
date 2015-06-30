package dCacheTools::ReplicationHandler;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use POSIX qw/strftime/;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Math::BigInt;

use BaseTools::Util qw/message/;
use BaseTools::ConfigReader;

use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::PnfsManager;
use dCacheTools::P2P;
use dCacheTools::Replica;

# Autoflush
$| = 1;

use constant MINUTE => 60;
use constant MIN_INTERVAL => 5;
use constant KB2By => 1024;
use constant BLOCK_SIZE => 100 * (KB2By**2);    # sleep for 1 second for every 100 MB
use constant MIN_FREE_SPACE => 20 * (KB2By**3); # 20 GB

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader  = BaseTools::ConfigReader->instance();
  my $config  = $reader->{config};
  my $verbose = $config->{verbose} || 0;

  $attr->{max_threads}        = 5 unless (exists $attr->{max_threads} and $attr->{max_threads}>0);
  $attr->{src_cached}         = 0 unless (exists $attr->{src_cached} and $attr->{src_cached}>0);
  $attr->{dst_precious}       = 0 unless (exists $attr->{dst_precious} and $attr->{dst_precious}>0);
  $attr->{cached_src_allowed} = 0 unless (exists $attr->{cached_src_allowed} and $attr->{cached_src_allowed}>0);
  $attr->{same_host_allowed}  = 0 unless (exists $attr->{same_host_allowed} and $attr->{same_host_allowed}>0);
  $attr->{show_progress}      = 0 unless (exists $attr->{show_progress} and $attr->{show_progress}>0);
    
  my @poollist = dCacheTools::PoolManager->instance()->poollist; # must {parse_all}
  print STDERR join("|", @poollist), "\n" if $verbose;
  bless {
                config => $config,
              _verbose => ($attr->{verbose} || 0),
          dst_precious => $attr->{dst_precious},
            src_cached => $attr->{src_cached},
    cached_src_allowed => $attr->{cached_src_allowed},
     same_host_allowed => $attr->{same_host_allowed},
         show_progress => $attr->{show_progress},
           max_threads => $attr->{max_threads}, 
    ignore_space_limit => ($attr->{ignore_space_limit} || 0),
                _rlist => {},  # replication list
                _mlist => {},  # monitoring list
                _pnfsH => dCacheTools::PnfsManager->instance(),
                 _repH => dCacheTools::Replica->new,
              poollist => \@poollist
  }, $class;
}
sub add 
{
  my ($self, $input) = @_;
  my @poollist = @{$self->{poollist}};
  my $rlist = $self->{_rlist};

  my $pnfsid  = $input->{pnfsid};
  my $srcpool = $input->{spool};
  my $dstpool = $input->{dpool};

  message RED, q| source pool name not provided!| and return unless defined $srcpool;
  message RED, qq| source pool $srcpool is not in poollist| 
    and return unless grep { $_ eq $srcpool } @poollist;

  my $spool = dCacheTools::Pool->new({ name => $srcpool });
  message RED, qq| skipping, source pool $srcpool inaccessible!| and return 
    unless ($spool->alive({ refresh => 1 }) and not $spool->timedOut);

  my @output = $spool->exec({ command => qq|rep ls $pnfsid| });
  message RED, qq| skipping $pnfsid, source replica not present on $srcpool.| 
    and return if ($spool->hasCacheException or !scalar(@output));
  my $repH = $self->{_repH};
  $repH->repls($output[0]);
  message BLUE, qq| skipping $pnfsid, source replica on $srcpool not precious.| 
    and return if ($repH->cached and not $self->{cached_src_allowed});

  message RED, q| destination pool name not provided!| and return unless defined $dstpool;
  message RED, qq| destination pool $dstpool is not in poollist| 
    and return unless grep { $_ eq $dstpool } @poollist;

  my $tag = qq|$pnfsid#$srcpool#$dstpool|;
  $rlist->{$tag} = $input;
}
sub remove
{
  my ($self, $tag) = @_;
  my $rlist = $self->{_rlist};
  delete $rlist->{$tag};
}
sub run
{
  my $self = shift;
  my $rlist = $self->{_rlist};
  my $mlist = $self->{_mlist};
  my $repH  = $self->{_repH};
  print Data::Dumper->Dump([$rlist], [qw/rlist/]) if $self->{_verbose};

  # start max_thread p2p processes 
  my $nitems = scalar keys %$rlist;
  my ($item, $last_bunch) = (0,0);
  message BLUE, q| replication - start|;
  while (my ($tag, $input) = each %$rlist) {
    my ($spool, $dpool) = $self->replicate($input); 
    --$nitems and next unless (defined $spool and defined $dpool);

    $last_bunch = 1 if ++$item == $nitems;
    my $pnfsid = $input->{pnfsid};
    $mlist->{$tag} = {
                        pnfsid => $pnfsid,
                         spool => $spool, 
                         dpool => $dpool, 
                          size => filesize($spool, $pnfsid),
                       started => time()
                     };

    # remove the completed ones and add new ones so that max_thread 
    # processes are always on
    my $nactive = scalar keys %$mlist;
    if ( $nactive == $self->{max_threads} or $last_bunch ) {
      message BLUE, q| entering monitoring loop|;
      while (1) {
        my $bytes_left = 0;
        my $timenow = time;
        while (my ($tag, $info) = each %$mlist) {
          my $pnfsid  = $info->{pnfsid};
          my $spool   = $info->{spool};
          my $dpool   = $info->{dpool};
          my $srcsize = $info->{size};
          my $in_transfer = $timenow - $info->{started};

          my $srcpool = $spool->name;
          my $dstpool = $dpool->name;

          # at source, check each time if the Pool is alive
          my @p2p_output = $spool->exec({ command => q|p2p ls| });
          message RED, qq| source Pool $srcpool inaccessible, continue to next!| 
            and next unless $spool->alive;

          # what happens if the same file is replicated from 1 to may pools?
          # p2p ls output will have the same pnfsid many times
          # so we need another way to get unique combination of (pnfsid,src,dest). How?
          my @srcLines = grep /{$dstpool@(?:.*?):\d+}\s+$pnfsid/, @p2p_output; 
          if (scalar @srcLines) {
	    my $p2p = dCacheTools::P2P->new({
                input => $srcLines[0],
               server => $spool
            });
            # kill the transfer if it is hung and clean-up
            if ($p2p->stuck) {
              my $d = $in_transfer / MINUTE;
              message RED, qq| removing <$pnfsid> from Pool <$srcpool> to Pool <$dstpool>: p2p hung for $d mins!|;
              $p2p->cancel;
              delete $mlist->{$tag};
              next;
            }
	  }
          my $src_quiet = (scalar @srcLines) ? 0 : 1;
          push @srcLines, $srcsize if $src_quiet;
          message BLUE, qq| source pool <$srcpool> says:|;
          print join("\n", @srcLines), "\n";

          # calculate the transfer rate and bytes remaining at the source pool
          $bytes_left += showRate($srcLines[0], $srcsize) unless $src_quiet;
    
          # at destination check every time that the pool is alive
          my @pp_output = $dpool->exec({ command => q|pp ls| });
          message RED, qq| destination Pool $dstpool inaccessible, continue to next!| 
            and next unless $dpool->alive;
    
          my @destLines  = grep /$pnfsid/, @pp_output; 
          my $dest_quiet = (scalar @destLines) ? 0 : 1;
          push @destLines, filesize($dpool, $pnfsid) if $dest_quiet;
          message BLUE, qq| destination pool <$dstpool> says:|;
          print join("\n", @destLines), "\n";
    
          # take a decision
          if ($src_quiet and $dest_quiet and sizeMatched($pnfsid, $spool, $dpool)) {
	    if ($self->{dst_precious}) {
              # mark the replica as precious
              $dpool->exec({ command => qq|rep set precious $pnfsid -force| });
              
              # wait for a couple of moments and check if the destination is indeed precious
              sleep 2;

              my @output = $dpool->exec({ command => qq|rep ls $pnfsid| });
              $repH->repls($output[0]);
              if ($repH->precious and $self->{src_cached}) { 
                # If possible and requested make the source cached for eventual reclaim
                @output = $spool->exec({ command => qq|rep ls $pnfsid| });
                $repH->repls($output[0]);
                unless ($repH->client_count > 0) {
		  my $niter = 0;
                  do { 
                    $spool->exec({ command => qq|rep set cached $pnfsid -force| });

                    # wait for a couple of moments and check if the source is indeed cached; if not warn
                    sleep 2;

                    @output = $spool->exec({ command => qq|rep ls $pnfsid| });
                    $repH->repls($output[0]);
		  } until ($repH->cached or ++$niter > 3);
                  $repH->cached or message RED, qq| failed to make source replica [$srcpool, $pnfsid] cached!\n|;
	        }
              }
	    }

            # now remove the completed transfer
            message GREEN, qq| replication of <$pnfsid> from Pool <$srcpool> to Pool <$dstpool> complete\n|;
            delete $mlist->{$tag};
          }
        }
        $nactive = scalar keys %$mlist;

        # define the cases when control comes out of the monitor loop 
        last unless $nactive;
        last if ($nactive < $self->{max_threads} and not $last_bunch);

        my $mon_interval = getMonitorInterval($bytes_left, $nactive); 
        message BLUE, qq| setting monitoring interval to $mon_interval seconds.|;
        sleep $mon_interval;
      }
    }
  }
  message BLUE, q| replication - end|;
}
sub replicate
{
  my ($self, $input) = @_;
  my $pnfsid  = $input->{pnfsid};
  my $srcpool = $input->{spool};
  my $dstpool = $input->{dpool};
  message RED, q| invalid input!| and return () unless (defined $pnfsid 
                                                    and defined $srcpool
                                                    and defined $dstpool);
  my $pnfsH = $self->{_pnfsH};
  my $spool = dCacheTools::Pool->new({ name => $srcpool });
  message RED, qq| skipping $pnfsid, source pool $srcpool inaccessible!| and return () 
    unless ($spool->alive({refresh => 1}) and not $spool->timedOut);
  my $shost = $spool->host;

  # from pnfsid get the pfn
  my ($status, $srcsize, $pfn) = file_exists($pnfsH, $spool, $pnfsid);
  message RED, qq| skipping $pnfsid, source $srcpool does not have a replica!| 
    and return () 
      unless defined $status;
  message RED, q| skipping $pnfsid, failed to get pfn from pnfsid!| 
    and return () 
      unless defined $pfn;

  # source and destination should be different
  message CYAN, qq| skipping $pnfsid, srcpool=$srcpool and dstpool=$dstpool same| 
    and return () 
      if $srcpool eq $dstpool;

  my $dpool = dCacheTools::Pool->new({ name => $dstpool });
  message RED, qq| skipping $pnfsid, destination pool $dstpool inaccessible!| 
    and return () 
      unless ($dpool->alive({ refresh => 1 }) and not $dpool->timedOut);
  my $dhost = $dpool->host;

  # also optionally ensure that the src and destination nodes are different
  message CYAN, qq| skipping $pnfsid, srcnode($shost) and destnode($dhost) same| 
    and return () 
      if (not $self->{same_host_allowed} and $dhost eq $shost);

  # the file might already exist at the destination pool
  my ($dstatus, $destsize, $destpfn) = file_exists($pnfsH, $dpool, $pnfsid);
  if (defined $dstatus) {
    my $color = GREEN;
    my $res   = q|match.|;
    if (abs($srcsize-$destsize)) { $color = RED; $res = q|mismatch!!|; }
    message GREEN, qq| skipping $pnfsid, already on $dstpool, $srcpool:$srcsize, $dstpool=$destsize, $res| 
      and return () if $dstatus;
  }
  # check if the destination pool has enough space
  my $space_info = $dpool->space_info;
  message RED, qq| skipping $pnfsid, only $space_info->{free} bytes free on destination pool $dstpool! reqd_min=|
    . MIN_FREE_SPACE. q| bytes| 
    and return () unless ($self->{ignore_space_limit} or $space_info->{free} >= MIN_FREE_SPACE);

  # all set now
  message BLUE, qq| process entry name=<$pfn> pnfsid=<$pnfsid> srcpool=<$srcpool> dstpool=<$dstpool>|;

  # initiate pool-to-pool copy
  my $command = qq|pp set pnfs timeout 300\npp get file $pnfsid $srcpool\npp ls|;
  print $command, "\n" if $self->{_verbose};
  my @result = $dpool->exec({ command => $command });

  # the destination pool already has the file, the second line of defence
  if (grep /Entry already exists/, @result) {
    # mark the replica as precious
    $dpool->exec({ command => qq|rep set precious $pnfsid -force| }) if $self->{dst_precious};
    message GREEN, qq| skipping, $pnfsid already replicated to $dstpool, no action!| and return ();
  }
  message BLUE, q| replication command output:|;
  print join("\n", @result), "\n";

  ($spool, $dpool);
}
sub getMonitorInterval
{
  my ($size, $nactive) = @_;
  my $interval;
  eval {
    $interval = int($size/BLOCK_SIZE/$nactive);
  };
  $interval = MIN_INTERVAL if ($@ || $interval < MIN_INTERVAL);
  $interval;
}
sub filesize
{
  my ($pool, $pnfsid) = @_;
  return -1 unless defined $pool;
  my $size = $pool->filesize($pnfsid);
  (defined $size) ? $size : -1;
}
sub file_exists
{
  my ($pnfsH, $pool, $pnfsid) = @_;
  my $size = $pool->filesize($pnfsid);
  return () unless defined $size;
  
  my $pfn = $pnfsH->pathfinder($pnfsid);
  return (1, $size) unless defined $pfn;
  return (1, $size, $pfn);
}
sub sizeMatched
{
  my ($pnfsid, $spool, $dpool) = @_;

  my $ssize = $spool->filesize($pnfsid);
  return 0 unless defined $ssize;

  my $dsize = $dpool->filesize($pnfsid);
  return 0 unless defined $dsize;

  return (($ssize - $dsize) == 0) ? 1 : 0;
}
sub showRate
{
  my $input = shift;
  my $p2p = dCacheTools::P2P->new({ input => $input });

  my $bytes_left = $p2p->bytes_left;
  printf qq|Avg. Rate=%.2f KB/sec, remaining=%s bytes, approx. time left=%d sec\n|, 
          $p2p->rate, 
          (Math::BigInt->new($bytes_left))->bstr,
          $p2p->time_left;

  $bytes_left;
}

1;
__END__
package main;
use BaseTools::Util qw/readFile/;

my $infile = shift || die qq|Usage: $0 infile|;
die qq|$infile not readable, stopped| unless -r $infile;
chomp(my @list = readFile($infile));

my $handler = dCacheTools::ReplicationHandler->new({ max_threads => 5 });
for (@list) {
  next if /^$/;
  next if /^#/;
  my ($pnfsid, $spname, $dpname) = split;
  $handler->add({
    pnfsid => $pnfsid,
     spool => $spname,
     dpool => $dpname
  });
}
$handler->run;
