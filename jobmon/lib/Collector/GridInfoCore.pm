package Collector::GridInfoCore;

use strict;
use warnings;
use Carp;
use IO::File;
use File::Glob ':globally';

use Collector::ConfigReader;
use Collector::Util qw/trim
                       commandFH 
                       show_message
                       readFile/;
use Collector::GridmapParser;

$Collector::GridInfoCore::VERSION = q|1.0|;
our $batchAttr = 
{ 
     lsf => q|Collector::LSF::Parser|,
     pbs => q|Collector::PBS::Parser|,
  condor => q|Collector::Condor::Parser|
};

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 
  croak q|Job List not found| unless defined $attr->{joblist};
  my $self = bless {
    joblist => $attr->{joblist},
     _cache => {} 
  }, $class;

  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  my $jidlist = $self->{joblist};

  # read the configuration
  my $reader = Collector::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{verbose} || 0;

  my $lrms  = $config->{lrms}     || croak qq|Batch system not specified in config.pl!|;
  my $class = $batchAttr->{$lrms} || croak qq|Batch system $lrms not supported!|;

  my $parser = Collector::ObjectFactory->instantiate($class, {joblist => $jidlist});
  $parser->show if $verbose;
  my $dict = $parser->info;

  # Parse the Gridmap files and update 
  my $gParser = new Collector::GridmapParser;
  $gParser->show if $verbose;
  while ( my ($jid) = each %$dict ) {
    $dict->{$jid}{GLOBUS_CE}  = $gParser->GLOBUS_CE($jid)  unless defined $dict->{$jid}{GLOBUS_CE};
    $dict->{$jid}{GRID_ID}    = $gParser->GRID_ID($jid)    unless defined $dict->{$jid}{GRID_ID};
    $dict->{$jid}{GRID_JOBID} = $gParser->GRID_JOBID($jid) unless defined $dict->{$jid}{GRID_JOBID};
    $dict->{$jid}{FQAN}       = $gParser->FQAN($jid)       unless defined $dict->{$jid}{FQAN};
  }

  $self->{lrms}   = $lrms; 
  $self->{info}   = $dict;
  $self->{config} = $config;
}

# jobdscription file
sub jobdesc
{
  my ($self, $jid) = @_;
  return undef unless (defined $jid and defined $self->{info}{$jid});

  my $jobdesc = '?';
  my $dict = $self->{info}{$jid};
  return $jobdesc unless (defined $dict->{LOGNAME} and
                          defined $dict->{GLOBUS_GRAM_JOB_CONTACT});

  my $user = $dict->{LOGNAME};
  my $lrms = $self->{lrms};
  my @files = <~$user/.lcgjm/jm-*${lrms}-submit.list>;
  return $jobdesc unless scalar @files;

  my $file = $files[0];
  return $jobdesc unless -r $file;

  chop(my $text = readFile($file, 1));
  return $jobdesc unless length $text;

  my @fields = (split /\n/, trim $text);
  my $tag = join '.', (split m#/#, $dict->{GLOBUS_GRAM_JOB_CONTACT})[-2,-1];
  for (@fields) {
    if (m#lcgjm/jobdescription#) {
      if (m#$tag#) {
        $jobdesc = (split)[-1];
        last;
      }
    }
  }
  $jobdesc = qq|/home/$user/$jobdesc| unless $jobdesc eq '?';
  $jobdesc;
}

sub execute
{
  my ($self, $jid, $attr) = @_;

  my $config = $self->{config};
  my $verbose = $config->{verbose} || 0;
  my $req_su  = $config->{requires_su} || 0;
  my $show_error = $config->{show_cmd_error} || 0;

  my $command;
  if ($req_su) {
    croak qq|User not defined!| unless defined $attr->{LOGNAME};
    $command = qq/su -m $attr->{LOGNAME} -c "/;
  }
  $command .= qq/voms-proxy-info -file $attr->{X509_USER_PROXY} -all/;
  $command .= qq/"/ if $req_su;
  print "COMMAND=$command\n" if $verbose;

  delete $self->{_cache}{$jid} if exists $self->{_cache}{$jid};

  show_message qq| start - executing $command for jid $jid| if $verbose>1;
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    while (my $line = $fh->getline) {
      my ($key, $value) = (split /\s+:\s+/, trim $line);
      next unless (defined $key and defined $value);
      next if $value =~ /nickname/;
      push @{$self->{_cache}{$jid}{$key}}, $value;
    }
    $fh->close;
  }
  show_message qq| done - executing $command| if $verbose>1;
}

