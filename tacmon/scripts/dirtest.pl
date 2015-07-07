#!/usr/bin/env perl

opendir(DIR, "/data3/TIBTOB") || die "Can't open directory, $!\n";
my $run = "6502";
my @a = grep(/(?:.*)$run(?:.*)\.(?:root|dat)$/, readdir(DIR)); # grep(/(?:.*)$run(?:.*)\.root$/o, readdir(DIR));
closedir(DIR);
print join("\n", @a), "\n";
