#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Configuration::Type::Fs;

use Moose;
use File::Spec;
use Rex::Commands::Fs;
require Rex::Commands;

use Application::Configuration::Fs::File;

has files => (
  is => 'ro',
  isa => 'ArrayRef[Application::Configuration::Fs::File]',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my @files;

    my $local_path = $self->source;
    $local_path =~ s|^fs://||;

    Rex::Commands::LOCAL sub {
      @files = 
        map {
          $_ = Application::Configuration::Fs::File->new(
            lookup_path => File::Spec->catfile($local_path, $_),
            configuration => $self,
          );
        }
        grep {
          is_file(File::Spec->catfile($local_path, $_))
        }
        list_files($local_path);
    };

    return \@files;
  },
);

with qw(Application::Configuration::Type::Base);

1;
