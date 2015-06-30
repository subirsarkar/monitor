#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use WebTools::PhedexFiles;
use BaseTools::Util qw/trim/;

use constant DEBUG => 0;

my $list = shift || die qq|Usage: $0 list|;
open INPUT, $list or die qq|failed to open $list, stopped|;
while (<INPUT>) {
  my ($dataset, $frac, $se) = (split);
  $se = qq|cmssrm.fnal.gov| unless $se;
  print join(', ', $dataset, $frac, $se), "\n" if DEBUG;
  my $p = WebTools::PhedexFiles->new({ se => $se, verbose => 0 });
  my $blocks = $p->blocks(trim($dataset));

  my @blist = sort keys %$blocks;
  $frac = 1.0 unless scalar @blist > 10;
  my $tfiles = 0;
  for my $key (@blist) {
    $tfiles += $blocks->{$key}[0];
  }
  my $nfiles = 0;
  for my $key (@blist) {
    $nfiles += $blocks->{$key}[0];
    last if $nfiles > int($frac*$tfiles);
    print "$key\n";
  }
  print "\n";
}
close INPUT;
__END__
