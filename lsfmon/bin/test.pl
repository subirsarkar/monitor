#!/usr/bin/env perl 
use strict;
use warnings;
use XML::Simple;

use LSF::ConfigReader;
use LSF::Util qw/trim readFile filereadFH restoreInfo/;
use LSF::JobInfo;
use LSF::Accounting;
use LSF::PlotCreator qw/createPNG plotBar/;

sub findGroup
{
  my $user = shift;
  my $gid = (getpwnam($user))[3];
  return undef unless $gid;
  (getgrgid($gid))[0];
}
sub defineColors
{
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $colorDict = $config->{plotcreator}{colorDict} || {};
  my %filter = map { $_ => 1 } values %$colorDict;  # already defined colors
  print join("\n", keys %filter), "\n";

  grep { not exists $filter{$_} }
    map { sprintf "#%s",
	join "", map { sprintf "%02x", rand(255) } (0..2)
    } (0..255);
}

sub bjobs
{
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;
  my $verbose_g = $config->{verbose} || 0;
  my $queues_toskip = $config->{queues_toskip} || [];

  my $info = {};
  my $file = qq|bjobs-w-u-all.log|;
  my $fh = filereadFH($file, $verbose_g);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while ( my $line = $fh->getline) {
      my @fields = (split /\s+/, trim($line));
      my ($jid, $user, $status, $queue, $ce) = @fields[0,1,2,3,4];
      next if grep { $_ eq $queue } @$queues_toskip;

      my ($host, $jname) = ($status eq 'RUN') ? @fields[5,6] : (undef, $fields[-4]); 
      my $index = ($jname =~ /(?:.*?)(\[\d+\])$/) ? $1 : undef;
      #print "$jname, $index\n" if defined $index;
      $jid .= qq|$index| if defined $index;
      warn qq|$jid already exists!\n| if exists $info->{$jid};
      $info->{$jid} = [$user, $status, $queue, $ce, $host];
    }
    $fh->close;
  }
  print scalar keys %$info, "\n";
#  print STDERR Data::Dumper->Dump([$info], [qw/info/]);
}
sub bjobs_l
{
  my $reader = LSF::ConfigReader->instance();
  my $config = $reader->config;

  my $info = {};
  my $file = qq|bjobs_l.log|;
  my $fh = filereadFH($file);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while (my $line = $fh->getline) {
      if ($line =~ /(.*?)Started\s+on(?:.*?)<(.*?)>/ or $line =~ /(.*?)\s+(?:\[\d+\])\s+started\s+on(?:.*?)<(.*?)>/) {
        my $start = substr $1, 0, -2;
        $start = substr $1, 0, -1 if length($start) < 19;
        print "$start, $2\n";
      }
    }
    $fh->close;
  }
}

sub readDB
{ 
  my $file = qq|../db/bjobs.db|;
  my $dict = restoreInfo($file);
  while ( my ($jid) = each %$dict ) {
    my $job = $dict->{$jid};
    print Data::Dumper->Dump([$job], [qw/job/]);
    print $job->CPUTIME, "\n";
    last;
  }
}
sub xmls
{
  my $ref = XMLin('../html/overview.xml');
  print Data::Dumper->Dump([$ref], [qw/jobview/]);
}

sub plot
{
  my $data = 
  [
    [
      '#8b3626',
      '#74b5ff',
      '#0086b3',
      '#555399',
      '#5958a1',
      '#ee9572',
      '#30a051',
      '#9745ab',
      '#556b2f',
      '#8b4c99'
    ],
    [
      'compchem',
      'glast',
      'gridit',
      'theodip',
      'theoinfn',
      'alice',
      'cms',
      'atlas',
      'lhcb',
      'ops'
    ],
    [
      '99.9',
      '99.5',
      '98.7',
      '98.3',
      '93.5',
      '66.4',
      '62.2',
      '59.1',
      '51.8',
      '30.3'
    ]
  ];
  my $image = plotBar(qq|CPU Effi.|, qq|Eff in %|, $data);
  createPNG($image, qq|test.png|);  
}
#print findGroup 'na48005';
#print "\n";

#my @colors = defineColors;
#print scalar @colors, "\n";
#print join("\n", @colors), "\n";

#bjobs;
#bjobs_l;
#readDB;
#xmls;
plot;
__END__
