package Collector::PBS::Overview;

use strict;
use warnings;
use Carp;

use POSIX qw/strftime/;
use Data::Dumper;
$Data::Dumper::Purity = 1;
use List::Util qw/max min/;
use File::stat;

use Collector::Util qw/trim 
                       getCommandOutput 
                       updateSlotDB
                       file_age
                       getParser
                       storeInfo 
                       restoreInfo/;
use Collector::ConfigReader;
use Collector::PBS::JobList;

our $smap = 
{
  R => q|nrun|,
  Q => q|npend|,
  W => q|npend|,
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
sub parse_showq
{
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $show_error = $config->{show_cmd_error} || 0;
  my $verbose    = $config->{verbose} || 0;

  # Batch slots
  my $command = q|showq|;
  print "$command\n" if $verbose;

  my $ecode = 0;
  chomp(my @lines = grep { /Processors Active/ } 
    getCommandOutput($command, \$ecode, $show_error, $verbose));
  print join("\n", @lines), "\n" if $verbose;
  my ($claimed, $available, $maxs) 
     = (split /\s+/, trim $lines[0])[0,5,5];
  my $free = $available - $claimed;
  {
          maxs => $maxs || 0,
     available => $available || 0,
       claimed => $claimed || 0,
          free => $free
  };
}
sub parse_pbsnodes_text
{
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $domain     = $config->{domain};
  my $show_error = $config->{show_cmd_error} || 0;
  my $verbose    = $config->{verbose} || 0;

  my $ecode = 0;
  my $command = q|pbsnodes -a|;
  chop(my $text = 
    getCommandOutput($command, \$ecode, $show_error, $verbose));
  my @blocks = split /$domain\n/, $text;
  shift @blocks;

  my $info = {maxs => 0,
         available => 0,
           claimed => 0};
  for my $block (@blocks) {
    my $elinfo = {};
    my @lines = split /\n/, $block;
    for my $line (@lines) {
      next if $line =~ /^$/;
      next unless $line =~ /=/;
      my ($name, $value) = map {trim $_ } (split /=/, $line);
      $elinfo->{$name} = $value;
    }
    my $np = $elinfo->{pcpus} || 0;
    $info->{maxs} += $np;
    if (defined $elinfo->{state} and $elinfo->{state} ne 'down') {
      $info->{available} += $np;
      if (defined $elinfo->{jobs}) {
        my $jobs = $elinfo->{jobs};
        my @list = split /,/, $jobs;
        my $njobs = scalar @list;
        $info->{claimed} += $njobs;
      }
    }
  }
  $info->{free} = $info->{available} - $info->{claimed};
  $info;
}
sub parse_pbsnodes_xml
{
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $show_error = $config->{show_cmd_error} || 0;
  my $verbose    = $config->{verbose} || 0;

  my $ecode = 0;
  my $command = q|pbsnodes -x|;
  chop(my $xml = 
     getCommandOutput($command, \$ecode, $show_error, $verbose));

  my $xmlstr = qq|<?xml version="1.0" standalone="yes"?>\n$xml|;
  # create the XML parser
  my $xp = getParser({xml => $xmlstr});  
  croak q|Error parsing XML input| unless defined $xp;

  my $info = {maxs => 0,
         available => 0,
           claimed => 0};
  foreach my $node ($xp->find(q|/Data/Node|)->get_nodelist) {
    my $elinfo = {};
    for my $cnode ($node->getChildNodes) {
      my $name  = $cnode->getName;
      my $value = $cnode->string_value;
      $elinfo->{$name} = $value;
    }
    my $np = $elinfo->{np} || ($elinfo->{pcpus} || 0);
    $info->{maxs} += $np;
    if (defined $elinfo->{state} and $elinfo->{state} ne 'down') {
      $info->{available} += $np;
      if (defined $elinfo->{jobs}) {
	my $jobs = $elinfo->{jobs};
	my @list = split /,/, $jobs;
	my $njobs = scalar @list;
	$info->{claimed} += $njobs;
      }
    }
  }
  $info->{free} = $info->{available} - $info->{claimed};
  $info;
}
sub _initialize
{
  my $self = shift;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $slotDB   = $config->{db}{slot};
  my $verbose  = $config->{verbose} || 0;
  my $has_maui = $config->{has_maui} || 0;
  my $show_fairshare = (exists $config->{show_table}{fairshare}) 
    ? $config->{show_table}{fairshare} : 1;

  my $sinfo = ($has_maui > 0) ? parse_showq : parse_pbsnodes_text;
  print Data::Dumper->Dump([$sinfo],  [qw/sinfo/]); 

  my $maxever = updateSlotDB($sinfo->{maxs});
  my $slotinfo = 
  {
      maxever => $maxever,
          max => $sinfo->{maxs},
    available => $sinfo->{available},
      running => $sinfo->{claimed},
         free => $sinfo->{free}
  };

  my $jobinfo = {njobs => 0,
                  nrun => 0,
                 npend => 0,
                 nheld => 0,
               cputime => 0,
              walltime => 0,
               ratio10 => 0};
  my $userinfo  = {};
  my $groupinfo = {};
  my $ceinfo    = {};
  my $jobs = new Collector::PBS::JobList;
  my $joblist = $jobs->list; # returns a hash reference
  for my $job (values %$joblist) {
    my $dn     = $job->SUBJECT;
    my $user   = $job->USER;
    my $status = $job->STATUS;
    my $group  = $job->GROUP;
    my $ceid   = $job->GRID_CE;
    my $ce     = (split m#\/#, $ceid)[0];

    $jobinfo->{njobs}++;
    $groupinfo->{$group}{njobs}++;
    $ceinfo->{$ce}{njobs}++;
    $userinfo->{$dn}{njobs}++;
    $userinfo->{$dn}{user}  = $user  unless exists $userinfo->{$dn}{user};
    $userinfo->{$dn}{group} = $group unless exists $userinfo->{$dn}{group};

    defined $smap->{$status} or next;
    my $tag = $smap->{$status};
    $jobinfo->{$tag}++;
    $groupinfo->{$group}{$tag}++;
    $ceinfo->{$ce}{$tag}++;
    $userinfo->{$dn}{$tag}++;
    if ($status eq 'R') {
      my $cputime  = $job->CPUTIME  || 0.0;
      my $walltime = $job->WALLTIME || 0.0;

      $jobinfo->{cputime}  += $cputime;
      $jobinfo->{walltime} += $walltime;

      $groupinfo->{$group}{cputime}  += $cputime;
      $groupinfo->{$group}{walltime} += $walltime;

      $ceinfo->{$ce}{cputime}  += $cputime;
      $ceinfo->{$ce}{walltime} += $walltime;

      $userinfo->{$dn}{cputime}  += $cputime;
      $userinfo->{$dn}{walltime} += $walltime;

      my $ratio = min 1, (($walltime>0) ? $cputime/$walltime : 0);
      if ($ratio < 0.1) {
        ++$jobinfo->{ratio10};
        ++$groupinfo->{$group}{ratio10};
        ++$ceinfo->{$ce}{ratio10};
        ++$userinfo->{$dn}{ratio10};
      }
    }
  }
  for my $info ($groupinfo, $ceinfo, $userinfo) {
    for my $el (sort keys %$info) {
      $info->{$el}{njobs}    = 0 unless defined $info->{$el}{njobs};
      $info->{$el}{nrun}     = 0 unless defined $info->{$el}{nrun};
      $info->{$el}{npend}    = 0 unless defined $info->{$el}{npend};
      $info->{$el}{nheld}    = 0 unless defined $info->{$el}{nheld};
      $info->{$el}{cputime}  = 0 unless (defined $info->{$el}{cputime} and $info->{$el}{cputime}>0);
      $info->{$el}{walltime} = 0 unless (defined $info->{$el}{walltime} and $info->{$el}{walltime}>0);
      $info->{$el}{ratio10}  = 0 unless defined $info->{$el}{ratio10};
    }
  }

  if ($verbose) {
    print Data::Dumper->Dump([$slotinfo],  [qw/slotinfo/]); 
    print Data::Dumper->Dump([$jobinfo],   [qw/jobinfo/]); 
    print Data::Dumper->Dump([$ceinfo],    [qw/ceinfo/]);
    print Data::Dumper->Dump([$groupinfo], [qw/groupinfo/]);
    print Data::Dumper->Dump([$userinfo],  [qw/userinfo/]);
  }
  # now add them to the object
  $self->{_slotinfo}  = $slotinfo;
  $self->{_jobinfo}   = $jobinfo;
  $self->{_groupinfo} = $groupinfo;
  $self->{_ceinfo}    = $ceinfo;
  $self->{_userinfo}  = $userinfo;
  $self->{_priority}  = $self->getPriority if $show_fairshare;
  $self->{_joblist}   = $joblist;
}

sub getPriority
{
  my $self = shift;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $priorityDB = $config->{db}{priority};
  my $show_error = $config->{show_cmd_error} || 0;
  my $verbose    = $config->{verbose} || 0;

  my $output = '';
  if ( -r $priorityDB and file_age($priorityDB) < 300) {
    print ">>> Overview::getPriority: read priority table from cache $priorityDB\n";
    my $info = restoreInfo($priorityDB);
    $output = $info->{text};
  }
  else {
    my $command = q|diagnose -f|;
    my $ecode = 0; 
    chop($output = getCommandOutput($command, \$ecode, $show_error, $verbose));
    my $info = {text => $output};
    storeInfo($priorityDB, $info);
  }
  $output;
}

1;
__END__
my $obj = new Collector::PBS::Overview;
