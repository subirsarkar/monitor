#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Copy;
use POSIX qw/strftime/;
use List::Util qw/min max/;
use Template::Alloy;
use LWP::Simple;
use JSON;

use Util qw/trim/;
use WebTools::Page;
use ConfigReader;
use AvailableServers;
use CompStatusParser;
use TaskGraphParser;
use MsgQueueParser;

sub createHTML
{
  my $content = shift;
  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $htmlFile = qq|$config->{baseDir}/html/overview.html|;
  my $tmpFile = qq|$htmlFile.tmp|;
  my $fh = IO::File->new($tmpFile, 'w');
  $fh->opened or die qq|Failed to open $tmpFile, $!, stopped|;
  print $fh $content;
  $fh->close;

  # Atomic step
  # use a temporary file and then copy to the final in an atomic step
  # Slightly irrelavant in this case
  copy $tmpFile, $htmlFile or
        warn qq|Failed to copy $tmpFile to $htmlFile: $!\n|;
  unlink $tmpFile;
}
sub color_code
{
  my ($ntasks, $attr) = @_;
  my $color_code = 'ok';
  $ntasks > $attr->{limit_warn} and $color_code = 'warn';
  $ntasks > $attr->{limit_ko} and $color_code = 'ko';
  $color_code;
}
sub showTasklist
{
  my ($tt, $tmplFile, $outref, $srv, $parser_tg, $parser_mq, $tag) = @_;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  $tt->process_simple(qq|$tmplFile/${tag}_task_header|, {}, $outref) or die $tt->error;
  my $dict  = {};
  for ($srv->list) {
    my $webserver = $srv->webserver($_);
    my $url = q|http://|.$webserver.q|:8888/taskgraph/?tasktype=All&length=1&span=days&type=list|;
    print ">>> processing $url\n";
    $parser_tg->parse({ url => $url });

    $url = q|http://|.$webserver.q|:8888/compstatus|;
    print ">>> processing $url\n";
    $parser_mq->parse({ url => $url });

    my $n_submitting = $parser_tg->submitting || 0;
    $dict->{$_} =
    { 
             server_name => $_,
              web_server => $webserver, 
               submitted => ($parser_tg->submitted || 0), 
                   ended => ($parser_tg->ended || 0), 
              submitting => $n_submitting,
           color_code_tg => color_code($n_submitting, {limit_warn => ($config->{color_code}{tasklist}{notice} || 10), 
                                                         limit_ko => ($config->{color_code}{tasklist}{warning} || 50)}),
           not_submitted => ($parser_tg->not_submitted || 0),
        partially_killed => ($parser_tg->partially_killed || 0),
               msg_queue => ($parser_mq->total || 0),
           color_code_mq => color_code($parser_mq->total, {limit_warn => ($config->{color_code}{msgqueue}{notice} || 500), 
                                                             limit_ko => ($config->{color_code}{msgqueue}{warning} || 1000)})
    };
  }
  for (sort { $dict->{$b}{submitting} <=> $dict->{$a}{submitting} } keys %$dict) {
    $tt->process_simple(qq|$tmplFile/${tag}_task_row|, $dict->{$_}, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/${tag}_task_footer|, {}, $outref) or die $tt->error;
}
sub getImagePath
{
  my ($srv, $url) = @_;
  print ">>> processing $url\n";
  my $content = WebTools::Page->Content({ url => $url });
  if ( length $content ) {
    $content = (split /\n/, $content)[-1]; 
    $content  = trim($content);
    #$content =~ s@<html><body>(?:.*?)<img src="..@@;
    $content =~ s@<html><body>@@;
    $content =~ s@<img src="..@@;
    $content =~ s@"></body></html>@@;
  }
  (length $content) ? qq|http://$srv:8888$content| : '';
}
sub main
{
  my $reader   = ConfigReader->instance();
  my $config   = $reader->config;
  my $verbose  = $config->{verbose} || 0;
  my $tmplFile = qq|$config->{baseDir}/tmpl/crab_overview.html.tmpl|;

  my $tt = Template::Alloy->new(
    EXPOSE_BLOCKS => 1,
         ABSOLUTE => 1,
     INCLUDE_PATH => qq|$config->{baseDir}/tmpl|,
      OUTPUT_PATH => qq|$config->{baseDir}/html|
  );
  my $output = q||;
  my $outref = \$output;

  my $timestamp = time;
  my $str = strftime qq|%Y-%m-%d %H:%M:%S GMT|, gmtime($timestamp);
  my $data = 
  {
    date => $str
  };
  $tt->process_simple(qq|$tmplFile/page_header|, $data, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/server_header|, {}, $outref) or die $tt->error;

  $tt->process_simple(qq|$tmplFile/server_status_header|, {}, $outref) or die $tt->error;
  my $av_servers = AvailableServers->new;
  $av_servers->parse({ url => q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AnalysisOperationsServerList| });
  my $parser = CompStatusParser->new;
  for my $srv ($av_servers->list) {
    my $webserver = $av_servers->webserver($srv);
    my $url = qq|http://$webserver:8888/compstatus|;
    print ">>> processing $url\n";
    $parser->parse({ url => $url });
    my $jt = ($parser->handled || 0) + ($parser->not_handled || 0);
    $tt->process_simple(qq|$tmplFile/server_status_row|, 
    { 
       web_server => $webserver, 
      server_name => $srv, 
                a => $jt, 
                b => ($parser->output_requested || 0), 
                c => ($parser->in_progress || 0)
    }, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/server_status_footer|, {}, $outref) or die $tt->error;

  # Task List
  my $parser_tg = TaskGraphParser->new;
  my $parser_mq = MsgQueueParser->new;
  showTasklist($tt, $tmplFile, $outref, $av_servers, $parser_tg, $parser_mq, 'all_server');

  $av_servers->parse({ url => q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AvailableServerList| });
  showTasklist($tt, $tmplFile, $outref, $av_servers, $parser_tg, $parser_mq, 'server');
  $tt->process_simple(qq|$tmplFile/server_footer|, {}, $outref) or die $tt->error;

  # Server plots
  $av_servers->parse({ url => q|http://cmsdoc.cern.ch/cms/LCG/crab/config/AnalysisOperationsServerList| });
  $tt->process_simple(qq|$tmplFile/server_plots_header|, {}, $outref) or die $tt->error;

  # Jobs plots
  $tt->process_simple(qq|$tmplFile/server_plots_jobs_header|, {}, $outref) or die $tt->error;
  for my $srv ($av_servers->list) {
    my $wsrv = $av_servers->webserver($srv);

    my $url = qq|http://$wsrv:8888/graphjobstcum/?length=12&span=hours|;
    my $path = getImagePath($wsrv, $url);
    my $img = basename $path;
    my $npath = qq|images/server/$srv-$img|;
    getstore($path, qq|$config->{baseDir}/$npath|);
    $tt->process_simple(qq|$tmplFile/server_plots_jobs_row|, 
       { 
              server_name => $srv, 
               web_server => $wsrv, 
         image_path_cumul => $npath}, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/server_plots_jobs_footer|, {}, $outref) or die $tt->error;

  # Message Queue plots
  $tt->process_simple(qq|$tmplFile/server_plots_msgq_header|, {}, $outref) or die $tt->error;
  for my $srv ($av_servers->list) {
    my $wsrv = $av_servers->webserver($srv);
    my $url = qq|http://$wsrv:8888/msgblnc/|;
    my $path = getImagePath($wsrv, $url);
    my $img = basename $path;
    my $npath = qq|images/server/$srv-$img|;
    getstore($path, qq|$config->{baseDir}/$npath|);
    $tt->process_simple(qq|$tmplFile/server_plots_msgq_row|, 
       { 
              server_name => $srv, 
               web_server => $wsrv, 
         image_path_msgq => $npath}, $outref) or die $tt->error;
  }
  $tt->process_simple(qq|$tmplFile/server_plots_msgq_footer|, {}, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/server_plots_footer|, {}, $outref) or die $tt->error;
  $tt->process_simple(qq|$tmplFile/page_footer|, {}, $outref) or die $tt->error;

  # Dump the html content in a file 
  createHTML $output;
}
main;
__END__
