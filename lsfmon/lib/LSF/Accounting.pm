package LSF::Accounting;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Getopt::Long;
use IO::File;
use File::Basename;
use File::stat;

use POSIX qw/strftime/;

use Storable;
use List::Util qw/max min sum/;

use LSF::Groups;
use LSF::CompletedJobInfo;
use LSF::ConfigReader;
use LSF::Util qw/trim 
                 getCommandOutput
                 filereadFH 
                 findGroup 
                 storeInfo 
                 restoreInfo/;
use LSF::PlotCreator qw/createPNG 
                        createPNGWithIM 
                        plotPie 
                        plotBar 
                        drawLegends/;
# auto-flush
$| = 1;

sub new
{
  my $this = shift;
  my $class = ref $this || $this;

  my $config = LSF::ConfigReader->instance()->config;
  my $use_bugroup = $config->{use_bugroup} || 0;

  my $self = bless { 
       ugDict => ($use_bugroup) ? LSF::Groups->instance({ verbose => 0 })->info : {},
    _filelist => [] # reference to a list
  }, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;

  croak q|ERROR. acctDir cannot be accessed, stopped| unless defined $config->{accounting}{infoDirList};
  carp q|WARNING. Color dictionary should be defined in the config for correct functioning| 
    unless defined $config->{plotcreator}{colorDict};
  $config->{accounting}{htmlFile} = q|accounting.html| unless defined $config->{accounting}{htmlFile};
}

sub DESTROY 
{
  my $self = shift;

  #print Data::Dumper->Dump([$self], [qw/self/]);

  # Store the information back to db
  $self->saveInfo;
}

sub getFilelist
{
  my $self = shift;

  my $config = LSF::ConfigReader->instance()->config;
  my $acctDirList = $config->{accounting}{infoDirList} || [];
  my $isdebug     = $config->{accounting}{debug}{enabled} || 0;
  my $maxFiles    = $config->{accounting}{debug}{max_files} || 4;

  my @fileList = ();
  for my $acctDir (@$acctDirList) {
    next unless -d $acctDir;

    # Read all the lsb.acct.* files. This should be done only once
    local *DIR;
    opendir DIR, $acctDir || carp qq|Failed to open directory $acctDir, $!, stopped|;

    # Schwarzian transformation
    push @fileList, map { qq|$acctDir/$_| }
                       grep { /lsb.acct/ }
                         readdir DIR;
    closedir DIR;
  }
  my %dict = map { $_ => -M $_ } @fileList;
  @fileList = sort { $dict{$b} <=> $dict{$a} } keys %dict;
  @fileList = ($isdebug ? splice @fileList, -$maxFiles : @fileList);
  $self->{_filelist} = \@fileList;
}

sub getAcctFiles
{
  my $self = shift;
  scalar @{$self->{_filelist}} or $self->getFilelist;
  $self->{_filelist};
}

sub setFirstEntry
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;

  my $ptag = $attr->{ptag};
  $self->{acctinfo}{anchor}{$ptag}{fread_jid}   = $attr->{jid};
  $self->{acctinfo}{anchor}{$ptag}{fread_etime} = $attr->{etime};
}

sub setLastEntry
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $timeSlices = $config->{accounting}{timeSlices} || [];
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    $self->{acctinfo}{anchor}{$ptag}{lread_jid}   = $attr->{jid};
    $self->{acctinfo}{anchor}{$ptag}{lread_etime} = $attr->{etime};
  }
}
sub addToAcctinfo
{
  my ($self, $dict, $setFE) = @_;
  carp qq|Hash \$dict undefined!| and return unless defined $dict;
  $setFE = 0 unless defined $setFE;
  my $group = $dict->{group};
  defined $group or return;
 
  my $config = LSF::ConfigReader->instance()->config;
  my $age = ($setFE) ? time() - $dict->{etime} : -1; # completed $age seconds ago
  my $timeSlices = $config->{accounting}{timeSlices} || [];
  for my $el (@$timeSlices) {
    $age > $el->{period} and next;
    my $ptag = $el->{ptag};
    $self->{acctinfo}{data}{$ptag}{$group}{jobs}++;
    $self->{acctinfo}{data}{$ptag}{$group}{sjobs}++ unless $dict->{ex_st};
    $self->{acctinfo}{data}{$ptag}{$group}{cores}  += $dict->{cores};
    $self->{acctinfo}{data}{$ptag}{$group}{walltime} += $dict->{walltime};
    $self->{acctinfo}{data}{$ptag}{$group}{cputime}  += $dict->{cputime};
    $self->{acctinfo}{data}{$ptag}{$group}{waitfor}  += $dict->{waitfor};

    # hack
    $self->setFirstEntry({ ptag => $ptag, jid => $dict->{jid}, etime => $dict->{etime} })
      if ($setFE and not exists $self->{acctinfo}{anchor}{$ptag}{fread_jid});
  }
}

