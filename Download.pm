#
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Download;

use strict;
use warnings;

use Rex::Commands::Fs;
use Rex::Commands::File;
use File::Basename qw(basename);
use File::Spec;
use Cwd qw(getcwd);
require Rex::Commands;

use Application::Download::URL;
use Carp;

sub get {
  my ( $url, %option ) = @_;
  my $ret;

  if ( !ref $url ) {
    my ( $proto, $host, $path ) = ( $url =~ m|^([^:]+)://([^/]+)(.*)$| );
    $url = Application::Download::URL->new(
      proto => $proto,
      host  => $host,
      path  => $path
    );
  }
  
  my $log_str = "Check to download: " . $url->proto . "://" . ( $url->has_auth ? $url->user . ":*******\@" : "" ) . $url->host . $url->path;

  Rex::Logger::info($log_str);

  my ( $tmp_dir, $deploy_file );
  $tmp_dir = "tmp/deploy";
  Rex::Commands::LOCAL( sub { mkdir $tmp_dir; } );

  my ( $type, $rest ) = ( $url =~ m|^([^:]+)://(.*)$| );

  eval "use Application::Download::\u$type";
  if ($@) {
    confess
"Error loading Application::Download::\u$type. Module not found.\nERROR: $@\n";
  }
  else {
    my $class = "Application::Download::\u$type";
    my $dl    = $class->new;
    $ret = $dl->download( url => $url, to => $tmp_dir );

    if ( exists $option{extract} && $option{extract} ) {
      Rex::Commands::LOCAL(
        sub {
          my $basename = basename($ret);
          $basename =~ s/[^a-zA-Z_0-9]/_/g;
          mkdir "$tmp_dir/extract_$basename";
          extract(
            File::Spec->catfile( getcwd(), $ret ),
            to => "$tmp_dir/extract_$basename"
          );
          $ret = "$tmp_dir/extract_$basename";
        }
      );
    }
  }

  return $ret;
}

1;
