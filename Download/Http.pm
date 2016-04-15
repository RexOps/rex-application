package Application::Download::Http;

use Moose;
use File::Basename;
use Carp;
require Rex::Commands;
require Rex::Commands::Download;

extends qw(Application::Download::Base);

sub download {
  my ( $self, %option ) = @_;
  
  my $url = $option{url};
  my $tmp_dir = $option{to};
  
  my %dl_option = ();

  if($url->has_auth) {
    $dl_option{user} = $url->user;
    $dl_option{password} = $url->password;
  }

  my $dl_file;
  Rex::Commands::LOCAL {
    rmdir $tmp_dir;
    mkdir $tmp_dir;

    Rex::Commands::Download::download( $url->to_s_without_auth,
      "$tmp_dir/" . File::Basename::basename($url), %dl_option );

    my $deploy_file = File::Basename::basename($url);

    $dl_file = "$tmp_dir/$deploy_file";
  };

  if ( !-f $dl_file ) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
