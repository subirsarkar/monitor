#my $filename = "tif.00002875.A.testStorageManager_0.7.root";
my $filename = "EDM0005105_004.root";
if ($filename =~ /^EDM(?:.*)\.root$/ or $filename =~ /(?:.*)StorageManager(?:.*)\.root$/) {
  print "YES\n";
}
