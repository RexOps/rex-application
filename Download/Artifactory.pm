# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Download::Artifactory;

use Moose;
use Artifactory;
use Carp;

require Rex::Commands;

extends qw(Application::Download::Base);

sub download {
  my ($self, $url, $tmp_dir) = @_;

  my $dl_file;
  Rex::Commands::LOCAL {
    # we must download the war from artifactory
    $tmp_dir = "tmp/deploy";

    rmdir $tmp_dir;
    mkdir $tmp_dir;

    my ($_url, $query_string) = split(/\?/, $url);
    $query_string ||= "";

    my @query_params = split(/\&/, $query_string);
    my %q_params = ();
    for my $qp (@query_params) {
      my ($key, $val) = split(/=/, $qp, 2);
      $q_params{$key} = $val;
    }

    $url = $_url;

    my ($repository, $package, $version) = ($url =~ m|^artifactory://([^/]+)/(.*)/([^/]+)$|);
    $package =~ s/\//./g;
    my $deploy_file = Artifactory::download {
      repository => $repository,
      package    => $package,
      version    => $version,
      to         => $tmp_dir,
      %q_params
    };

    $dl_file = "$tmp_dir/$deploy_file";
  };

  if(! -f $dl_file) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
