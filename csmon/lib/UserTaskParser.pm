package UserTaskParser;

use strict;
use warnings;
use Carp;
use HTTP::Date;
use Data::Dumper;
use URI::Escape;

use Util qw/trim time2hours/;
use WebTools::Page;

use constant MINUTE => 60;
use constant HOUR => 60 * MINUTE;

sub new 
{
  my $this = shift;
  my $class = ref $this || $this;

  bless {
    info => {},
  }, $class;
}
sub parse
{
  my ($self, $attr) = @_;
  my $verbose = $attr->{verbose} || 0;
  croak qq|URL missing| unless defined $attr->{url};
  my $rows = WebTools::Page->Table({ url => $attr->{url}, count => 0, verbose => $verbose });  
  my $info = {};
  for my $row (@$rows) {
    my ($task, $status, $completeness, $linklog, $linkstatus) = @$row;
    $status =~ s/\s+/_/g;
    $info->{$task} = {
                             status => $status, 
                       completeness => $completeness,
                            linklog => $linklog,
                         linkstatus => $linkstatus
		     };
  }
  $self->{info} = $info;
}
sub show
{
  my $self = shift;
  my $info = $self->{info};
  print Data::Dumper->Dump([$info], [qw/table/]);  
}

sub summary
{
  my ($self, $attr) = @_;
  my $verbose = $attr->{verbose} || 0;
  my $dict = $self->{info};
  my @list = ();
  my $timenow = time;
  while (my ($task, $info) = each %$dict) {
    my $status = $info->{status};
    next unless $status eq 'submitting';
    if ($status eq 'submitted') {
      my $link_status = $info->{linkstatus};
      if ($link_status =~ m#<a\s+href='..(.*?)'>(?:.*)#) {
        my $url = $attr->{baseurl} . $1;
        my $rows = WebTools::Page->Table({ url => $url, count => 0, verbose => $verbose });
        print Data::Dumper->Dump([$rows], [qw/table/]) if $verbose;
        my $nitems = 0;
        for my $row (@$rows) {
	  my $status = $row->[1];
          ++$nitems if $status=~ /Submitting/;
        }
        next unless $nitems;
      }
    }
    print STDERR qq|>>> Processing task: $task:$status\n| if $verbose;
    my $link_log = $info->{linklog};
    if ($link_log =~ m#<a\s+href='..(.*?)'>(?:.*)#) {
      my $url = $attr->{baseurl} . $1;
      my $rows = WebTools::Page->Table({ url => $url, count => 0, verbose => $verbose });
      print Data::Dumper->Dump([$rows], [qw/table/]) if $verbose;
      my $index = 0;
      for my $row (@$rows) {
	my $tag = $row->[0];
        last if $tag =~ /NewTaskRegistered/;
        ++$index;
      }
      next unless $index < scalar @$rows;
      my $instate = 0;
      eval {
        my $timestamp = $rows->[++$index][1];
        $timestamp =~ s/\s+UTC\s+.*//;
        my @fields = split /,/, $timestamp;
        $timestamp = join('.', $fields[0], substr($fields[1],0,2));
        $instate = $timenow - str2time($timestamp,"+0100");
      };
      carp $@ and next if $@;
      next unless $instate > 4 * HOUR;
      push @list, { task => $task, status => $status, duration => $instate };
    }
  }
  my $nsub = scalar @list;
  if ($nsub) {
    my $ntotal = scalar keys %$dict;
    printf "Fraction of tasks in submitting status: %6.2f%%\n", 
      (($ntotal > 0) ? 100*$nsub/$ntotal : 0); 
    printf qq|%100s %10s %15s\n|, q|Task|, q|Status|, q|Duration(hh:mm)|;
    for my $l (sort {$b->{duration} <=> $a->{duration} } @list) {
      printf qq|%100s %10s %10s\n|, $l->{task}, $l->{status}, time2hours($l->{duration});
    }
  }
  print "\n";
}

1;
__END__
package main;
my $baseurl = q|http://crab1.ba.infn.it:8888|;
my $url = $baseurl . q|/usertask/?username=All&tasktype=All&length=12&span=hours|;
my $obj = UserTaskParser->new;
$obj->parse({ url => $url });
$obj->summary({ baseurl => $baseurl });
