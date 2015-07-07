#!/usr/bin/env perl
sub readDir($$$)
{
  my ($dir, $run, $index) = @_;
  print "dir=$dir,run=$run,index=$index\n" if DEBUG;
  # /RU0\{0,7\}${run}_[0-9]*.root"
  # /[a-zA-Z]*.0\{0,8\}${run}.A.[a-zA-Z0-9_.]*.dat"

  opendir(DIR, $dir) || die "Can't open directory $dir, $!\n";
  my @a = readdir(DIR);
  if ($index > 0) {
    @a = grep { /(?:RU|tif\.)(?:.*)$run(?:.*)\.(?:root|dat)$/ } @a;
  }
  else {
    @a = grep { /(?:EDM|tif\.)(?:.*)$run(?:.*)\.(?:root|dat)$/ } @a;
  }
  closedir(DIR);
  @a;
}
my @a = readDir(qq[/data3/TOB/run], 7690, 1);
print join("\n", @a), "\n";

@a = readDir(qq[/data3/EDMProcessed/TOB/edm_2007_04_16], 7690, 0);
print join("\n", @a), "\n";
