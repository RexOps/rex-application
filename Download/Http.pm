package Application::Download::Http;

use Moose;
use File::Basename;
use Carp;
require Rex::Commands;
require Rex::Commands::Download;

extends qw(Application::Download::Base);

sub download {
  my ( $self, $url, $tmp_dir ) = @_;

  my $dl_file;
  Rex::Commands::LOCAL {
    rmdir $tmp_dir;
    mkdir $tmp_dir;

    Rex::Commands::Download::download( $url,
      "$tmp_dir/" . File::Basename::basename($url) );

    my $deploy_file = File::Basename::basename($url);

    $dl_file = "$tmp_dir/$deploy_file";
  };

  if ( !-f $dl_file ) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
