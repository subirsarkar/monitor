package Collector::PBS::JobdefParser;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use File::Find;
use File::Basename;

use Collector::ConfigReader;
use Collector::Util qw/trim 
                       sortedList
                       readFile
                       getCommandOutput
                       storeInfo
                       restoreInfo/;
use base 'Collector::Parser';

sub _parse_jobdesc;
sub subject;

$Collector::PBS::JobdefParser::VERSION = q|0.2|;

sub new
{
  my ($this, $attr) = @_;
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

  my $dbfile     = $config->{db}{dnmap};
  my $verbose    = $config->{verbose} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

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

  # now get the current joblist
  my $command = q|qstat -a|;
  my $ecode;
  # format: jid.(truncted hostfqdn)
  chomp(my @list = 
    grep { /^\d+\./ } getCommandOutput($command, \$ecode, $show_error, $verbose));
  my @jidlist = ();
  for (@list) {
    my ($jtag, $queue, $status) = map { trim $_ } (split /\s+/)[0,2,9];    
    my $jid = (split /\./, $jtag)[0]; # the remaining part is the CE
    push @jidlist, $jid;
  }

  # load the stored JID->DN map
  my $stmap = restoreInfo($dbfile);

  # now collect 
  for my $jid (@jidlist) {
    next if exists $stmap->{$jid};
    next unless defined $fmap->{$jid};
    my $file = $fmap->{$jid};
    next unless -r $file;
    my @lines = readFile($file, $verbose);
    my $info = _parse_jobdesc(\@lines);

    my $subject = (defined $info->{X509_USER_PROXY}) 
               ? subject({
                           proxy_file => $info->{X509_USER_PROXY}, 
                              logname => $info->{LOGNAME} || undef, 
                           show_error => 1, 
                              verbose => 1
                        }) 
               : ($info->{LOGNAME} || undef);
    $stmap->{$jid}{dn}        = $subject;
    $stmap->{$jid}{timestamp} = time;
  }
  # trim the stored map and transfer to $info
  my $then = time - 7 * 24 * 60 * 60;
  my $dnmap = {};
  for my $jid (keys %$stmap) {
    delete $stmap->{$jid} and next if $stmap->{$jid}{timestamp} < $then; 
    $dnmap->{$jid} = $stmap->{$jid}{dn};
  }
  $info->{_dnmap} = $dnmap;

  # now store back
  storeInfo($dbfile, $stmap);
}

sub readDir
{
  my $pkg = shift;

  # Read the global configuration, a singleton
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $path = $config->{jobDir} || q|/var/spool/pbs/server_priv/jobs|;
  my $max_file_age = $config->{max_file_age} || 7;

  my @files = ();
  my $traversal = sub
  {
    my $file = $File::Find::name;
    push @files, $file if (-f $file and 
                           -M $file < $max_file_age and 
                           basename($file) =~ /^\d+.(?:.*).SC$/);
  };
  find $traversal, $path;

  sortedList({ path => $path, files => \@files });
}

sub _parse_jobdesc
{
  my $input = shift;
  my $info = {};
  for (@$input) {
    if (/^#PBS/ && /X509_USER_PROXY/) {
      s/#PBS -v\s+//;
      s/"//g;
      my @fields = (split /\,/);
      for (@fields) {
        my ($key, $value) = map { trim $_ } (split /=/);
        $info->{$key} = $value;
      }
      last;
    }
  }
  $info;
}
sub buildCommand
{
  my ($file, $user, $stag) = @_;
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;
  my $req_su  = $config->{requires_su} || 0;

  my $command;
  if ($req_su) {
    croak q|User not defined!| unless defined $user;
    $command = qq/su -m $user -c "/;
  }
  $command .= qq/voms-proxy-info -file $file -$stag/;
  $command .= q/"/ if $req_su;
  $command .= q/ | tail -1/;
  print "COMMAND=$command\n" if $verbose;
  $command;
}
sub subject
{
  my $attr = shift;
  $attr->{verbose}    = 0 unless defined $attr->{verbose};
  $attr->{show_error} = 0 unless defined $attr->{show_error};
  my $subject = '?';

  my $ecode;
  my $command = buildCommand($attr->{proxy_file}, $attr->{logname}, 'acsubject');
  chop($subject = getCommandOutput($command, \$ecode, $attr->{show_error}, $attr->{verbose}));

  if ($subject eq '') {
    $command = buildCommand($attr->{proxy_file}, $attr->{logname}, 'subject');
    chop($subject = getCommandOutput($command, \$ecode, $attr->{show_error}, $attr->{verbose}));
  }
  print STDERR "FILE=$attr->{proxy_file},SUBJECT=$subject\n" if $attr->{verbose};

  $subject = ($attr->{logname} || '?') if $subject eq '';
  trim $subject;
}

sub dnmap
{
  my $self = shift;
  $self->info()->{_dnmap};
}

1;
__END__
package main;
my $job = new Collector::PBS::JobdefParser;
$job->show;
