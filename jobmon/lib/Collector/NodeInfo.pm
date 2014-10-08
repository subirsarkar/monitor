package Collector::NodeInfo;
 
use strict;
use warnings;
use Carp;
use IO::File;
use File::Basename;
use File::Find;
use Fcntl ':mode';
use Data::Dumper;
use List::Util qw/max min/;

use Collector::ConfigReader;
use Collector::ObjectFactory;
use Collector::Util qw/trim 
                       getHostname 
                       isSLC4 
                       getCommandOutput 
                       filereadFH
                       readFile 
                       nCPU/;

$Collector::NodeInfo::VERSION = q|1.0|;

# Keep provision for other storage systems
our $storageTypes =
{
  dcache => q|Collector::dCache::Transfers|,
  lustre => q|Collector::Lustre::Transfers|
};

use constant SCALE => 1024;
our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $page2bytes = 4 * $conv->{K};
our $cmap = 
{
    Z => q|zcat|,
   gz => q|zcat|,
  bz2 => q|bzcat|
};
sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  # read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $self = bless { 
       nCPU => nCPU(),
    _config => $config,
          @_ 
  }, $class;
  if ($config->{storageinfo}{available}) {
    my $type  = $config->{storageinfo}{type} || 'dcache';
    my $class = $storageTypes->{$type} || croak qq|Storage system $type not supported!|;
    $self->{_sobj} = Collector::ObjectFactory->instantiate($class);
  }
  $self;
}

sub config
{
  my $self = shift;
  $self->{_config};
}
sub info
{
  my $self = shift;
  if (@_) {
    return $self->{_info} = shift;
  } 
  else {
    return $self->{_info};
  }
}

