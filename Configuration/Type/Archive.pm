#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Configuration::Type::Archive;

use Moose;
use File::Spec;
use Rex::Commands::Fs;
require Rex::Commands;

use Rex::CMDB;
use Rex::Commands::Run;
use Carp;

use Application::Download;
use Application::Configuration::Fs::File;
use Data::Dumper;

has files => (
  is      => 'ro',
  isa     => 'ArrayRef[Application::Configuration::Fs::File]',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my @files;

    my $extracted_dir =
      Application::Download::get( $self->source, extract => 1 );

    my @content;
    Rex::Commands::LOCAL(
      sub {
        @content =
          grep { $_ !~ m/^\./ && is_dir("$extracted_dir/$_") }
          list_files $extracted_dir;
      }
    );

    my $config_dir;
    if ( scalar @content == 1 ) {
      $config_dir = "$extracted_dir/$content[0]";
    }
    else {
      $config_dir = $extracted_dir;
    }

    Rex::Commands::LOCAL sub {
      my @dirs = ($config_dir);

      for my $d (@dirs) {
        for my $entry ( list_files($d) ) {
          if ( is_dir( File::Spec->catfile( $d, $entry ) ) ) {
            push @dirs, File::Spec->catfile( $d, $entry );
            next;
          }

          my $name = File::Spec->catfile( $d, $entry );
          $name =~ s/^\Q$config_dir\E\/?//;

          push @files, Application::Configuration::Fs::File->new(
            lookup_path   => File::Spec->catfile( $d, $entry ),
            configuration => $self,
            name          => $name,
          );
        }
      }
    };

    return \@files;
  },
);

with qw(Application::Configuration::Type::Base);

1;