sub removeFromAcctinfo
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $dict  = $attr->{dict};
  my $group = $dict->{group};
  defined $group or return;
  my $el   = $attr->{el};
  my $ptag = $el->{ptag};
  $self->{acctinfo}{data}{$ptag}{$group}{jobs}--;
  $self->{acctinfo}{data}{$ptag}{$group}{sjobs}-- unless $dict->{ex_st};
  $self->{acctinfo}{data}{$ptag}{$group}{cores}  -= $dict->{cores};
  $self->{acctinfo}{data}{$ptag}{$group}{walltime} -= $dict->{walltime};
  $self->{acctinfo}{data}{$ptag}{$group}{cputime}  -= $dict->{cputime};
  $self->{acctinfo}{data}{$ptag}{$group}{waitfor}  -= $dict->{waitfor};
}

sub addDelta
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  print qq|>>> addDelta:\n|;
  my $info = {};
  my @files = @{$self->getAcctFiles};
  for my $file (@files) {
    # skip files that are way out of the delta time window
    my $stats = stat $file or carp qq|Failed to stat $file, reason: $?\n| and next;
    $stats->mtime < $attr->{lread_etime} and next;

    # first read the lsb.acct file directly
    my $jobinfo = __PACKAGE__->readAcctFile($file);

    # now use bacct to get the rest of the information
    my $jobList = __PACKAGE__->exec_bacct($file);

    for (@$jobList) {
      # We already have the long listing on the job at our disposal
      chop;
      my $dict = $self->parseLine($_, $jobinfo);
      defined $dict or next;
      my $etime = $dict->{etime};
      $etime < $attr->{lread_etime} and next;
      print ">>> Add $dict->{jid}\n" if $verbose;
      $self->addToAcctinfo($dict);
      $info->{jid}   = $dict->{jid};
      $info->{etime} = $etime;
    }
  }
  $self->setLastEntry({ jid => $info->{jid}, etime => $info->{etime} }) 
    if exists $info->{jid};
}

