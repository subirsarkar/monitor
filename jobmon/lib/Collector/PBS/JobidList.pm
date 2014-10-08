package Collector::PBS::JobidList;

use strict;
use warnings;
use Carp;
use Net::Domain qw/hostname hostfqdn/;

use Collector::ConfigReader;
use Collector::Util qw/trim getCommandOutput/;
use base 'Collector::JobidList';
use Collector::PBS::JobList;

$Collector::PBS::JobidList::VERSION = q|1.0|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize();
  $self;
}

sub _initialize
{
  my $self = shift;

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $celist = $config->{site_ce}{list} || [];
  (scalar @$celist > 1) ? $self->_parse_multice
                        : $self->_parse_ce;
}
sub _parse_ce
{
  my $self = shift;

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose       = $config->{verbose} || 0;
  my $show_error    = $config->{show_cmd_error} || 0;
  my $queues_toskip = $config->{queues_toskip} || [];

  my $command = q|qstat -a|;
  $verbose and print STDERR "$command\n";
  my $ecode = 0;
  chomp(my @list = grep { /^\d+\./ }  # format: jid.(truncted hostfqdn)
    getCommandOutput($command, \$ecode, $show_error, $verbose));

  my $jidList = {};
  for my $line (@list) {
    my ($jtag, $queue, $status) = (split /\s+/, trim $line)[0,2,9];    
    next if (defined $queue and grep { $_ eq $queue } @$queues_toskip);

    my $jid = (split /\./, $jtag)[0]; # the remaining part is the truncated CE name
    $jidList->{$jid} = $status;
  }
  $self->list($jidList);
}

sub _parse_multice
{
  my $self = shift;

  # Read the config in any case
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose       = $config->{verbose} || 0;
  my $show_error    = $config->{show_cmd_error} || 0;
  my $queues_toskip = $config->{queues_toskip} || [];
  my $celist = $config->{site_ce}{list};  # asserted
  @$celist = map { lc $_ }
               map { (split /\./)[0] }
                 @$celist;
  my $master_ce = $config->{site_ce}{master};
  carp q|Master CE undefined on a multiple CE system, local jobs will not be available| 
    unless defined $master_ce;
  $master_ce = (split /\./, lc $master_ce)[0] if defined $master_ce;

  my $host = lc hostname; # short name
  my $iam_master = (defined $master_ce and $host eq $master_ce) ? 1 : 0;

  # Now get the fully specified name
  $host = lc hostfqdn;
  my $jobList = Collector::PBS::JobList->qstat_f;
  my $jidList = {};
  for my $jobInfo (@$jobList) {
    my @lines = map { trim $_ }   # that's schwartzian transformation
                  grep { $_ if length($_)>0 }
                    (split /\n/, $jobInfo);
    my $jid = shift @lines;
    $jid = (split /\./, $jid)[0];

    my $info = {};
    for (@lines) {
      my ($key, $value) = (split m#\s+=\s+#);
      next unless defined $value;
      next unless grep { $_ eq $key } qw/Job_Owner queue job_state/;
      if ($key eq q|Job_Owner|) {
        $info->{ceid} = (split /\@/, $value)[-1];
      }
      else {
	$info->{$key} = $value;
      }
    }
    # skip unwanted queues
    next unless defined $info->{ceid};  # mostly redundant
    next if (defined $info->{queue} and 
      grep { $_ eq $info->{queue} } @$queues_toskip);
    next unless Collector::PBS::JobList->keepJob({
           host => $host,
           ceid => $info->{ceid},
         celist => $celist,
      is_master => $iam_master
    });
    $jidList->{$jid} = $info->{job_state};
  }
  $self->list($jidList);
}

1;
__END__
package main;

my $job = new Collector::PBS::JobidList;
$job->show;
