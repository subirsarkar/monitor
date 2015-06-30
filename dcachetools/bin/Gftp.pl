#!/usr/bin/env perl
package main;

use strict;
use warnings;
use List::Util qw/min max/;

use POSIX qw/strftime/;
use Template::Alloy;

use BaseTools::ConfigReader;
use BaseTools::Util qw/storeInfo restoreInfo writeHTML/;

use dCacheTools::Cell;
use dCacheTools::GridftpCell;

our $htmlFile = q|gftp.html|;
our $tmplFile = q|../tmpl/gftp.html.tmpl|;

sub updateDB
{
  my $ndoors = shift;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $dbfile = $config->{resourceDB}{gridftp};

  return $ndoors unless defined $dbfile;

  my $nent = 0;
  if ( -r $dbfile ) {
    my $info = restoreInfo($dbfile);
    my $nel  = $info->{doors};

    storeInfo($dbfile, {doors => $ndoors} ) if $ndoors > $nel;
    $nent = max $nel, $ndoors;
  }
  else {
    storeInfo($dbfile, {doors => $ndoors} );
    $nent = $ndoors;
  }
  $nent;
}
sub main
{
  # Now create the Template::Alloy object and create the html from template
  # Create a Template::Alloy object
  my $tt = Template::Alloy->new(
    EXPOSE_BLOCKS => 1,
    RELATIVE      => 1,
    INCLUDE_PATH  => q|dcachetools/tmpl|,
    OUTPUT_PATH   => q|./|
  );
  my $output_full = q||;
  my $outref_full = \$output_full;

  # html header
  my $tstr = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
  $tt->process_simple(qq|$tmplFile/header|, 
       {site => q|Pisa|, storage => q|dCache|, timestamp => $tstr}, $outref_full) 
     or die $tt->error, "\n";

  dCacheTools::GridftpCell->header;
  my $broker = dCacheTools::Cell->new({ name => q|LoginBroker| });
  my @gftpList = grep { /GFTP/ } $broker->exec({ command => q|ls| });

  # Now update resource
  $tt->process_simple(qq|$tmplFile/table_start|, {}, $outref_full) or die $tt->error, "\n";

  my $tinfo = { domain => 'Overall'};
  for (sort @gftpList) {
    my $cell = (split /;/)[0];
    my $obj = dCacheTools::GridftpCell->new({ name => $cell });
    $obj->showLogin;

    my ($created, $failed, $denied, $active, $lmax) = 
     ($obj->logins_created,
      $obj->logins_failed,
      $obj->logins_denied,
      $obj->logins_active,
      $obj->logins_max);

    $tinfo->{created} += $created;
    $tinfo->{failed}  += $failed;
    $tinfo->{denied}  += $denied;
    $tinfo->{active}  += $active;
    $tinfo->{max}     += $lmax;

    my $row = {
       domain => (split /@/, $obj->name)[0],
      created => $created,
       failed => $failed,
       denied => $denied,
       active => $active,
          max => $lmax
    };
    $tt->process_simple(qq|$tmplFile/table_row|, $row, $outref_full) or die $tt->error, "\n";
  }
  my $ndoors = scalar @gftpList;
  my $max_doors = updateDB($ndoors);  
  print "\t>>> GridFtp doors: Installed = $max_doors, Online = $ndoors\n";

  $tinfo->{installed} = $max_doors;
  $tinfo->{online}    = $ndoors;
  $tt->process_simple(qq|$tmplFile/table_end|, $tinfo, $outref_full) or die $tt->error, "\n";

  $tt->process_simple(qq|$tmplFile/footer|, {}, $outref_full) or die $tt->error, "\n";

  # template is processed in memory, now dump
  writeHTML($htmlFile, $output_full);
}

main;
__END__