sub readAcctFile
{
  my ($pkg, $file) = @_;
  print qq|>>> Processing   file: <$file>\n|;

  my $jobinfo = {};
  my $fh = filereadFH($file);
  if (defined $fh) {
    while (<$fh>) {
      chop;
      my ($end, $jobid, $submit, $start, $user, $queue, $ui)
        = (split)[2,3,7,10,11,12,16];
      $user =~ s/"//g; $queue =~ s/"//g; $ui =~ s/"//g;
      $jobinfo->{$jobid} = [$user, $queue, $ui, $submit, $start, $end];
    }
    $fh->close;
  }
  $jobinfo;
}
sub exec_bacct
{
  my ($pkg, $file) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose_g = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $b_command = q|bacct -l -u all |;
  my $tmpFile = q|/tmp/lsb.acct.tmp|;
  my $command = ($file =~ /\.gz$/) ? qq#zcat $file > $tmpFile; $b_command -f $tmpFile# : qq|$b_command -f $file|;

  print qq|>>> Executing command: <$command>\n|;

  my $ecode = 0;
  chop(my $text = getCommandOutput($command, \$ecode, $show_error, $verbose_g));
  return [] if $ecode;

  my $sep = '-' x 78;
  my $jobList = [split /$sep/, $text]; 
  shift @$jobList; pop @$jobList;
  $jobList;
}
sub deleteDelta
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $delta = $self->{acctinfo}{anchor}{lday}{lread_etime} 
            - $attr->{lread_etime}; # seconds

  print qq|>>> deleteDelta: $delta seconds\n|;

  my $info = {};
  my @files = @{$self->getAcctFiles};
  my $timeSlices = $config->{accounting}{timeSlices} || [];
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    $ptag eq q|lfull| and next;

    my $window_start = $self->{acctinfo}{anchor}{$ptag}{fread_etime};
    my $window_end   = $window_start + $delta;
    print qq|>>> period=$ptag\n|;

    my $read_next_file = 1;
    for my $file (@files) {

      # skip files that are way out of the time window
      my $stats = stat $file or carp qq|Failed to stat $file, reason: $?\n| and next;
      $stats->mtime < $window_start and next; 

      # first read the lsb.acct file directly
      my $jobinfo = __PACKAGE__->readAcctFile($file);

      # now use bacct to get the rest of the information
      my $jobList = __PACKAGE__->exec_bacct($file);

      for (@$jobList) {
        chop;
        my $dict = $self->parseLine($_, $jobinfo);
        defined $dict or next;

        my $etime = $dict->{etime};
        $etime < $window_start and next;
        if ($etime > $window_end) {
          $read_next_file = 0;
          $self->setFirstEntry({ ptag => $ptag, jid => $dict->{jid}, etime => $etime });
          last;
        }
        print "Remove $dict->{jid}\n" if $verbose;
        $self->removeFromAcctinfo({ el => $el, dict => $dict });
      }
      $read_next_file or last;
    }
  }
}

sub parseLine
{
  my ($self, $line, $dict) = @_;
  my $config = LSF::ConfigReader->instance()->config;
  my $acctDirList   = $config->{accounting}{infoDirList} || [];
  my $skip_root     = (exists $config->{accounting}{skip_root} and $config->{accounting}{skip_root}) ? 1 : 0;
  my $queues_toskip = $config->{queues_toskip} || [];
  my $verbose       = $config->{accounting}{verbose} || 0;
  
  my $job = LSF::CompletedJobInfo->new({ line => $line, dict => $dict, verbose => $verbose });
  my $info = $job->info;
  my $jid = $info->{JID};
  my $user = $info->{USER};
  my $queue = $info->{QUEUE};
  print ">>>> JID=$jid USER=$user\n" and return undef unless defined $queue;

  return undef if ($skip_root and $user eq 'root');
  return undef if grep { $_ eq $queue } @$queues_toskip;
  unless (exists $self->{ugDict}{$user}) {
    my $group = undef;
    eval {
      $group = findGroup $user;
    };
    $@ and carp qq|problem finding group for user $user|;
    $self->{ugDict}{$user} = [$group] if defined $group;
  }
  my $group = $self->{ugDict}{$user}[0] || q|other|;
  carp qq|group not found for JID=$jid, USER=$user! setting GROUP=$group, check if the user is created correctly;|
    if $group eq q|other|;
  return undef if ($skip_root and $group eq 'root');

  my $walltime = $info->{WALLTIME};
  # FIXME. cputime >> walltime indicates a wrong entry
  my $cputime = int(min($info->{CPUTIME}, $walltime));
  printf "%10s %7.7d %9.1f %9.1f\n", $group, $jid, $walltime, $cputime if $verbose;

  # get the end time and 'wait' period of the job, all in seconds since the epoch
  my $etime = $info->{END};
  my $qtime = $info->{QTIME} || 0;
  my $stime = $info->{START} || 0;
  my $ncore = $info->{NCORE} || 0; 
  #print "==> ", join(",", $jid, $qtime, $stime, $etime, $stime-$qtime), "\n";
  my $wtime = ($stime > 0 and $qtime > 0) ? $stime - $qtime : 0; # waited on the queue
  {
         jid => $jid,
       group => $group,
     cputime => $cputime,
    walltime => $walltime,
       cores => $ncore,
     waitfor => $wtime,
       etime => $info->{END},
       ex_st => $info->{EX_ST}
  };
}

