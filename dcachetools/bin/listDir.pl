#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use File::Basename;
use File::stat;
use POSIX qw/strftime/;
use Math::BigInt;

use BaseTools::Util qw/trim/;
use dCacheTools::Filemap;
use dCacheTools::Replica;
use dCacheTools::Pool;

use constant GB2BY => 1024 ** 3;

# Command line options with Getopt::Long
our $verbose    = '';
our $help       = '';
our $pnfsroot   = undef;
our $recursive  = '';
our $show_fullname = '';
our $show_replica_status = '';

sub usage
{
  print <<HEAD;
Extended listing of a directory. 

The command line options are

-v|--verbose              display debug information (D=false)
-h|--help                 show help on this tool and quit (D=false)
-R|--recursive            traverse the path recursively (D=false)
-p|--pnfsroot             pnfs namespace to prepend to filename (D=config)
-f|--show-fullname        show fully specified PFN(D=0)
-s|--show-replica-status  show replica status(P,C etc) D=0)

Example usage:
perl -w $0 /store/PhEDEx_LoadTest07
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions   'verbose!' => \$verbose,
                  'help!' => \&usage,
             'pnfsroot=s' => \$pnfsroot,
        'f|show-fullname' => \$show_fullname,
  's|show-replica-status' => \$show_replica_status,
            'R|recursive!'=> \$recursive;
  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}

sub main
{
  readOptions;

  # Read the pathname
  my $path = shift @ARGV;
  die q|Dataset Path not specified!| unless defined $path;

  my $fileinfo = dCacheTools::Filemap->new({
        source => q|path|,
          path => $path, 
      pnfsroot => $pnfsroot,
     recursive => $recursive,
     get_stats => 1,
       verbose => $verbose
  })->fileinfo;
  my $totalsize = 0;
  my $replicasize = 0;
  my $FORMAT = qq|%10s %3d %7s %4s %12s %17s %s %24s %s\n|;
  my $ri = dCacheTools::Replica->new;
  for my $file (sort { $fileinfo->{$a}{mtime} <=> $fileinfo->{$b}{mtime} } keys %$fileinfo) {
    my $pnfsid = $fileinfo->{$file}{pnfsid};
    my @poolList = @{$fileinfo->{$file}{pools}};
    my $poolstr = '';
    if ($show_replica_status) {
      for my $p (@poolList) {
        my $pool = dCacheTools::Pool->new({ name => $p });
        $pool->online or next;

        # is this a precious replica?
        my @result = $pool->exec({ command => qq|rep ls -l $pnfsid| });
        $pool->alive or warn qq|Pool $p did not respond! skipped\n| and next;
        $ri->repls($result[0]);
        $poolstr .= $p.q|[| . (($ri->precious) ? 'P' : 'C') . q|] |;
      }
    }
    else {
      $poolstr = join(' ', @poolList);
    }
    my $timestamp = strftime qq|%b %d %Y %H:%M|, localtime $fileinfo->{$file}{mtime};
    my $fname = $file;
    $fname =~ s#$pnfsroot##;
    printf $FORMAT, $fileinfo->{$file}{mode}, 
                    $fileinfo->{$file}{nlink}, 
                    $fileinfo->{$file}{user}, 
                    $fileinfo->{$file}{group}, 
                    (Math::BigInt->new($fileinfo->{$file}{size}))->bstr, 
                    $timestamp, 
                    (($show_fullname) ? $fname : basename($fname)), 
                    $pnfsid, 
                    trim($poolstr);
    $totalsize   += $fileinfo->{$file}{size};
    $replicasize += $fileinfo->{$file}{size} * scalar(@poolList);
  }
  printf ">>> Files = %d, Total size = %9.2f GB, Replica size = %9.2f GB\n", 
      scalar keys %$fileinfo, $totalsize/GB2BY, $replicasize/GB2BY;
}

# subroutine definition done
main;
__END__
