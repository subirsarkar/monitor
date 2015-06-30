#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::Cell;
use dCacheTools::GridftpCell;
use dCacheTools::GridftpTransfer;

my $broker = dCacheTools::Cell->new({ name => q|LoginBroker| });
my @gftpList = grep { /GFTP/ } $broker->exec({ command => q|ls| });
my @objectList = ();
for (@gftpList) {
  my $cell = (split /;/)[0];
  my $obj = dCacheTools::GridftpCell->new({ name => $cell });
  push @objectList, $obj;
}
# First the logins
dCacheTools::GridftpCell->header;
for my $obj (@objectList) {
  $obj->showLogin;
}
# Now the children
printf "%29s|", "Cell";
dCacheTools::GridftpTransfer->header;
for my $obj (@objectList) {
  $obj->showChildren;
}
__END__
