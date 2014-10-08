package Collector::GridiceInfo;

use strict;
use warnings;
use Carp;

use Collector::ConfigReader;
use Collector::ObjectFactory;
use Collector::Util qw/restoreInfo/;

use Collector::JobList;

$Collector::GridiceInfo::VERSION = q|1.0|;
our $batchAttr =
{
     lsf => q|Collector::LSF::JobList|,
     pbs => q|Collector::PBS::JobList|,
  condor => q|Collector::Condor::JobList|
};

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 
  my $self = bless {}, $class;

  $self->_initialize();
  $self;
}

sub _initialize
{
  my $self = shift;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;

  my $baseDir   = $config->{baseDir} || q|/opt|;
  my $cacheLife = $config->{cachelife}{jobinfo} || 240; # seconds
  my $inputFile = qq|$baseDir/jobmon/data/jobs.db|;

  my $readFromCache = 0;
  if (-e $inputFile) {
    # last modification time
    my $age = time() - (stat $inputFile)[9];
    $readFromCache = 1 if $age < $cacheLife;
  }
  my $joblist = undef;
  if ($readFromCache) {
    print STDERR qq|INFO. Reading cached information from $inputFile\n|;
    $joblist = restoreInfo($inputFile);
  }
  else {
    my $lrms  = $config->{lrms}     || croak qq|Batch system not specified in config.pl!|;
    my $class = $batchAttr->{$lrms} || croak qq|Batch system $lrms not supported!|;
    my $jColl = Collector::ObjectFactory->instantiate($class);
    $joblist = $jColl->jobinfo; # (a JID,jobinfo hash)
  }
  return unless defined $joblist;

  $self->{info} = $joblist;
}

sub info
{
  my $self = shift;
  $self->{info};
}

1;
__END__
