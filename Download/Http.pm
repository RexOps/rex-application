package Application::Download::Http;

use Moose;
use File::Basename;
use Carp;
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

    my $ua = LWP::UserAgent->new;
    if($ENV{http_proxy} || $ENV{https_proxy}) {
      Rex::Logger::info("Loading http proxy settings from environment:");
      Rex::Logger::info("http_proxy = " . ($ENV{http_proxy} || ''));
      Rex::Logger::info("https_proxy = " . ($ENV{https_proxy} || ''));
      $ua->env_proxy;
    }

    open(my $fh, ">", $dl_file) or die("Error opening file to write ($dl_file): $!");
    my $response = $ua->get(
      $url->to_s,
      ':content_cb' => sub {
        my ( $data, $response, $protocol ) = @_;
        print $fh $data;
      }
    );
    close $fh;

    if ( !$response->is_success ) {
      unlink $dl_file;
      die "Error downloading file from server.\nStatus: " . $response->status_line;
    }
    
    return $dl_file;
    
  };

  if ( !-f $dl_file ) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