sub update
{
  my $self = shift;
  my $config = LSF::ConfigReader->instance()->config;
  my $timeSlices = $config->{accounting}{timeSlices} || [];
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    my $groupInfo = $self->{acctinfo}{data}{$ptag};

    # get the total walltime and total jobs in each period
    my @groupList = sort keys %$groupInfo;
    my $walltime_t = 0;
    my $njobs_t = 0;
    for my $group (@groupList) {
      $walltime_t += $groupInfo->{$group}{walltime};
      $njobs_t    += $groupInfo->{$group}{jobs};
    }
    for my $group (@groupList) {
      my $walltime = $groupInfo->{$group}{walltime};
      my $cputime  = $groupInfo->{$group}{cputime};
      my $njobs    = $groupInfo->{$group}{jobs};
      my $sjobs    = (exists $groupInfo->{$group}{sjobs}) ? $groupInfo->{$group}{sjobs} : 0;
      my $srate    = ($njobs) ? $sjobs*1.0/$njobs : 0.0;
      my $avgwait  = ($njobs) ? $groupInfo->{$group}{waitfor}/$njobs : 0; # seconds
      my $cpueff   = ($walltime) ? min(1.0, $cputime/$walltime) : 0.0;
      $cpueff     *= 100; # convert to percentage
      my $wtshare  = ($walltime_t) ? $walltime*100/$walltime_t : 0.0;

      $groupInfo->{$group}{success_rate}   = $srate;
      $groupInfo->{$group}{cpueff}         = $cpueff;
      $groupInfo->{$group}{walltime_share} = $wtshare;
      $groupInfo->{$group}{avgwait}        = $avgwait;
      $groupInfo->{$group}{job_share}      = ($njobs_t) ? $njobs*100/$njobs_t : 0.0;
    }
    $self->{acctinfo}{data}{$ptag} = $groupInfo;
  }
}

sub collect 
{
  my $self = shift;
  my $config = LSF::ConfigReader->instance()->config;
  my $read_all = $config->{accounting}{read_all} || 0;

  # read the saved dictionary
  unless ($read_all) {
    $self->readStoredInfo;
    defined $self->{acctinfo}{data}{lday} or $read_all = 1;
  }

  # if acctinfo exists and is valid then try only add/delete delta
  if ($read_all) {
    $self->readAll;
  }
  else {
    my $dict = {
        lread_jid => $self->{acctinfo}{anchor}{lday}{lread_jid},
      lread_etime => $self->{acctinfo}{anchor}{lday}{lread_etime}
    };
    $self->addDelta($dict);
    $self->deleteDelta($dict);
  }
  $self->update;
}

sub readAll
{
  my $self = shift;
  my $config = LSF::ConfigReader->instance()->config;

  my $info = {};
  # Loop over files
  my @files = @{$self->getAcctFiles};
  for my $file (@files) {
    # first read the lsb.acct file directly
    my $jobinfo = __PACKAGE__->readAcctFile($file);

    # now use bacct to get the rest of the information
    my $jobList = __PACKAGE__->exec_bacct($file);

    for (@$jobList) {
      chop;
      my $dict = $self->parseLine($_, $jobinfo);
      defined $dict or next;
      $self->addToAcctinfo($dict, 1);
      $info->{jid}   = $dict->{jid};
      $info->{etime} = $dict->{etime};
    }
  }
  $self->setLastEntry({jid => $info->{jid}, etime => $info->{etime}})
    if exists $info->{jid};
}

sub readStoredInfo
{
  my $self = shift;

  my $config = LSF::ConfigReader->instance()->config;
  my $dbfile = $config->{accounting}{dbFile};

  my $acctinfo = restoreInfo($dbfile);
  $self->{acctinfo} = $acctinfo;
}

sub saveInfo
{
  my $self = shift;
  my $config   = LSF::ConfigReader->instance()->config;
  my $verbose  = $config->{accounting}{verbose} || 0;
  my $dbfile   = $config->{accounting}{dbFile};
  my $acctinfo = $self->{acctinfo};

  storeInfo($dbfile, $acctinfo);
}

