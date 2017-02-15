package Application::Download::Http;

use Moose;
use File::Basename;
use Carp;
use Rex::Commands::Run;
require Rex::Commands;
require Rex::Commands::Download;
use LWP::UserAgent;

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

    my $deploy_file = File::Basename::basename($url);
    $dl_file = "$tmp_dir/$deploy_file";

    my $out = run "wget -O $dl_file " . $url->to_s . " 2>&1";
    if($? != 0) {
      unlink $dl_file;
      die "Error downloading file from server.\n" . $url->to_s . "\nERROR:\n$out\n";
    }
    
    return $dl_file;
    
  };

  if ( !-f $dl_file ) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
