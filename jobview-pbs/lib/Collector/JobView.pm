package Collector::JobView;

use strict;
use warnings;
use Carp;

use Collector::ConfigReader;
use Collector::ObjectFactory;

$Collector::JobView::VERSION = q|0.1|;

our $batchClass = 
{ 
     lsf => q|Collector::LSF::Overview|,
     pbs => q|Collector::PBS::Overview|,
  condor => q|Collector::Condor::Overview|
};
our $AUTOLOAD;
my %fields = map { $_ => 1 }
     qw/slotinfo
        jobinfo
        groupinfo
        ceinfo
        userinfo
        priority/;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  my $self = bless { 
    _permitted => \%fields,
    _overview => undef,
  }, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;

  # read the configuration
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $lrms  = $config->{lrms} || croak q|Batch system no specified in config.pl!|;
  my $class = $batchClass->{lc $lrms} || croak qq|Batch attribute missing for $lrms!|;

  my $overview = Collector::ObjectFactory->instantiate($class);
  $self->{_overview} = $overview;
}
sub dump
{
  my $self = shift;
  my $stream = shift || *STDOUT;

  print $stream Data::Dumper->Dump([$self->slotinfo],  [qw/slots/]);
  print $stream Data::Dumper->Dump([$self->jobinfo],   [qw/jobinfo/]);
  print $stream Data::Dumper->Dump([$self->groupinfo], [qw/groupinfo/]);
  print $stream Data::Dumper->Dump([$self->ceinfo],    [qw/ceinfo/]);
  print $stream Data::Dumper->Dump([$self->userinfo],  [qw/userinfo/]);
  print $stream Data::Dumper->Dump([$self->priority],  [qw/priority/]);
}

sub show
{
  my $self = shift;
  my $stream = shift || *STDOUT;

  # Resources
  print $stream "=================\nResource\n=================\n";
  printf $stream  "%10s| %10s| %10s| %10s| %10s|\n", 
      q|MaxEver|, q|Max|, q|Available|, q|Occupied|, q|Free|;
  my $slots = $self->slotinfo;
  printf $stream  "%10d| %10d| %10d| %10d| %10d|\n", 
      $slots->{maxever}, 
      $slots->{max}, 
      $slots->{available}, 
      $slots->{running}, 
      $slots->{free};

  # Overall jobs
  print $stream "\n=================\nJobs\n=================\n";
  printf $stream  "%10s| %10s| %10s| %10s| %10s\n", 
      q|Total|, q|Running|, q|Pending|, q|Held|, q|CPU Eff(%)|;
  my $jobinfo = $self->jobinfo;
  my $nrun = $jobinfo->{nrun};
  my $cputime_t  = $jobinfo->{cputime};
  my $walltime_t = $jobinfo->{walltime};
  my $cpueff = ($walltime_t > 0)
       ? sprintf ("%-6.2f", max(0.0, $cputime_t*100.0/$walltime_t))
       : '-';
  printf $stream  "%10s| %10s| %10s| %10s| %10s\n", 
      $jobinfo->{njobs}, 
      $nrun, 
      $jobinfo->{npend}, 
      $jobinfo->{nheld}, 
      $cpueff;

  # Jobs by groups
  print $stream "\n=================\nJobs by Groups\n=================\n";
  printf $stream "%12s| %10s| %10s| %10s| %10s| %7s\n", 
      q|Group|, q|Total|, q|Running|, q|Pending|, q|Held|, q|CPU Eff(%)|;
  my $groupinfo = $self->groupinfo;
  for my $group (sort { $groupinfo->{$b}{nrun} <=> $groupinfo->{$a}{nrun} } keys %$groupinfo) {
    my $nrun  = $groupinfo->{$group}{nrun};
    my $npend = $groupinfo->{$group}{npend};
    my $cputime  = $groupinfo->{$group}{cputime};
    my $walltime = $groupinfo->{$group}{walltime};
    my $cpueff = ($walltime > 0)
         ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
         : '-';
    printf $stream  "%12s| %10d| %10d| %10d| %10d| %10s\n", 
      $group, 
      $groupinfo->{$group}{njobs}, 
      $nrun, 
      $npend, 
      $groupinfo->{$group}{nheld}, 
      $cpueff;
  }

  # Jobs by CE
  print $stream "\n=================\nJobs by CE\n=================\n";
  printf $stream "%22s| %10s| %10s| %10s| %10s| %10s\n", 
      q|CE|, q|Total|, q|Running|, q|Pending|, q|Held|, q|CPU Eff(%)|;
  my $ceinfo = $self->ceinfo;
  for my $ce (sort { $ceinfo->{$b}{nrun} <=> $ceinfo->{$a}{nrun} } keys %$ceinfo) {
    my $nrun = $ceinfo->{$ce}{nrun};
    my $cputime  = $ceinfo->{$ce}{cputime};
    my $walltime = $ceinfo->{$ce}{walltime};
    my $cpueff = ($walltime > 0)
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
       : '-';
    printf $stream "%22s| %10d| %10d| %10d| %10d %10s\n",
      $ce, 
      $ceinfo->{$ce}{njobs}, 
      $nrun, 
      $ceinfo->{$ce}{npend}, 
      $ceinfo->{$ce}{nheld}, 
      $cpueff;
  }  

  # Jobs by DN
  print $stream "\n=================\nJobs by DN\n=================\n";
  printf $stream "%10s| %10s| %10s| %10s| %10s| %10s| %s|\n", 
      q|Group|, 
      q|Total|, 
      q|Running|, 
      q|Pending|, 
      q|Held|, 
      q|CPU Eff|, 
      q|DN|;
  my $userinfo = $self->userinfo;
  for my $dn (sort { $userinfo->{$b}{nrun} <=> $userinfo->{$a}{nrun} } %$userinfo) {
    my $nrun = $userinfo->{$dn}{nrun};
    my $cputime  = $userinfo->{$dn}{cputime};
    my $walltime = $userinfo->{$dn}{walltime};
    my $cpueff = ($walltime > 0)
       ? sprintf ("%-6.2f", max(0.0, $cputime*100.0/$walltime))
       : '-';
    printf $stream  qq|%10s %10d %10d %10d %10d %10s %s\n|, 
      $userinfo->{$dn}{group},
      $userinfo->{$dn}{njobs},
      $nrun,
      $userinfo->{$dn}{npend},
      $userinfo->{$dn}{nheld},
      $cpueff,
      $dn;
  }
}
sub DESTROY
{
  my $self = shift;
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  ( defined $self->{_overview}{"_$name"} 
      ? $self->{_overview}{"_$name"} 
      : undef );
}

1;
__END__
