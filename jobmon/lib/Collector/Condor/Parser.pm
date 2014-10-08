package Collector::Condor::Parser;

use strict;
use warnings;
use Carp;

use Collector::Util qw/trim readFile/;
use Collector::Parser;

use base 'Collector::Parser';

our $VERSION = qq|0.1|;

sub new($$)
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  croak qq|Must specify JID!| unless ($attr and exists $attr->{jid});

  my $self = SUPER::new $class();
  bless $self, $class;

  $self->_initialize($attr);
  $self;
}

sub _initialize($$) 
{
  my ($self, $attr) = @_;
  my $jid = $attr->{jid};

  my $info = {};
  $self->info($info);

  # Read the config in any case
  my $reader = new Collector::ConfigReader;
  my $config = $reader->config;
  my $baseDir = $config->{baseDir};

  my $command = qq|$baseDir/jobmon/lib/Collector/Condor/findLogs.sh $jid|;
  chomp(my @content = getCommandOutput($command));
  return unless scalar @content; 
  my $file = $content[0]; 
  return if $file eq '?';

  chomp(my @lines = readFile($file));
  for (@lines) {
    if (/X509_USER_PROXY/         || 
        /GRID_JOBID/              || 
        /GRID_ID/                 ||
        /LOGNAME/                 || 
        /GLOBUS_GRAM_JOB_CONTACT/ || 
        /GATEKEEPER_JM_ID/        || 
        /GLOBUS_CE/)
    {
      next if (/^#/ || /ENV/);
      s/;\s+export(?:.*)//g;
      s/"/'/g;
      my @fields = (split /\,/);
      for (@fields) {
        my ($key, $value) = split /='/;
        $value =~ s/'//;
        $info->{trim($key)} = trim($value);
      }
    }
  }
}

1;
__END__
package main;
my $jid = shift || die qq|Usage: $0 jid|;
my $job = new Collector::Condor::Parser({jid => $jid});
$job->show;