sub prepare
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;

  my $config = LSF::ConfigReader->instance()->config;
  my $colorDict = $config->{plotcreator}{colorDict} || {};

  my $format = (exists $attr->{format}) ? $attr->{format} : qq|%5.1f|;
  my $limit  = (exists $attr->{limit})  ? $attr->{limit}     
                                        : $config->{plotcreator}{minReq}{common};
  my $minJobs   = (exists $attr->{minJobs})   ? $attr->{minJobs}   : 1;
  my $addOthers = (exists $attr->{addOthers}) ? $attr->{addOthers} : 0;
  my $orderem   = (exists $attr->{order})     ? $attr->{order}     : 1;

  my $period = $attr->{period};
  my $tag    = $attr->{tag};  # job_share used for legends as well
  my $groupInfo = $self->{acctinfo}{data}{$period};

  my $data = [];
  my $sum = 0;
  my @groupList = sort { $groupInfo->{$b}{$tag} <=> $groupInfo->{$a}{$tag} } keys %$groupInfo;

  # we accept all the entries passing minJobs for the legends
  my $max_entries_allowed  = (defined $attr->{max_entries} and $attr->{max_entries}>0) 
     ? $attr->{max_entries} 
     : scalar @groupList;

  my $n_entries = 0;
  for my $group (@groupList) {
    my $njobs = $groupInfo->{$group}{jobs};
    next if $njobs < $minJobs;

    my $value = $groupInfo->{$group}{$tag};
    if ($n_entries >= $max_entries_allowed or $value <= $limit) {
      $sum += $value;
    }
    else {
      my $color = (exists $colorDict->{$group}) 
                      ? $colorDict->{$group} 
                      : $config->{plotcreator}{defaultColor};
      my $formatted_value = sprintf $format, $value;
      my $info = { 
         name => $group, 
        color => $color, 
        value => trim($formatted_value)
      };
      push @$data, $info;
    }
    ++$n_entries;
  }
  if ($addOthers) {
    my $formatted_sum = sprintf $format, $sum;
    my $info = { 
       name => q|others|, 
      color => $config->{plotcreator}{defaultColor}, 
      value => trim ($formatted_sum)
    };
    push @$data, $info;
  }
  # sort the array in descending order (by default)
  @$data = sort { $b->{value} <=> $a->{value} } @$data if $orderem; 
  $data;
}

sub jobShare
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $period  = $attr->{ptag};
  my $minJobs = $attr->{minJobs};
  my $data = $self->prepare({ 
          period => $period, 
         minJobs => $minJobs,
             tag => q|job_share|, 
          format => qq|%-5.1f|,
           limit => $config->{plotcreator}{minReq}{jobShare} || 2,
     max_entries => $config->{plotcreator}{image}{pie}{max_entries} || 10,
       addOthers => 1
  });
  return unless scalar @$data;
  if ($verbose) {
    print "Accounting::jobShare, period $period => \n";
    print Data::Dumper->Dump([$data], [qw/data/]);
  }
  my $image  = plotPie(q|Job Share (%)|, __PACKAGE__->transform($data), 3);
  my $width  = $config->{plotcreator}{image}{pie}{width} || 200;
  my $height = $config->{plotcreator}{image}{pie}{height} || 180;
  my $imageDir = qq|$config->{baseDir}/images/accounting|;
  createPNGWithIM({ 
     image => $image, 
     width => $width, 
    height => $height, 
      file => qq|$imageDir/${period}_jobshare.png| 
  });
}

sub walltimeShare
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $period  = $attr->{ptag};
  my $minJobs = $attr->{minJobs};
  my $data = $self->prepare({ 
          period => $period, 
         minJobs => $minJobs,
             tag => q|walltime_share|, 
          format => qq|%-5.1f|,
           limit => $config->{plotcreator}{minReq}{wtimeShare} || 3,
     max_entries => $config->{plotcreator}{image}{pie}{max_entries} || 10,
       addOthers => 1
  });
  return unless scalar @$data;
  if ($verbose) {
    print "Accounting::jobShare, period $period => \n";
    print Data::Dumper->Dump([$data], [qw/data/]);
  }

  my $image    = plotPie(q|Walltime Share (%)|, __PACKAGE__->transform($data), 3);
  my $width    = $config->{plotcreator}{image}{pie}{width} || 200;
  my $height   = $config->{plotcreator}{image}{pie}{height} || 180;
  my $imageDir = qq|$config->{baseDir}/images/accounting|;
  createPNGWithIM({ 
     image => $image, 
     width => $width, 
    height => $height, 
      file => qq|$imageDir/${period}_wtshare.png| 
  });
}

