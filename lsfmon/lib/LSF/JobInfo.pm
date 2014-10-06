package LSF::JobInfo;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use HTTP::Date;
use List::Util qw/min/;

use LSF::ConfigReader;
use LSF::Util qw/trim getCommandOutput/;

$LSF::JobInfo::VERSION = q|0.9|;
use constant SCALE => 1024;

our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $toKB =
{
  Kbytes => 1,
  Mbytes => SCALE,
  Gbytes => SCALE**2,
  Tbytes => SCALE**3,
};
our $statusAttr = 
{
    RUN => [q|R|, q|running|],
   PEND => [q|Q|, q|pending|],
   DONE => [q|E|, q|exited|],
   EXIT => [q|E|, q|exited|],
  SSUSP => [q|H|, q|held|],
  USUSP => [q|H|, q|held|],
  PSUSP => [q|H|, q|held|],
  UNKWN => [q|U|, q|unknown|],
  ZOMBI => [q|U|, q|unknown|]
};

our $AUTOLOAD;
my %fields = map { $_ => 1 }
          qw/JID
             USER
             GROUP
             QUEUE
             STATUS
             LSTATUS
             QTIME
             START
             END
             EXEC_HOST
             UI_HOST
             CPUTIME
             WALLTIME
             MEM
             VMEM
             EX_ST
             SUBJECT
             CPUEFF
             NCORE/;
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 
  bless {
    _permitted => \%fields
  }, $class;
}

sub parse
{
  my ($self, $attr) = @_;
  my $info = {};

  # Now parse the bjobs -l output
  my @lines;
  if (defined $attr->{text}) { 
    my $text = $attr->{text};
    @lines = split /\n/, $$text;
  }
  else {
    croak q|Must specify a valid JOBID| unless defined $attr->{jobid};
    my $reader = LSF::ConfigReader->instance();
    my $config = $reader->config;
    my $show_error = $config->{show_cmd_error} || 0;
    my $verbose = $config->{verbose} || 0;

    my $user = $attr->{user} || q|all|;
    my $command = qq|bjobs -l -u $user $attr->{jobid}|;
    my $ecode = 0;
    chomp(@lines = getCommandOutput($command, \$ecode, $show_error, $verbose));
  }
  for ( map { trim $_ } @lines)  {
    next if /^$/;         # Skip empty lines
    if (/^Job\s+<(\d+?(?:\[\d+\])?)>/) {
      my $jid = $1;
      $info->{JID} = $jid;
      $info->{USER} = $attr->{info}{$jid}{user} || undef;
      my $status = $attr->{info}{$jid}{status};
      $info->{STATUS}  = $statusAttr->{$status}[0] || undef; 
      $info->{LSTATUS} = $statusAttr->{$status}[1] || undef; 
      $info->{QUEUE}   = $attr->{info}{$jid}{queue} || undef;

      if (defined $attr->{info}{$jid}{host}) {
        my @hoststr = split /:/, $attr->{info}{$jid}{host};
        if (scalar @hoststr > 1) {
          my $ncore = 0;
          my @hosts = ();
          for (@hoststr) {
            my ($n,$h) = (split /\*/);
            if (defined $n and defined $h) {
              $ncore += $n;
              push @hosts, $h;   
            }
            else {
              $ncore++;
              push @hosts, $_;   
            }
          }
          $info->{EXEC_HOST} = join(":", @hosts);
          $info->{NCORE}     = $ncore;
        }
        else {
          my @f = (split /\*/, $hoststr[0]);
          $info->{EXEC_HOST} = (scalar @f > 1) ? $f[1] : $hoststr[0];
          $info->{NCORE}     = (scalar @f > 1) ? $f[0] : 1;
        }
      }
    }
    elsif (/(.*?)Submitted\s+from\s+host\s+<(.*?)>/) {
      my $qtime = substr $1, 0, -2;
      $info->{QTIME} = str2time($qtime); 
    }
    elsif (defined $info->{STATUS} and $info->{STATUS} ne 'Q' and $info->{STATUS} ne 'U') {
      if (/(.*?)Started\s+on(?:.*?)<(.*?)>/ or /(.*?)\s+(?:\[\d+\])\s+started\s+on(?:.*?)<(.*?)>/) {
        my $start = substr $1, 0, -2;
        $start = substr $1, 0, -1 if length($start) < 19;
        $info->{START} = str2time($start); 
      } 
      elsif (/The CPU time used is/) {
        if ($info->{STATUS} eq 'E') {
          $info->{DONE_TIME} = undef;
          $info->{CPUTIME} = (split /\s+/)[-2];
        }
        else {
          $info->{CPUTIME} = (split /\s+/)[5];
        }
      }
      elsif (/MEM:/) {
        eval {
          # MEM: 388 Mbytes;  SWAP: 241.5 Gbytes;  NTHREAD: 22
          my ($mem, $munit, $vmem, $vunit) = (split /\s+/)[1,2,4,5];
          $munit =~ s/;//; $vunit =~ s/;//;
          $info->{MEM} = $mem * $toKB->{$munit}; 
          $info->{VMEM} = $vmem * $toKB->{$vunit}; 
          unless (defined $info->{MEM} and defined $info->{VMEM}) {
	    my $msg = q|ERROR. Invalid parameter(s) for JID=|. ($info->{JID} || 'undefined');
            $msg .= qq|, MEM=$mem, VMEM=$vmem|;
            carp $msg;
          }
        }; 
        if ($@) {
          carp qq|Reason\n: $@| if $@;
        }
      }
    }
    last if (/PGID/ or /MEMORY USAGE/);
  }
  $info->{WALLTIME} = (defined $info->{START}) 
      ? time() - $info->{START} 
      : undef;
  if (defined $info->{WALLTIME}) {
    my $cput = (defined $info->{CPUTIME} and $info->{CPUTIME} =~ /\d+/) 
        ? int($info->{CPUTIME}) 
        : undef;
    # TODO: investigate cases where CPUTIME > WALLTIME
    $info->{CPUTIME} = (defined $cput) ? min($info->{WALLTIME}, $cput) : undef;
  }
  # Finally the group the user belongs to
  # We should use a little map for this purpose and should not
  # recalculate it for each user, so I prefer to do it on step up
  $self->{_INFO} = $info;
}

