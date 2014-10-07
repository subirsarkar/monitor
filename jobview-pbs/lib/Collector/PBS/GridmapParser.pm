package Collector::PBS::GridmapParser;

use strict;
use warnings;
use Carp;
use IO::File;
use Data::Dumper;
use File::Find;
use File::Basename;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                 sortedList
                 filereadFH/;
use base 'Collector::Parser';

$Collector::PBS::GridmapParser::VERSION = q|0.9|;

sub new
{
  my $this = shift;
  my $class = ref $this || $this; 

  my $self = SUPER::new $class();
  bless $self, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  my $info = {};
  $self->info($info);

  my @filelist = __PACKAGE__->readDir;
  return unless scalar @filelist;

  # Build a (JID, DN) map
  my $dnmap = {};
  for my $file (@filelist) {
    next if -d $file;
    my $fh = filereadFH($file, $verbose);
    if (defined $fh) {
      while (<$fh>) {
        next if /lrmsID=none/;
        if (/.*?userDN=(.*?)".*?lrmsID=(.*?)".*?/) {
	  my ($dn, $jid) = map { trim $_ } ($1, $2);
          $jid = (split /\./, $jid)[0];
          $dnmap->{$jid} = $dn;
        }
      }
      $fh->close;
    }
  }
  $info->{_dnmap} = $dnmap;
}
sub save
{
  my ($self, $dbfile) = @_;

  unless (defined $dbfile and -r $dbfile) {
    # Read the global configuration, a singleton
    my $reader = Collector::ConfigReader->instance();
    my $config = $reader->config;
    $dbfile = $config->{db}{dnmap};
  }
  my $dnmap = $self->dnmap;
  my $fh = new IO::File $dbfile, 'w';
  carp qq|Failed to open output file $dbfile, $!| unless defined $fh;

  while ( my ($jid, $dn)= each %$dnmap ) {
    print $fh "$jid##$dn\n";
  }
  $fh->close;
}
sub readDir
{
  my $pkg = shift;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $path = $config->{gridmapDir} || q|/opt/edg/var/gatekeeper|;
  my $max_file_age = $config->{max_file_age} || 7;

  my @files = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    my $bname = basename($file);
    push @files, $file if ( -f $file and 
                            -M $file < $max_file_age and 
                            ($bname =~ /^grid-jobmap/ 
                          or $bname =~ /^blahp\.log/) );
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}
sub dnmap
{
  my $self = shift;
  $self->info()->{_dnmap};
}

1;
__END__
package main;
my $job = new Collector::PBS::GridmapParser;
$job->show;
