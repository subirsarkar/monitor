package LSF::Hosts;

use strict;
use warnings;
use Data::Dumper;

use LSF::ConfigReader;
use LSF::Util qw/trim commandFH/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $config = LSF::ConfigReader->instance()->config;
  my $hosts_toskip = $config->{overview}{hosts_toskip} || [];
  my $verbose = $config->{verbose} || 0;

  # Batch slots
  my ($maxSlots, $okSlots, $jobSlots, $runSlots) = (0,0,0,0);
  my $command = q|bhosts -w|;
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while (my $line = $fh->getline) {
      next if $line =~ /unavail|unreach/;
      my ($host, $status, $jmax, $njobs, $nrun) = (split /\s+/, trim($line))[0,1,3,4,5];
      next if grep /$host/, @$hosts_toskip;

      $maxSlots += $jmax;

      $status =~ /ok|closed_Full|closed_LIM|closed_Excl/ or next;
      $okSlots  += $jmax; 
      $jobSlots += $njobs;
      $runSlots += $nrun;
    }
    $fh->close;
  }
  my $info = 
  {
          max => $maxSlots,
    available => $okSlots,
          job => $jobSlots,
      running => $runSlots
  };
  bless {
    _info => $info
  }, $class;
}
sub info
{
  my $self = shift;
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  print Data::Dumper->Dump([$info], [qw/info/]); 
}

1;
__END__
package main;
my $obj = LSF::Hosts->new;
$obj->show;
