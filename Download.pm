#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Download;

use strict;
use warnings;

require Rex::Commands;
use Rex::Commands::Download;
use Rex::Commands::Fs;

use File::Basename;

BEGIN {
  use Rex::Shared::Var;
  share qw(%download_count $deploy_file);
};

sub get {
  my ($url) = @_;

  Rex::Logger::info("Check to download: $url");

  my $tmp_dir;

  if(! $download_count{$url}) {
    $download_count{$url} = 1;
  }
  else {
    $download_count{$url} = $download_count{$url} + 1;
  }

  if($url =~ m/^http:/) {
    Rex::Commands::LOCAL {
      $tmp_dir = "tmp/deploy";

      if($download_count{$url} && $download_count{$url} > 1) {
        $url = "$tmp_dir/$deploy_file";
        return;
      }

      rmdir $tmp_dir;
      mkdir $tmp_dir;

      download $url, "$tmp_dir/" . File::Basename::basename($url);

      $deploy_file = File::Basename::basename($url);

      $url = "$tmp_dir/$deploy_file";
    };
  }
  elsif($url =~ m/^artifactory:/) {

    Rex::Commands::LOCAL {
      # we must download the war from artifactory
      $tmp_dir = "tmp/deploy";

      if($download_count{$url} && $download_count{$url} > 1) {
        $url = "$tmp_dir/$deploy_file";
        return;
      }

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

      my ($repository, $package, $version) = split(/\//, substr($url, length("artifactory://")));
      $deploy_file = Artifactory::download {
        repository => $repository,
        package    => $package,
        version    => $version,
        to         => $tmp_dir,
        %q_params
      };

      $url = "$tmp_dir/$deploy_file";
    };
  }

  return $url;
}


1;