# subject
sub subject
{
  my ($self, $jid) = @_;
  my $subject = undef;
  return $subject unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  return $dict->{GRID_ID} if defined $dict->{GRID_ID};

  return $subject unless (defined $dict->{X509_USER_PROXY} 
                           and -r $dict->{X509_USER_PROXY}); 

  $self->execute($jid, $dict) unless exists $self->{_cache}{$jid}{subject};
  return $subject unless defined $self->{_cache}{$jid}{subject};

  my @list = @{$self->{_cache}{$jid}{subject}};
  $subject = $list[-1] if scalar @list;
  $subject;
}

# Grid jobid
sub gridid
{
  my ($self, $jid) = @_;
  return undef unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  $dict->{GRID_JOBID};
}

# Rb/WMS
sub rb
{
  my ($self, $jid) = @_;
  return undef unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  return undef unless (defined $dict->{X509_USER_PROXY} 
                        and -r $dict->{X509_USER_PROXY}); 

  my $rb = '?';
  my $file = $dict->{GLOBUS_REMOTE_IO_URL};
  if (defined $file and -r $file) {
    chop(my $text = readFile($file, 1));
    $rb = $1 if $text =~ m#https://(.*?)\:\d+#;
  }
  $rb;
}

# CE Id
sub gridce
{
  my ($self, $jid) = @_;
  return undef unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  $dict->{GLOBUS_CE};
}

# validity of proxy
sub timeleft
{
  my ($self, $jid) = @_;
  my $timeleft = undef;
  return $timeleft unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  return $timeleft unless (defined $dict->{X509_USER_PROXY} 
                            and -r $dict->{X509_USER_PROXY}); 

  $self->execute($jid, $dict) unless exists $self->{_cache}{$jid}{timeleft};
  return $timeleft unless defined $self->{_cache}{$jid}{timeleft};
  my @list = @{$self->{_cache}{$jid}{timeleft}};

  $timeleft = -1;
  if (scalar @list) {
    @list = map { int $_ } (split /:/, $list[-1]);
    if (scalar @list > 2) {
      $timeleft = $list[0] * 3600 + $list[1] * 60 + $list[2];
    }
    elsif (scalar @list > 1) {
      $timeleft = $list[0] * 60 + $list[1];
    }
    else {
      $timeleft = $list[0];
    }
  }
  $timeleft;
}

# VOMS Role
sub role
{
  my ($self, $jid) = @_;
  my $role = undef;
  return $role unless (defined $jid and defined $self->{info}{$jid});

  my $dict = $self->{info}{$jid};
  return $dict->{FQAN} if defined $dict->{FQAN};

  return $role unless (defined $dict->{X509_USER_PROXY} 
                        and -r $dict->{X509_USER_PROXY}); 

  $self->execute($jid, $dict) unless exists $self->{_cache}{$jid}{attribute};
  return $role unless defined $self->{_cache}{$jid}{attribute};

  my @list = @{$self->{_cache}{$jid}{attribute}};
  $role = (scalar @list) ? join (':', @list) : '?';
  $role;
}

sub info
{
  my $self = shift;
  $self->{info};
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  while ( my ($jid) = each %$info ) {
    print STDERR join ("##", $jid, 
                             $self->subject($jid), 
                             $self->gridid($jid), 
                             $self->rb($jid), 
                             $self->timeleft($jid),
                             $self->jobdesc($jid), 
                             $self->role($jid),
                             $self->gridce($jid)), 
                      "\n";
  }
}

1;
__END__
