#!/usr/bin/env perl

package main;
use strict;
use warnings;
use List::Util qw/min max/;

use BaseTools::Util qw/trim readFile/;
use dCacheTools::ReplicationHandler;

my $infile = shift || die qq|Usage: $0 infile\n\tstopped|;
-r $infile or die qq|$infile not readable\n\tstopped|;

my $ecode = 0;
chomp(my @list = readFile($infile, \$ecode));
die qq|Failed to read $infile, stopped| if $ecode;

my $nitems = scalar @list;
print qq|Replicate $nitems files\n|;
my $handler = dCacheTools::ReplicationHandler->new({ 
         max_threads => min(30, $nitems), 
          src_cached => 1, 
        dst_precious => 1, 
  cached_src_allowed => 0,
   same_host_allowed => 0
});

for (@list) {
  next if (/^$/ or /^#/);
  my ($pnfsid, $spool, $dpool) = map { trim $_ } (split /\s+/);
  warn qq|Please check $infile content, destination pool missing!| and next 
    unless (defined $dpool and length $dpool);
  $handler->add({
     pnfsid => $pnfsid,
      spool => $spool,
      dpool => $dpool
  });
}
$handler->run;
__END__
