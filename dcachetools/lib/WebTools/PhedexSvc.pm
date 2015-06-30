package WebTools::PhedexSvc;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use LWP::UserAgent;
use URI::Escape;

use BaseTools::Util qw/trim/;

our $_bquery = q|https://cmsweb.cern.ch/phedex/datasvc/perl/prod|;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  $attr->{verbose} = 0 unless defined $attr->{verbose};
  bless {
    _verbose => $attr->{verbose},
    _options => undef
  }, $class;
}
sub options
{
  my ($self, $attr) = @_;
  $self->{_attr} = $attr;
  
  my $params = '';
  if (defined $attr) {
    $params .= sprintf qq|&node=%s|,     $attr->{node} if exists $attr->{node};
    $params .= sprintf qq|&se=%s|,       $attr->{se}   if exists $attr->{se};
    $params .= sprintf qq|&complete=%s|, $attr->{complete}
      if (defined $attr->{complete} and  $attr->{complete} ne 'na');
    $params .= sprintf qq|&create_since=%s|, $attr->{create_since} if defined $attr->{create_since}; # unix timestamp
    $params .= sprintf qq|&group=%s|, $attr->{group} if defined $attr->{group};
    $params .= sprintf qq|&limit=%d|, $attr->{limit} if defined $attr->{limit};
    $params .= sprintf qq|&subscribed=%s|, $attr->{subscribed} if defined $attr->{subscribed};

    print ">>> $params\n" if $self->{_verbose};
    $self->{_options} = $params;
  }
  $self->{_options};
}
sub blocks
{
  my ($self, $dataset) = @_;
  my $info = {};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 120);

  my $b = (defined $dataset and length $dataset) 
       ? uri_escape(qq|$dataset*|) 
       : uri_escape(qq|*|); 
  my $query = sprintf qq|$_bquery/%s?block=%s|, qq|blockReplicas|, $b;
  $query .= $self->{_options} if defined $self->{_options};
  print "$query\n" if $self->{_verbose};

  my $response = $agent->get($query);

  # query ok, now look inside the Data::Dumper data structure
  if ($response->is_success) {
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{BLOCK};
    for my $block (@$list) {
      print join(' ', $block->{NAME}, 
                      $block->{FILES}, 
                      $block->{BYTES}), "\n" if $self->{_verbose};
      $info->{$block->{NAME}} = {
           files => $block->{FILES}, 
           bytes => $block->{BYTES},
         replica => {      
                group => $block->{REPLICA}[0]->{GROUP} || 'undefined', 
           subscribed => $block->{REPLICA}[0]->{SUBSCRIBED},
             complete => $block->{REPLICA}[0]->{COMPLETE},
                files => $block->{REPLICA}[0]->{FILES},
                bytes => $block->{REPLICA}[0]->{BYTES}
         }
      };
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}
sub _filesPerBlock
{
  my ($self, $block, $files) = @_;

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 120);

  # escape the offending # character in the blockname string
  my ($dataset, $datablock) = split /#/, $block;
  $block = join uri_escape("#"), $dataset, $datablock;

  # Now retrieve the file replicas for ths block
  my $query = sprintf qq|$_bquery/%s?block=%s|, qq|fileReplicas|, $block;
  print "$query\n" if $self->{_verbose};

  my $response = $agent->get($query);
  if ($response->is_success) {  
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{BLOCK}[0]{FILE};
    for my $file (@$list) {
      print join(' ', $file->{NAME}, $file->{BYTES}), "\n" if $self->{_verbose};
      $files->{$file->{NAME}} = 
      { 
           size => $file->{BYTES}, 
        dataset => $dataset, 
          block => $datablock
      };
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $files;
}
sub files
{
  my ($self, $dataset) = @_;
  my $info = {};  

  if (defined $dataset and length $dataset) {
    my ($set, $block) = (split /#/, $dataset);
    $self->_filesPerBlock($dataset, $info) and return $info if $block;
  }
  my $blocks = $self->blocks($dataset);
  for my $bname (sort keys %$blocks) {
    $self->_filesPerBlock($bname, $info);
  }
  $info;
}
sub nodemap
{
  my $self = shift;
  my $info = {};  

  my $query = $_bquery.qq|/nodes|;
  print "$query\n" if $self->{_verbose};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 15);
  my $response = $agent->get($query);

  if ($response->is_success) {
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{NODE};
    for my $node (@$list) {
      print join(' ', $node->{NAME} || '?', 
                      $node->{ID} || -1, 
                      $node->{SE} || '?', 
                      $node->{TECHNOLOGY} || '?',
                      $node->{KIND} || '?'), 
        "\n" if $self->{_verbose};
      my $name = delete $node->{NAME};
      $info->{$name} = $node;
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}
sub groupmap
{
  my $self = shift;
  my $info = {};  

  my $query = $_bquery.qq|/groups|;
  print "$query\n" if $self->{_verbose};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 15);
  my $response = $agent->get($query);

  if ($response->is_success) {
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{GROUP};
    for my $group (@$list) {
      print join(' ', $group->{NAME} || '?', 
                      $group->{ID} || -1), 
        "\n" if $self->{_verbose};
      my $name = delete $group->{NAME};
      $info->{$group->{NAME}}{id} = $group->{ID};
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}
sub subscriptions
{
  my $self = shift;
  my $info = {};  

  my $query = qq|$_bquery/transferrequests?|;
  $query .= $self->{_options} if defined $self->{_options};
  print "$query\n" if $self->{_verbose};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 120);
  my $response = $agent->get($query);

  if ($response->is_success) {
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{REQUEST};
    for my $req (@$list) {
      my $datasets = $req->{DATA}{DBS}{DATASET};
      $datasets = $req->{DATA}{DBS}{BLOCK} unless scalar @$datasets;
      for my $dset (@$datasets) {
	my ($dname, $block) = (split /#/, $dset->{NAME});
        $info->{$dname}{dbs}{id}             = $dset->{ID};
        $info->{$dname}{dbs}{files}          = $dset->{FILES} || -1;
        $info->{$dname}{dbs}{bytes}          = $dset->{BYTES} || -1;
        push @{$info->{$dname}{dbs}{blocks}}, $block if defined $block;

        $info->{$dname}{request}{id}         = $req->{ID};
        $info->{$dname}{request}{move}       = $req->{MOVE};
        $info->{$dname}{request}{group}      = $req->{GROUP} || 'undefined';
        $info->{$dname}{request}{priority}   = $req->{PRIORITY};
        $info->{$dname}{request}{custodial}  = $req->{CUSTODIAL};
        $info->{$dname}{request}{static}     = $req->{STATIC};
        $info->{$dname}{request}{time}       = $req->{TIME_CREATE};

        $info->{$dname}{requester}{id}       = $req->{REQUESTED_BY}{ID};
        $info->{$dname}{requester}{name}     = $req->{REQUESTED_BY}{NAME};
        $info->{$dname}{requester}{host}     = $req->{REQUESTED_BY}{HOST};
        $info->{$dname}{requester}{user}     = $req->{REQUESTED_BY}{USERNAME};
        $info->{$dname}{requester}{comments} = $req->{REQUESTED_BY}{COMMENTS}{'$T'};
        $info->{$dname}{requester}{email}    = $req->{REQUESTED_BY}{EMAIL};
        $info->{$dname}{requester}{dn}       = $req->{REQUESTED_BY}{DN} || 'undefined';

        my $nodes = $req->{DESTINATIONS}{NODE};
        for my $node (@$nodes) {
	  my $nodename = $node->{NAME};
	  my $sename   = $node->{SE};
          my $mynode = 0;
          (defined $self->{_attr}{node} and $nodename eq $self->{_attr}{node}) and $mynode = 1;
          (defined $self->{_attr}{se}   and $sename   eq $self->{_attr}{se})   and $mynode = 1;
          if (defined $node->{DECIDED_BY}{DECISION} and $node->{DECIDED_BY}{DECISION} eq 'y') {
            unless (grep { /$sename/ } @{$info->{$dname}{destination}{selist}}) {
	      push @{$info->{$dname}{destination}{selist}},   $sename;
              push @{$info->{$dname}{destination}{nodelist}}, $nodename;
  	    }
          }
          if ($mynode) {
            $info->{$dname}{approver}{id}       = $node->{DECIDED_BY}{ID};
            $info->{$dname}{approver}{name}     = $node->{DECIDED_BY}{NAME};
            $info->{$dname}{approver}{host}     = $node->{DECIDED_BY}{HOST};
            $info->{$dname}{approver}{user}     = $node->{DECIDED_BY}{USERNAME};
            $info->{$dname}{approver}{dn}       = $node->{DECIDED_BY}{DN};
            $info->{$dname}{approver}{email}    = $node->{DECIDED_BY}{EMAIL};
            $info->{$dname}{approver}{decision} = $node->{DECIDED_BY}{DECISION};
            $info->{$dname}{approver}{time}     = $node->{DECIDED_BY}{TIME_DECIDED};
	  }
        }
      }
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}
sub groupusage
{
  my $self = shift;
  my $info = {};  

  my $query = $_bquery.qq|/groupusage?|;
  $query .= $self->{_options} if defined $self->{_options};
  print "$query\n" if $self->{_verbose};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 15);
  my $response = $agent->get($query);

  if ($response->is_success) {
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    my $list = $VAR1->{PHEDEX}{NODE}[0]->{GROUP};
    for my $group (@$list) {
      print join(' ', $group->{NAME} || '?', 
                      $group->{ID} || -1), 
        "\n" if $self->{_verbose};
      my $name = $group->{NAME};
      $info->{$name}{id}     = $group->{ID};
      $info->{$name}{rbytes} = $group->{NODE_BYTES};
      $info->{$name}{sbytes} = $group->{DEST_BYTES};
      $info->{$name}{rfiles} = $group->{NODE_FILES};
      $info->{$name}{sfiles} = $group->{DEST_FILES};
    }
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}
sub nodeusage
{
  my $self = shift;
  my $info = {};  

  my $query = $_bquery.qq|/nodeusage?|;
  $query .= $self->{_options} if defined $self->{_options};
  print "$query\n" if $self->{_verbose};

  # Instantiate an LWP User Agent to communicate through
  my $agent = LWP::UserAgent->new(timeout => 15);
  my $response = $agent->get($query);

  if ($response->is_success) {
    # query ok, now look inside the Data::Dumper data structure
    my $content = $response->content;
    my $VAR1; eval $content;
    $info = $VAR1->{PHEDEX}{NODE}[0];
  }
  else {
    my $status = $response->status_line;
    carp qq|>>> ERROR. query $query failed because: $status|;
  }
  $info;
}

1;
__END__
my $svc = WebTools::PhedexSvc->new({ verbose => 1 });
$svc->query({ se => qq|cmsdcache.pi.infn.it| });
my $files = $svc->files("/W5jet_0ptw100-alpgen/CMSSW_1_5_2-CSA07-2224/GEN-SIM-DIGI-RECO#dea8e81b-308c-4d53-8c67-838c178ae26b");
print Data::Dumper->Dump([$files], [qw/phedexfiles/]);
print join ("\n", sort keys %$files), "\n";

my $blocks = $svc->blocks("/W5jet_0ptw100-alpgen/CMSSW_1_5_2-CSA07-2224/GEN-SIM-DIGI-RECO");
print Data::Dumper->Dump([$blocks], [qw/blocks/]);

# --- Documentation starts
=pod

=head1 NAME

WebTools::PhedexSvc - Queries the PhEDEx data service to prepare a list of blocks/files PhEDEx believes a site should have

=head1 SYNOPSIS

  my $svc = WebTools::PhedexSvc->new({ verbose => 0 });
  $svc->query({ se => qq|cmsdcache.pi.infn.it| });
  my $files = $svc->files("/W5jet_0ptw100-alpgen/CMSSW_1_5_2-CSA07-2224/GEN-SIM-DIGI-RECO");
  print join ("\n", sort keys %$files), "\n";

=head1 REQUIRES

  LWP::UserAgent
  URI::Escape
  Data::Dumper

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

The PhEDEx data service allows one to find all the dataset block and file replicas for each site
that should be available at the site according to PhEDEx. WebTools::PhedexSvc fetches all such information and 
prepares its own data structure with the list of filename as key and blockname, filesize etc. as values for 
each file found on PhEDEx.

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor.

  $attr->{verbose}  - debug flag

=item * query ($attr): None

Prepare the query string

  $attr->{node}     - storage name (e.g T2_IT_Pisa)
  $attr->{se}       - storage name (e.g cmsdcache.pi.infn.it)
  $attr->{complete} - if enabled, looks for completed blocks only (values: y|n|na)

=item * files ($dataset): $files hash

Returns a list of files belonging to <code>$dataset</code> that could also be a block.
If the method is called without specifying the dataset name, all the datasets are fetched.
  $files = {
     '/store/mc/2007/9/26/CSA07-W5jet_0ptw100-alpgen-2224/0000/7839E239-E76C-DC11-A55F-000423D6A7C4.root' => {
              'dataset' => '/W5jet_0ptw100-alpgen/CMSSW_1_5_2-CSA07-2224/GEN-SIM-DIGI-RECO',
                'block' => 'dea8e81b-308c-4d53-8c67-838c178ae26b',
                 'size' => '1388531076'
     },
     ....
  };

=item * blocks ($dataset): $blocks hash

Returns a list of datablocks belonging to <code>$dataset</code>.
If the method is called without specifying the dataset name, all the datasets are fetched.

   $blocks = {
        '/W5jet_0ptw100-alpgen/CMSSW_1_5_2-CSA07-2224/GEN-SIM-DIGI-RECO#bd121198-c1c3-4da2-b970-9a1da97eb08d' => {
            blocks => '23',
             bytes => '32272734172',
             etc.
         }, 

   };

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::PhedexComparison

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: PhedexSvc.pm,v 1.0 2008/07/26 12:10:00 sarkar Exp $

=cut
# ----- Documentation ends