sub setStatus
{
  my ($self, $status) = @_;
  $self->{_INFO}{STATUS}  = $statusAttr->{$status}[0] || undef; 
  $self->{_INFO}{LSTATUS} = $statusAttr->{$status}[1] || undef;
}

sub info
{
  my $self = shift;
  $self->{_INFO};
}

sub dump
{
  my $self = shift;
  my $info = $self->info;
  print Data::Dumper->Dump([$info], [qw/jobinfo/]);
}
sub show
{
  my $self = shift;
  my $stream = shift || *STDOUT;
  print $stream $self->toString;
}

sub tags
{
  my $self = shift;
  sort keys %{$self->{_INFO}};
}

sub toString
{
  my $self = shift;
  my $info = $self->info;
  my $output = sprintf (qq|\n{%s}{%s}{%s}\n|, $info->{GROUP}, $info->{QUEUE}, $info->{JID});
  for my $key (sort keys %$info) {
    $output .= sprintf(qq|%s: %s\n|, $key, $info->{$key});
  }
  $output;
}

sub AUTOLOAD
{  
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;
         
  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion
 
  croak qq|Failed to access $name field in class $type|
     unless exists $self->{_permitted}{$name};
        
  if (@_) {
    return $self->{_INFO}{$name} = shift;
  }
  else {
    return ( defined $self->{_INFO}{$name}  
           ? $self->{_INFO}{$name}
           : undef );
   }
}

# AUTOLOAD/carp fallout
sub DESTROY { }

1;
__END__
package main;

my $jid = shift || die qq|Usage: $0 JOBID|;
my $job = LSF::JobInfo->new({jobid => $jid});
$job->show;
