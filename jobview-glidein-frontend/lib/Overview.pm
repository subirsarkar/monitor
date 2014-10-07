package Overview;

use strict;
use warnings;

use IO::File;
use POSIX qw/strftime/;
use Data::Dumper;
$Data::Dumper::Purity = 1;
use List::Util qw/max min/;
use File::stat;

use Util qw/trim 
            show_message
            commandFH
            getCommandOutput
            storeInfo 
            restoreInfo/;
use ConfigReader;
use JobList;
use JobInfo;

use constant MINUTE => 60;
use constant HOUR   => 60 * MINUTE;

our $smap = 
{
  R => q|nrun|,
  Q => q|npend|,
  H => q|nheld|
};
sub new
{
  my $this = shift;
  my $class = ref $this || $this;

  my $self = bless {}, $class;
  $self->_initialize;
  $self;
}
sub _initialize
{
  my $self = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $collector  = $config->{collector};
  my $slotDB     = $config->{db}{slot} || qq|$config->{baseDir}/db/slots.db|;
  my $ce2siteDB  = $config->{db}{ce2site} || qq|$config->{baseDir}/db/ce2site.db|;
  my $verbose    = $config->{verbose} || 0;
  my $time_cmd   = $config->{time_cmd} || 0;
  my $show_error = $config->{show_cmd_error} || 0;
  my $min_walltime_reqd = $config->{min_walltime_reqd} || 10;

  # Batch slots
  # time the Condor commands
  my $time_a = time;
  my $command = <<"END";
condor_status -pool $collector \\
              -format "%s!" State \\
              -format "%s!" Machine \\
              -format "%d!" SlotID \\
              -format "%V!" TotalMemory \\
              -format "%V!" TotalLoadAvg \\
              -format "%d!" MyCurrentTime \\
              -format "%s\\n" GlobalJobId \\
END
  $command .=  q| -constraint 'State != "Owner"'|;
  $command .= qq| -constraint '$config->{constraint}{condor_status}'|
    if defined $config->{constraint}{condor_status};
  print $command;

  my ($total, $claimed, $unclaimed) = (0, 0, 0);
  my $dict = {};
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      $line =~ s/"//;
      ++$total; 
      my ($state, $name, $slotid, $memory, $load, $time, $jid) 
         = (split /!/, trim $line);
      ($state eq 'Claimed') ? ++$claimed : ++$unclaimed;
      $name = qq|slot$slotid\@$name|;
      next if ($jid eq 'undefined' or $state ne 'Claimed');
      $dict->{$name} = 
      {
                 State => $state,
           GlobalJobId => $jid,
           TotalMemory => (($memory ne 'undefined') ? $memory : 0),
          TotalLoadAvg => (($load ne 'undefined') ? $load : 0),
         MyCurrentTime => $time
      };
    }
    $fh->close;
  }
  show_message ">>> Overview::condor_status: elapsed time = ". (time() - $time_a) . " second(s)"
    if $time_cmd;

  my $max = $self->updateSlotDB($dict);
  my $slots = {
          max => $total,
    available => $total,
      running => $claimed,
         free => $unclaimed
  };

  my $jobinfo = {
       njobs => 0,
       nrun  => 0,
       npend => 0,
       nheld => 0,
     cputime => 0,
    walltime => 0,
     ratio10 => 0
  };
  my $userinfo   = {};
  my $groupinfo  = {};
  my $ceinfo     = {};
  my $userceinfo = {};
  my $usersiteinfo = {};
  my $jobs = JobList->new;
  my $joblist = $jobs->list; # returns a hash reference
  my $ce2site = (-r $ce2siteDB) ? restoreInfo($ce2siteDB) : {};
  while ( my ($jid, $job) = each %$joblist ) {
    my $dn     = $job->SUBJECT;
    my $user   = $job->USER;
    my $status = $job->STATUS;
    my $ce     = $job->GRID_CE || q|glidein frontend|;
    my $site   = $job->GRID_SITE;
    $ce2site->{$ce} = $site if (defined $site and not defined $ce2site->{$ce});
    $site = $ce2site->{$ce} || ($config->{site} || q|T2_US_UCSD|);

    $jobinfo->{njobs}++;
    $ceinfo->{$ce}{$site}{njobs}++;

    $userinfo->{$dn}{njobs}++;
    $userinfo->{$dn}{user} = $user unless exists $userinfo->{$dn}{user};

    $userceinfo->{$dn}{$ce}{njobs}++;
    $userceinfo->{$dn}{$ce}{user} = $user unless exists $userceinfo->{$dn}{$ce}{user};

    $usersiteinfo->{$dn}{$site}{njobs}++;
    $usersiteinfo->{$dn}{$site}{user} = $user unless exists $usersiteinfo->{$dn}{$site}{user};

    defined $smap->{$status} or next;
    my $tag = $smap->{$status};
    $jobinfo->{$tag}++;
    $ceinfo->{$ce}{$site}{$tag}++;
    $userinfo->{$dn}{$tag}++;
    $userceinfo->{$dn}{$ce}{$tag}++;
    $usersiteinfo->{$dn}{$site}{$tag}++;
    if ($status eq 'R') {
      my $cputime = $job->CPUTIME || 0.0;
      my $walltime = $job->WALLTIME || 0.0;

      my $accept_job = ($walltime > $min_walltime_reqd * MINUTE or $cputime > 0);
      $accept_job = 0 if ($walltime > 6 * HOUR and $cputime < MINUTE);
      if ($accept_job) {
        $jobinfo->{cputime}  += $cputime;
        $jobinfo->{walltime} += $walltime;

        $ceinfo->{$ce}{$site}{cputime}  += $cputime;
        $ceinfo->{$ce}{$site}{walltime} += $walltime;

        $userinfo->{$dn}{cputime}  += $cputime;
        $userinfo->{$dn}{walltime} += $walltime;
        $userceinfo->{$dn}{$ce}{cputime} += $cputime;
        $userceinfo->{$dn}{$ce}{walltime} += $walltime;
        $usersiteinfo->{$dn}{$site}{cputime} += $cputime;
        $usersiteinfo->{$dn}{$site}{walltime} += $walltime;
      }
      my $ratio = min 1, (($walltime>0) ? $cputime/$walltime : 0);
      if ($ratio < 0.1) {
        ++$jobinfo->{ratio10};
        ++$ceinfo->{$ce}{$site}{ratio10};
        ++$userinfo->{$dn}{ratio10};
        ++$userceinfo->{$dn}{$ce}{ratio10};
        ++$usersiteinfo->{$dn}{$site}{ratio10};
      }
    }
  }
  storeInfo($ce2siteDB, $ce2site);

  while ( my ($ce) = each %$ceinfo ) {
    my $sites = $ceinfo->{$ce};
    while (my ($site) = each %$sites ) {
      $ceinfo->{$ce}{$site}{njobs}  = 0 unless defined $ceinfo->{$ce}{$site}{njobs};
      $ceinfo->{$ce}{$site}{nrun}   = 0 unless defined $ceinfo->{$ce}{$site}{nrun};
      $ceinfo->{$ce}{$site}{npend}  = 0 unless defined $ceinfo->{$ce}{$site}{npend};
      $ceinfo->{$ce}{$site}{nheld}  = 0 unless defined $ceinfo->{$ce}{$site}{nheld};
      $ceinfo->{$ce}{$site}{cputime} = 0 
          unless (defined $ceinfo->{$ce}{$site}{cputime} and $ceinfo->{$ce}{$site}{cputime}>0);
      $ceinfo->{$ce}{$site}{walltime} = 0 
          unless (defined $ceinfo->{$ce}{$site}{walltime} and $ceinfo->{$ce}{$site}{walltime}>0);
      $ceinfo->{$ce}{$site}{ratio10}  = 0 unless defined $ceinfo->{$ce}{$site}{ratio10};
    }
  }
  while ( my ($dn) = each %$userinfo ) {
    $userinfo->{$dn}{njobs}  = 0 unless defined $userinfo->{$dn}{njobs};
    $userinfo->{$dn}{nrun}   = 0 unless defined $userinfo->{$dn}{nrun};
    $userinfo->{$dn}{npend}  = 0 unless defined $userinfo->{$dn}{npend};
    $userinfo->{$dn}{nheld}  = 0 unless defined $userinfo->{$dn}{nheld};
    $userinfo->{$dn}{cputime} = 0 
      unless (defined $userinfo->{$dn}{cputime} and $userinfo->{$dn}{cputime}>0);
    $userinfo->{$dn}{walltime} = 0 
      unless (defined $userinfo->{$dn}{walltime} and $userinfo->{$dn}{walltime}>0);
    $userinfo->{$dn}{ratio10}  = 0 unless defined $userinfo->{$dn}{ratio10};
  }
  while ( my ($dn) = each %$userceinfo ) {
    my $ceinfo = $userceinfo->{$dn};
    while (my ($ce) = each %$ceinfo ) {
      $userceinfo->{$dn}{$ce}{njobs}  = 0 unless defined $userceinfo->{$dn}{$ce}{njobs};
      $userceinfo->{$dn}{$ce}{nrun}   = 0 unless defined $userceinfo->{$dn}{$ce}{nrun};
      $userceinfo->{$dn}{$ce}{npend}  = 0 unless defined $userceinfo->{$dn}{$ce}{npend};
      $userceinfo->{$dn}{$ce}{nheld}  = 0 unless defined $userceinfo->{$dn}{$ce}{nheld};
      $userceinfo->{$dn}{$ce}{cputime} = 0 
        unless (defined $userceinfo->{$dn}{$ce}{cputime} and $userceinfo->{$dn}{$ce}{cputime}>0);
      $userceinfo->{$dn}{$ce}{walltime} = 0 
        unless (defined $userceinfo->{$dn}{$ce}{walltime} and $userceinfo->{$dn}{$ce}{walltime}>0);
      $userceinfo->{$dn}{$ce}{ratio10}  = 0 unless defined $userceinfo->{$dn}{$ce}{ratio10};
    }
  }

  while ( my ($dn) = each %$usersiteinfo ) {
    my $siteinfo = $usersiteinfo->{$dn};
    while (my ($site) = each %$siteinfo ) {
      $usersiteinfo->{$dn}{$site}{njobs}  = 0 unless defined $usersiteinfo->{$dn}{$site}{njobs};
      $usersiteinfo->{$dn}{$site}{nrun}   = 0 unless defined $usersiteinfo->{$dn}{$site}{nrun};
      $usersiteinfo->{$dn}{$site}{npend}  = 0 unless defined $usersiteinfo->{$dn}{$site}{npend};
      $usersiteinfo->{$dn}{$site}{nheld}  = 0 unless defined $usersiteinfo->{$dn}{$site}{nheld};
      $usersiteinfo->{$dn}{$site}{cputime} = 0 
        unless (defined $usersiteinfo->{$dn}{$site}{cputime} and $usersiteinfo->{$dn}{$site}{cputime}>0);
      $usersiteinfo->{$dn}{$site}{walltime} = 0 
        unless (defined $usersiteinfo->{$dn}{$site}{walltime} and $usersiteinfo->{$dn}{$site}{walltime}>0);
      $usersiteinfo->{$dn}{$site}{ratio10}  = 0 unless defined $usersiteinfo->{$dn}{$site}{ratio10};
    }
  }
  if ($verbose) {
    print Data::Dumper->Dump([$slots],   [qw/slots/]); 
    print Data::Dumper->Dump([$jobinfo], [qw/jobinfo/]); 
    print Data::Dumper->Dump([$ceinfo],  [qw/ceinfo/]);
    print Data::Dumper->Dump([$userinfo],[qw/userinfo/]);
    print Data::Dumper->Dump([$userceinfo],[qw/userceinfo/]);
    print Data::Dumper->Dump([$usersiteinfo],[qw/usersiteinfo/]);
  }
  # now add them to the object
  $self->{slots}    = $slots;
  $self->{jobinfo}  = $jobinfo;
  $self->{ceinfo}   = $ceinfo;
  $self->{userinfo} = $userinfo;
  $self->{userceinfo} = $userceinfo;
  $self->{usersiteinfo} = $usersiteinfo;
}
sub updateSlotDB
{
  my ($self, $info) = @_;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $slotDB = $config->{db}{slot} || qq|$config->{baseDir}/db/slots.db|;
  my $novm   = $config->{db}{novm} || qq|$config->{baseDir}/db/novm.txt|;
  my $mentries = 0;
  if ( -r $slotDB ) {
    my $dbinfo = restoreInfo($slotDB);
    my $neli   = scalar keys %$dbinfo; 

    # present in DB but not in the present iteration
    my $fh = IO::File->new($novm, 'w');
    if (defined $fh and $fh->opened) {
      for my $el (sort keys %$dbinfo) {
        unless (exists $info->{$el}) { 
          printf $fh qq#%34s|%10s|%40s|%8d|%7.3f|%d\n#, 
                $el, 
                $dbinfo->{$el}{State},
                $dbinfo->{$el}{GlobalJobId},
                $dbinfo->{$el}{TotalMemory},
    	        $dbinfo->{$el}{TotalLoadAvg},
                $dbinfo->{$el}{MyCurrentTime};
        }
      }
      $fh->close;
    }
    else {
      warn qq|Failed to open $novm, $!|;
    } 
    
    # present in the present iteration but not in DB
    for my $el (sort keys %$info) {
      exists $dbinfo->{$el} or $dbinfo->{$el} = $info->{$el};
    }
    my $nelj = scalar keys %$dbinfo; 
    storeInfo($slotDB, $dbinfo) if $nelj > $neli;
    $mentries = max $neli, $nelj;
  }
  else {
    storeInfo($slotDB, $info);
    $mentries = scalar keys %$info;
  }
  $mentries;
}
sub getPriority
{
  my $self = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $priorityDB = $config->{db}{priority};
  my $verbose = $config->{verbose} || 0;

  my $output = '';
  if (-r $priorityDB and file_age($priorityDB) < 3600) {
    show_message qq|>>> Overview::getPriority: read priority table from cache $priorityDB|;
    my $info = restoreInfo($priorityDB);
    $output = $info->{text};
  }
  else {
    my $collector = $config->{collector};
    my $command = qq|condor_userprio -pool $collector -all|;
    print $command, "\n";
    my $ecode = 0; 
    chop($output = getCommandOutput($command, \$ecode));
    my $info = {text => $output};
    storeInfo($priorityDB, $info);
  }
  $output;
}
sub file_age
{
  my $file = shift;
  time() - stat($file)->mtime;
}

1;
__END__
my $obj = Overview->new;
