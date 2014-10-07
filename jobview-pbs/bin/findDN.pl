#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;

use Collector::ConfigReader;
use Collector::Util qw/trim readFile getCommandOutput/;

sub _parse_jobdesc;
sub subject;

sub main
{
  my $file = shift;

  my @lines = readFile($file);
  my $info = _parse_jobdesc(\@lines);
  my $subject = (defined $info->{X509_USER_PROXY}) 
               ? subject({
                           proxy_file => $info->{X509_USER_PROXY}, 
                              logname => $info->{LOGNAME}, 
                           show_error => 1, 
                              verbose => 1
                        }) 
               : '?';
  print "DN=$subject\n";
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
    $command = qq/su -m $user -c "/;
  }
  $command .= qq/voms-proxy-info -file $file -$stag/;
  $command .= qq/"/ if $req_su;
  $command .= qq/ | tail -1/;
  print "COMMAND=$command\n" if $verbose;
  $command;
}
sub subject
{
  my $attr = shift;
  $attr->{verbose} = 0 unless defined $attr->{verbose};
  $attr->{show_error} = 0 unless defined $attr->{show_error};
  my $subject = '?';

  my $ecode;
  my $command = buildCommand($attr->{proxy_file}, $attr->{logname}, 'acsubject');
  chop($subject = getCommandOutput($command, \$ecode, $attr->{show_error}));

  if ($subject eq '') {
    $command = buildCommand($attr->{proxy_file}, $attr->{logname}, 'subject');
    chop($subject = getCommandOutput($command, \$ecode, $attr->{show_error}));
  }
  print STDERR "FILE=$attr->{proxy_file},SUBJECT=$subject\n" if $attr->{verbose};

  $subject = '?' if $subject eq '';
  trim $subject;
}

my $file = shift || die qq|Usage: $0 filename|;
main($file);
__END__
