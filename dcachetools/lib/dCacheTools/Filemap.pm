package dCacheTools::Filemap;

use strict;
use warnings;
use Carp;
use File::stat;

use Term::ProgressBar;

use BaseTools::ConfigReader;
use BaseTools::ObjectFactory;
use dCacheTools::Companion;
use dCacheTools::PnfsManager;

our $source_types =
{
     path => q|dCacheTools::FilelistInPath|,
  dataset => q|dCacheTools::FilelistInDataset|,
   infile => q|dCacheTools::FilelistInFile|
};

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  defined $attr->{source} or
    croak q|Source key [path,dataset name,filename containing lfn/pfn] missing|;

  $attr->{progress_freq} = 10 unless defined $attr->{progress_freq};
  $attr->{get_size}      =  0 unless defined $attr->{get_size};
  $attr->{get_stats}     =  0 unless defined $attr->{get_stats};
  my $self = bless { attr => $attr }, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;

  my $pnfsroot = $self->{attr}{pnfsroot};
  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }

  my $dclass = $source_types->{$self->{attr}{source}};
  my $obj    = BaseTools::ObjectFactory->instantiate($dclass, $self->{attr});
  my @fileList = @{$obj->filelist};
  print join ("\n", @fileList), "\n" if $self->{attr}{verbose};

  # Create the relevant handler objects
  my $pnfsH = dCacheTools::PnfsManager->instance();
  my $dbc   = dCacheTools::Companion->new;

  my $info = {};
  my $nfiles = scalar @fileList;
  my $ifile = 0;
  my $next_update = -1;
  my $FORMAT = qq|Total: %d, processed|;
  my $progress = Term::ProgressBar->new({ name => sprintf ($FORMAT, $nfiles), 
                                         count => $nfiles, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  my $it = int($nfiles/100) || $self->{attr}{progress_freq};  
  for my $file (@fileList) {
    unless ((++$ifile)%$it) {
      $next_update = $progress->update($ifile) if $ifile >= $next_update;
    }
    $file = $pnfsroot.$file unless $file =~ m#^/pnfs/#;
    warn qq|Error. $file: not a file or disappeared!\n| 
      and next unless -f $file;
    print STDERR ">>> Processing $file ...\n" if $self->{attr}{verbose};

    my $pnfsid = dCacheTools::PnfsManager->pfn2id($file);
    warn qq|Error. pfn2id failed for $file, skipped\n| and next unless defined $pnfsid;
    warn qq|Error. Incorrect format of pnfsid=$pnfsid, skipped\n| and next
      unless $pnfsid =~ /^[0-9A-F]{24,}$/;
    $info->{$file}{pnfsid} = $pnfsid;

    # file pool(s)
    my @poolList = sort $dbc->pools({ pnfsid => $pnfsid });
    $info->{$file}{pools} = [@poolList];

    next unless ($self->{attr}{get_size} or $self->{attr}{get_stats});

    # File properties
    my $stats = stat $file or warn qq|No $file: $!, skipped\n| and next;

    # size
    my $size = $stats->size;
    if ($size == 1) { # filesize > 2GB
      my $status;
      $size = $pnfsH->pnfs_filesize({ pnfsid => $pnfsid });
      $size = -1 unless defined $size;
    }
    $info->{$file}{size} = $size;

    next unless $self->{attr}{get_stats};
    my $mode = format_mode($stats->mode);
    $info->{$file}{mode}  = $mode;
    $info->{$file}{nlink} = $stats->nlink;
    $info->{$file}{user}  = (getpwuid $stats->uid)[0];
    $info->{$file}{group} = (getgrgid $stats->gid)[0];
    $info->{$file}{mtime} = $stats->mtime;
  }
  $progress->update($ifile) if $ifile > $next_update;
  $self->{info} = $info;
}

# Lifted from File::Stat::Ls - I could not find an rpm for that module
sub format_mode 
{
  my $mode = shift;
  my @perms = qw(--- --x -w- -wx r-- r-x rw- rwx);
  my @ftype = qw(. p c ? d ? b ? - ? l ? s ? ? ?);
  $ftype[0] = '';
  my $setids = ($mode & 07000)>>9;
  my @permstrs = @perms[($mode&0700)>>6, ($mode&0070)>>3, $mode&0007];
  my $ftype = $ftype[($mode & 0170000)>>12];

  if ($setids) {
    if ($setids & 01) {         # Sticky bit
      $permstrs[2] =~ s/([-x])$/$1 eq 'x' ? 't' : 'T'/e;
    }
    if ($setids & 04) {         # Setuid bit
      $permstrs[0] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
    }
    if ($setids & 02) {         # Setgid bit
      $permstrs[1] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
    }
  }

  join '', $ftype, @permstrs;
}

sub fileinfo
{
  my $self = shift;
  $self->{info}; 
}

1;
__END__
package main;
my $obj = dCacheTools::Filemap->new({
    source => q|dataset|, 
   dataset => q|/RelValQCD_Pt_50_80/CMSSW_1_6_10-RelVal-1204132718/GEN-SIM-DIGI-RECO|, 
  get_size => 1 
});
my $fileinfo = $obj->fileinfo;
for my $file (keys %$fileinfo) {
  print join (" ", $file, @{$fileinfo->{$file}{pools}}, $fileinfo->{$file}{size}), "\n";
}
