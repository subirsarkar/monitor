#!/usr/bin/env perl 
use strict;
use warnings;

use LSF::PlotCreator qw/createPNG plotBar/;

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
  my $data_2 = [
    ['#555399'], ['theodip'], [34295]
  ];
  my $image = plotBar(qq|CPU Effi.|, qq|Eff in %|, $data_2);
  createPNG($image, qq|test.png|);  
}
plot;
__END__
