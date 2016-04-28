package Application::Download::File;

use Moose;
use File::Basename;
use Carp;
require Rex::Commands;
require Rex::Commands::Fs;
require Rex::Commands::Download;

extends qw(Application::Download::Base);

sub download {
  my ( $self, %option ) = @_;
  
  my $url = $option{url};
  my $tmp_dir = $option{to};
  my $dl_file;
  
  my $local_path = "/" . $url->host . $url->path;

  Rex::Commands::LOCAL {
    rmdir $tmp_dir;
    mkdir $tmp_dir;

    Rex::Commands::Fs::cp($local_path, "$tmp_dir/" . File::Basename::basename($local_path));

    my $deploy_file = File::Basename::basename($local_path);

    $dl_file = "$tmp_dir/$deploy_file";
  };

  if ( !-f $dl_file ) {
    confess "Error downloading url: $url.";
  }

  return $dl_file;
}

1;