sub collectAdditionalInfo
{
  my ($self, $jid) = @_;
  my $config = $self->config;
  my $verbose = $config->{verbose} || 0;

  my $info = $self->info;
  print STDERR qq|Failed to get the dictionary for JID=$jid!\n| 
    and return q|| unless defined $info;

  unless (defined $info->{jidmap}{$jid}{jobinfo}) {
    my $pidInfo = $info->{jidmap}{$jid}{pids};
    my @pidList = $self->pidList($jid);
    print STDERR join ("\n", qq|\@pidList=|, scalar @pidList, @pidList), "\n" if $verbose;

    my $jobInfo = {};
    my ($pidMaxLoad, $pidMaxTime, $maxLoad, $maxTime) = (-1,-1,-1,-1);
    for my $pid (@pidList) {
      if (-e qq|/proc/$pid|) { # ensure that data is available
        $jobInfo->{$pid}{cwd}  = readlink qq|/proc/$pid/cwd| || q##;
        $jobInfo->{$pid}{load} = $pidInfo->{$pid};

        my @fd      = (readlink qq|/proc/$pid/fd/1| || q##, readlink qq|/proc/$pid/fd/2| || q##);
        my @fd_stat = map { ( -e $_ ) ? [ (stat $_)[2,9] ] : [0,0] } @fd; # mode=>[2], mtime=>[9]

        if (-e qq|/proc/$pid|) { # ensure that data is still available !!!
          ($jobInfo->{$pid}{stdout}, $jobInfo->{$pid}{stdout_time}) = 
              (S_ISREG($fd_stat[0][0])) ? ($fd[0], $fd_stat[0][1]) : (q||, 0);
          ($jobInfo->{$pid}{stderr}, $jobInfo->{$pid}{stderr_time}) = 
              (S_ISREG($fd_stat[1][0])) ? ($fd[1], $fd_stat[1][1]) : (q||, 0);

          $jobInfo->{$pid}{time} = max $jobInfo->{$pid}{stdout_time}, $jobInfo->{$pid}{stderr_time};
          if ($jobInfo->{$pid}{time} > $maxTime) {
            $maxTime = $jobInfo->{$pid}{time};
            $pidMaxTime = $pid;
          }
          if ($jobInfo->{$pid}{load} > $maxLoad) {
            $maxLoad = $jobInfo->{$pid}{load};
            $pidMaxLoad = $pid;
          }
        }
      }
    }
    my ($stdout, $stderr, $jobdir, $workdir) = (q||, q||, q||, q||);
    if ($pidMaxLoad > -1 and $pidMaxTime > -1) {
      if ($jobInfo->{$pidMaxLoad}{time}) {
        $stdout = $jobInfo->{$pidMaxLoad}{stdout};
        $stderr = $jobInfo->{$pidMaxLoad}{stderr};
        $jobdir = $jobInfo->{$pidMaxLoad}{cwd};
      } 
      elsif ($jobInfo->{$pidMaxTime}{time}) {
        $stdout = $jobInfo->{$pidMaxTime}{stdout};
        $stderr = $jobInfo->{$pidMaxTime}{stderr};
        $jobdir = $jobInfo->{$pidMaxTime}{cwd};
      }
      print STDERR join("|", $stdout, $stderr, $jobdir), "\n" if $verbose;

      my $njobdir;
      if ($jobdir =~ m#(?:.*?)/(?:\.?)globus(?:.*?)/#) {
        my $gid = $info->{jidmap}{$jid}{gid};
        my $log = $config->{voattr}{$gid}{log};
        if (defined $log) {
          my $file = __PACKAGE__->traverse($jobdir, $log);
          $stdout = $file and $njobdir = dirname $stdout if defined $file;
        }
        my $error = $config->{voattr}{$gid}{error};
        if (defined $error) {
          my $file = __PACKAGE__->traverse($jobdir, $error);
          if (defined $file) {
            $stderr = $file;
            $njobdir = dirname $stderr unless defined $njobdir;
      	  }
        }
        print STDERR join("|", $stdout, $stderr), "\n" if $verbose;
      }
      $jobdir = $njobdir if defined $njobdir;
      $workdir = ($jobdir =~ m#(?:.*?)/(?:\.?)globus(?:.*?)/#) ? dirname $jobdir : $jobdir;      
      print STDERR join("|", $jid, $jobdir, $workdir), "\n" if ($verbose or $jobdir eq $workdir);
    }
    else {
      printf STDERR qq|Failed to find stdout,stderr for JID=%d,pidMaxLoad=%d,pidMaxTime=%d\n|,
                $jid, $pidMaxLoad, $pidMaxTime;
    }

    $jobInfo->{stdout}  = $stdout;
    $jobInfo->{stderr}  = $stderr;
    $jobInfo->{workdir} = $workdir;
    $jobInfo->{jobdir}  = $jobdir;
    
    $info->{jidmap}{$jid}{jobinfo} = $jobInfo;
    print Data::Dumper->Dump([$info], [qw/info/]) if $config->{debug};    
  }
}

sub traverse
{
  my ($pkg, $path, $name) = @_;
  my @list = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    push @list, $file if (-f $file and basename($file) =~ /$name/);
  };
  find $traversal, $path;

  my %dict = map { $_ => -M $_ } @list;
  @list = sort { $dict{$b} <=> $dict{$a} } keys %dict;
  $list[0] || undef;
}
sub getLoad
{
  my ($self, $jid) = @_;
  my $config = $self->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $info = $self->info;
  print STDERR qq|Failed to get the dictionary for JID=$jid!\n| 
    and return 0.0 unless defined $info;

  my @pidList = $self->pidList($jid);
  my $npid = scalar @pidList;
  print STDERR qq|No active PID found for JID=$jid!\n| 
    and return 0.0 unless $npid;

  # Cludge 1
  my $column = (isSLC4()) ? 9 : 10;  
  my $command = q|top -b -n 1|;
  print STDERR "command=$command, npid=$npid\n" if $verbose;

  my $ecode = 0;
  chomp(my @list = 
    map { trim $_ } getCommandOutput($command, \$ecode, $show_error, $verbose));

  my $cpup = 0.0;
  my $totalCpup = 0.0;
  for my $row (@list) {
    next if $row !~ /^[0-9]/; # ignore lines which do not start with a PID
    my @fields = (split /\s+/, trim $row);
    next if scalar @fields < $column;

    $totalCpup += $fields[$column-1];

    my $xpid = $fields[0];
    next unless grep { /^$xpid$/ } @pidList;
    $cpup += $fields[$column-1]; # %CPU column   
  }
  chop(my $avgload = `cat /proc/loadavg | awk '{print \$1}'`);

  my $load = $avgload * $cpup;
  $load /= $totalCpup if $totalCpup;

  $load;
}

sub getProcesses
{
  my ($self, $jid) = @_;
  my $config = $self->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $info = $self->info;
  print STDERR qq|Failed to get the dictionary for JID=$jid!\n| 
    and return q|| unless defined $info;

  my $command = $self->buildCommand($jid, 'ps');
  return q|| unless defined $command;

  print STDERR "command=$command\n" if $verbose;
  my $ecode = 0;
  chop(my $text = getCommandOutput($command, \$ecode, $show_error, $verbose));

  if (defined $self->{_sobj}) {
    my $sobj = $self->{_sobj};
    my @pidList = $self->pidList($jid);
    my $user = $info->{jidmap}{$jid}{uid};
    my $spath = $sobj->getline({pids => \@pidList, user => $user });
    $text .= qq|\n|.$spath if (defined $spath and length $spath);
  }
  $text;
}

sub jobTracking
{
  my ($self, $jid, $tag) = @_;
  my $info = $self->info;
  my $config = $self->config;

  $self->collectAdditionalInfo($jid);

  my $file = ($tag eq 'log') ? $info->{jidmap}{$jid}{jobinfo}{stdout}
                             : $info->{jidmap}{$jid}{jobinfo}{stderr};

  __PACKAGE__->getLog($file, $config->{nodeinfo}{nlines});
}

sub pidList
{
  my ($self, $jid) = @_;
  my $info = $self->info;

  return () unless defined $info->{jidmap}{$jid}{pids};
  my $pidInfo = $info->{jidmap}{$jid}{pids};
  sort keys %$pidInfo;
}
sub buildCommand
{
  my ($self, $jid, $option) = @_;
  my $config = $self->config;
  my $verbose = $config->{verbose} || 0;

  $option = q|ps| unless defined $option;

  my @pidList = $self->pidList($jid);
  return undef unless scalar @pidList;

  print STDERR join ("\n", qq|\@pidList=|, scalar @pidList, @pidList), "\n" if $verbose;
  my $command = q|ps |.(($option eq 'ps') ? q|--forest| : q||).q| --pid |;
  $command .= join (q|,|, @pidList);
  $command .= ($option eq 'ps') ? q| -o pid,start,pcpu,rss:7,vsz:7,cmd|
                                : q| -o cmd|;
  $command;
}

# unit: pages
# 0 Total program size
# 1 Size of memory portions
# 2 Number of pages that are shared
# 3 Number of pages are code
# 4 Number of pages of data/stack
# 5 Number of pages of library
# 6 Number of dirty pages 
sub getJobMemory
{
  my ($self, $jid) = @_;
  my @pidList = $self->pidList($jid);
  my $dict = {};
  for my $pid (@pidList) {
    next unless -d qq|/proc/$pid|;
    my $file = qq|/proc/$pid/statm|;
    chop(my $content = readFile($file));
    my ($psize, $tmem, $mshr, $mcode, $mdata, $mlib, $mdirty) 
      = map { $page2bytes * $_ } (split /\s+/, $content);
    $dict->{psize}  += $psize;
    $dict->{mtot}   += $tmem;
    $dict->{mshr}   += $mshr;
    $dict->{mcode}  += $mcode;
    $dict->{mdata}  += $mcode;
    $dict->{mlib}   += $mlib;
    $dict->{mdirty} += $mdirty;
  }
  $dict;
}
sub jobids
{
  my $self = shift;
  my $info = $self->info;
  return [] unless defined $info;

  my $map = $info->{jidmap};
  [sort keys %$map];
}

sub getWorkDir
{
  my ($self, $jid) = @_;
  $self->collectAdditionalInfo($jid);

  my $info = $self->info;
  $info->{jidmap}{$jid}{jobinfo}{workdir};
}
sub listWorkDir 
{
  my ($self, $jid) = @_;
  my $dir = $self->getWorkDir($jid);
  return q|Work directory not found!| unless (defined $dir && -e $dir);

  __PACKAGE__->getDirListing($dir);
}

sub listJobDir
{
  my ($self, $jid) = @_;
  $self->collectAdditionalInfo($jid);

  my $info = $self->info;
  my $dir = $info->{jidmap}{$jid}{jobinfo}{jobdir};
  return q|Job directory not found!| unless (defined $dir && -e $dir);

  __PACKAGE__->getDirListing($dir);
}
sub getDiskUsage
{
  my ($self, $jid) = @_;
  my $info = $self->info;
  my $dir = $info->{jidmap}{$jid}{jwdir};
  return 0 unless (defined $dir and -e $dir);
  chop(my $usage = `du -Dsb $dir`);
  my $value = (split /\s+/, trim $usage)[0];
  $value;
}
sub getDirListing
{
  my ($class, $file) = @_;

  # read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $dir = (-f $file) ? dirname $file : $file;
  my $command = qq|ls -ltr --dereference $dir|;
  my $ecode = 0;
  chop(my $content = getCommandOutput($command, \$ecode, $show_error, $verbose));
  qq|$dir\n$content|;
}

sub getLog
{
  my ($class, $file, $nlines) = @_;
  return q|Failed to find the job log/error file!|
     unless (defined $file and $file ne '');

  return qq|$file not readable!| unless -r $file;
  return qq|$file\n(Empty log)!| if -z $file;

  # read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $command;
  if ( -T $file ) {
    $command = q|cat -s -v|;
  }
  else {
    my $ext = (split /\./, $file)[-1];
    $command = $cmap->{$ext}.q| --quiet| if defined $cmap->{$ext};
  }
  return qq|$file\nunsupported extension (supports: ASCII, .gz, .bz2)| 
     unless defined $command;

  $command .= qq! $file 2>/dev/null| tail --lines=$nlines!; # note the unix pipe
  my $ecode = 0;
  chop(my $content = getCommandOutput($command, \$ecode, $show_error, $verbose));
  qq|$file\n$content|;
}

sub getTotalLoad
{
  my $class = shift;
  chop(my $output = `cat /proc/loadavg`);
  [(split /\s+/, $output)[0,1,2]];
}

sub getTop
{
  my $class = shift;
  chop(my $text = `top -b -n 1`);
  my $tn = localtime;
  qq|== $tn ==\n$text|;
}

sub getMemory
{
  my $class = shift;
  __PACKAGE__->getProcInfo(q|Mem|);
}

sub getSwap
{
  my $class = shift;
  __PACKAGE__->getProcInfo(q|Swap|);
}

sub getProcInfo
{
  my ($class, $type, $verbose) = @_;
  $verbose = 0 unless defined $verbose;

  my $file = q|/proc/meminfo|;
  my ($total, $used, $free) = (-1,-1,-1);
  my ($patT, $patF) = ($type.q|Total:|, $type.q|Free:|);

  my $fh = filereadFH($file, $verbose);
  if (defined $fh) {
    while (<$fh>) {
      if (/$patT/) {
        $total = (split)[1] * $conv->{K};
      }
      elsif (/$patF/) {
        $free = (split)[1] * $conv->{K};
      }
    }
    $fh->close;
  }
  $used = $total - $free;
  print STDERR join(",", $total, $used, $free), "\n" if $verbose;
  [$total, $used, $free];
}

sub valid
{
  my ($class, $gid) = @_;
  return 0 if ($gid eq '' || $gid eq '?');
  return 1;
}

1;
__END__