sub cpuEfficiency
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $period  = $attr->{ptag};
  my $minJobs = $attr->{minJobs};
  my $data = $self->prepare({ 
          period => $period, 
         minJobs => $minJobs,
             tag => q|cpueff|, 
          format => qq|%-5.1f|, 
           limit => $config->{plotcreator}{minReq}{cpuEff} || 25,
     max_entries => $config->{plotcreator}{image}{bar}{max_entries} || 10,
  });
  return unless scalar @$data;
  if ($verbose) {
    print "Accounting::jobShare, period $period => \n";
    print Data::Dumper->Dump([$data], [qw/data/]);
  }

  my $image = plotBar(q|CPU Effi.|, q|AcctGroup|, q|Eff in %|, __PACKAGE__->transform($data));
  my $imageDir = qq|$config->{baseDir}/images/accounting|;
  createPNG($image, qq|$imageDir/${period}_cpueff.png|);
}

sub avgWait
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $minJobs = $attr->{minJobs};
  my $period  = $attr->{ptag};

  my $groupInfo = $self->{acctinfo}{data}{$period};
  my @groupList = sort keys %$groupInfo;
  my @avgwait_tmp = ();
  for my $group (@groupList) {
    my $njobs = $groupInfo->{$group}{jobs};
    next unless $njobs > $minJobs;
    push @avgwait_tmp, $groupInfo->{$group}{avgwait};
  }
  my $maxv = max(@avgwait_tmp) || 0;
  my $data = $self->prepare({ 
         period => $period, 
        minJobs => $minJobs,
            tag => q|avgwait|, 
         format => qq|%u|, 
          limit => (($config->{plotcreator}{minReq}{avgWait} || 0.05 ) * $maxv),
    max_entries => ($config->{plotcreator}{image}{bar}{max_entries} || 10),
  });
  return unless scalar @$data;
  if ($verbose) {
    print "Accounting::jobShare, period $period => \n";
    print Data::Dumper->Dump([$data], [qw/data/]);
  }

  my $image = plotBar(q|Avg. Wait|, q|AcctGroup|, q|Avg Wait in secs|, __PACKAGE__->transform($data));
  my $imageDir = qq|$config->{baseDir}/images/accounting|;
  createPNG($image, qq|$imageDir/${period}_avgwait.png|);
}
 
sub legends
{
  my ($self, $attr) = @_;
  carp qq|Hash \$attr undefined!| and return unless defined $attr;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{accounting}{verbose} || 0;

  my $period = $attr->{ptag};
  my $minJobs = $attr->{minJobs};
  # Note that for the legends value is irrelevant
  my $data = $self->prepare({ 
          period => $period, 
         minJobs => $minJobs,
             tag => q|job_share|, 
          format => qq|%5.1f|,
           limit => -1.0,
       addOthers => 1
  });
  return unless scalar @$data;
  if ($verbose) {
    print "Accounting::legends, period $period => \n";
    print Data::Dumper->Dump([$data], [qw/data/]);
  }

  my $image = drawLegends(__PACKAGE__->transform($data));
  my $imageDir = qq|$config->{baseDir}/images/accounting|;
  createPNG($image, qq|$imageDir/${period}_legends.png|);
}

sub createPlots
{
  my ($self, $option) = @_;
  $self->jobShare($option);
  $self->walltimeShare($option);
  $self->cpuEfficiency($option);
  $self->avgWait($option);
  $self->legends($option);
}

sub transform
{
  my ($pkg, $data) = @_;
  my $trans = [];
  for my $info (@$data) {
    push @{$trans->[0]}, $info->{color};
    push @{$trans->[1]}, $info->{name};
    push @{$trans->[2]}, $info->{value};
  }
  $trans;
}

1;
__END__
