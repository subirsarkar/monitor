package Collector::LSF::Parser;

use strict;
use warnings;
use Carp;
use File::Find;
use File::Basename;
use Data::Dumper;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       readFile 
                       filereadFH 
                       sortedList
                       storeInfo/;
use Collector::Parser;
use base 'Collector::Parser';

$Collector::LSF::Parser::VERSION = q|1.0|;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 

  croak q|Must specify a list of JIDs!| unless defined $attr->{joblist};

  my $self = SUPER::new $class();
  bless $self, $class;
  $self->_initialize($attr);
  $self;
}

sub _initialize
{
  my ($self, $attr) = @_;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $jobDir  = $config->{jobDir} || q|/usr/local/lsf/work/infn-pisa/logdir/info|;
  my $jidlist = $attr->{joblist};

  my $info = {};
  $self->info($info);

  my @filelist = __PACKAGE__->readDir;
  return unless scalar @filelist;

  # Build a (JID, filepath) map
  my $fmap = {};
  for my $file (@filelist) {
    next if -d $file;
    my $base = basename $file;
    my $jid = (split /\./, $base)[-1];
    $fmap->{$jid} = $file;
  }

  for my $jid (@$jidlist) {
    next unless defined $fmap->{$jid};
    my $file = $fmap->{$jid};
    next unless -r $file;

    my $fh = filereadFH($file, $verbose);
    if (defined $fh) {
      while (<$fh>) {
        if (/X509_USER_PROXY/         || 
            /GRID_JOBID/              || 
            /GRID_ID/                 ||
            /LOGNAME/                 || 
            /GLOBUS_GRAM_JOB_CONTACT/ || 
            /GATEKEEPER_JM_ID/        || 
            /GLOBUS_REMOTE_IO_URL/    ||
            /GATEKEEPER_PEER/         ||
            /GLOBUS_CE/)
        {
          next if (/^#/ || /ENV/);
          s/;\s+export(?:.*)//g;
          s/"/'/g;
          my @fields = map { trim $_ } (split /\,/);
          for (@fields) {
            my ($key, $value) = (split /='/);
            defined $value or next;
            $value =~ s/'//;
            $info->{$jid}{$key} = $value;
          }
        }
      }
      $fh->close;
    }
  }
  print Data::Dumper->Dump([$info], [qw/info/]) if $config->{debug};
  my $dbfile = $config->{jidmap};
  storeInfo($dbfile, $info);
}

sub readDir
{
  my $pkg = shift;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $path = $config->{jobDir};
  my $max_file_age = $config->{max_file_age} || 7;

  my @files = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    push @files, $file if (-f $file and -M $file < $max_file_age);
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}

1;
__END__
