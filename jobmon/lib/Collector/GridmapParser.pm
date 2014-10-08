package Collector::GridmapParser;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use File::Find;
use File::Basename;

use Collector::ConfigReader;
use Collector::Util qw/filereadFH
                       sortedList/;

$Collector::GridmapParser::VERSION = q|1.0|;

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

  my $info = {};
  $self->info($info);

  my @filelist = __PACKAGE__->readDir;
  return unless scalar @filelist;

  my $config = Collector::ConfigReader->instance()->config;
  my $verbose = $config->{verbose} || 0;

  # Build a (JID-> DN, FQAN, CEid, GRID_ID) map
  my $jmap = {};
  for my $file (@filelist) {
    next if -d $file;
    print ">>> Processing file: $file ...\n" if $verbose;
    my $fh = filereadFH($file, $verbose);
    if (defined $fh) {
      while (<$fh>) {
        next if /lrmsID=none/;
        my $tmp_map = {};
        my @fields = map { $_ =~ s/"//g; $_ } (split /"\s?"/);
        for (@fields) {
          if (/(.*?)=(.*)/) {
            my ($key, $value) = ($1, $2); 
            exists $tmp_map->{$key} and $value = $tmp_map->{$key}.qq|:$value|;
            $tmp_map->{$key} = $value;
          }
        }
        exists $tmp_map->{lrmsID} or next;
        my $jid = delete $tmp_map->{lrmsID};
        $jid = (split /\./, $jid)[0]; # required by for PBS Cream CE
        for my $key (keys %$tmp_map) {
          $jmap->{$jid}{$key} = $tmp_map->{$key};
        }
      }
      $fh->close;
    }
  }
  $info->{_jidmap} = $jmap;
}
sub readDir
{
  my $pkg = shift;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $path = $config->{gridmapDir};
  my $max_file_age = $config->{max_file_age} || 7;

  my @files = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    my $bname = basename($file);
    push @files, $file if ( -f $file and 
                            -M $file < $max_file_age and 
			    ($bname =~ /^grid-jobmap/ or 
                             $bname =~ /^blahp\.log/) );
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}

sub info
{
  my $self = shift;
  if (@_) {
    return $self->{_info} = shift;
  } 
  else {
    return $self->{_info};
  }
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  return unless defined $info;

  print Data::Dumper->Dump([$info], [qw/info/]);    
}

sub jidmap
{
  my $self = shift;
  $self->info()->{_jidmap};
}

sub GLOBUS_CE
{
  my ($self, $jid) = @_;  
  my $dict = $self->jidmap;
  $dict->{$jid}{ceID} || undef; # for cases when JID is undefined
}

sub GRID_ID
{
  my ($self, $jid) = @_;  
  my $dict = $self->jidmap;
  $dict->{$jid}{userDN} || undef;
}

sub GRID_JOBID
{
  my ($self, $jid) = @_;  
  my $dict = $self->jidmap;
  $dict->{$jid}{jobID} = undef if (defined $dict->{$jid}{jobID} and $dict->{$jid}{jobID} eq 'none');
  $dict->{$jid}{jobID};
}

sub FQAN
{
  my ($self, $jid) = @_;  
  my $dict = $self->jidmap;
  $dict->{$jid}{userFQAN} || undef;
}

1;
__END__
package main;
my $p = new Collector::GridmapParser;
$p->show;
