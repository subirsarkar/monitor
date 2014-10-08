package Collector::PBS::Parser;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use File::Find;
use File::Basename;
use Storable;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       sortedList
                       readFile/;
use base 'Collector::Parser';

$Collector::PBS::Parser::VERSION = q|1.0|;

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
  my $jobDir  = $config->{jobDir};
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
    my $jid = (split /\./, $base)[0];
    $fmap->{$jid} = $file;
  }
  for my $jid (@$jidlist) {
    next unless defined $fmap->{$jid};
    my $file = $fmap->{$jid};
    next unless -r $file;
    chomp(my @lines = readFile($file, $verbose));
    for (@lines) {
      if (/#PBS\s+-v\s+X509_USER_PROXY/) { # LCG CE
        s/#PBS -v\s+//;
        s/"//g;
        my @fields = (split /\,/);
        for (@fields) {
          my ($key, $value) = map { trim $_ } (split /=/);
          $info->{$jid}{$key} = $value;
        }
      }
      elsif (/^#PBS\s+-W\s+stagein=/) {  ## CREAM CE - Bari
        my $str = (split /,/)[1];
        next unless defined $str;
        next unless ($str =~ /cream_sandbox/ and $str =~ /proxy\@/);
        my $proxy_file = (split /:/, trim $str)[-1];
        print join("\n",$str, $proxy_file), "\n" if $verbose;
        $info->{$jid}{q|X509_USER_PROXY|} = $proxy_file;
      }
      last if defined $info->{$jid}{X509_USER_PROXY};
    }
    next unless scalar keys %{$info->{$jid}};
    print keys %{$info->{$jid}}, "\n";

    $info->{$jid}{GRID_JOBID} = $info->{$jid}{EDG_WL_JOBID}
       if (defined $info->{$jid}{EDG_WL_JOBID} and not 
           defined $info->{$jid}{GRID_JOBID});
    $defined $info->{$jid}{X509_USER_PROXY})
      or carp qq|JID=$jid, X509_USER_PROXY not found, Grid infomation will be incomplete!!|;
  }
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
    push @files, $file if (-f $file and 
                           -M $file <= $max_file_age and 
                           basename($file) =~ /^\d+.(?:.*).SC$/);
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}

1;
__END__
package main;
my $jid = shift || die qq|Usage: $0 jid|;
my $job = new Collector::PBS::Parser({ joblist => [] });
$job->show;
