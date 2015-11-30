#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Configuration::Type::Cmdb_to_properties;

use Moose;
use File::Spec;
use Rex::Commands::Fs;
require Rex::Commands;

use Rex::CMDB;
require Rex::Commands;

use Application::Configuration::Fs::File;

has target_filename => (is => 'ro', isa => 'Str');

has files => (
  is => 'ro',
  isa => 'ArrayRef[Application::Configuration::Fs::File]',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my @files;

    my $data = Rex::Commands::get(cmdb());
    delete $data->{auth};
    my @content;
    for my $key (keys %{ $data }) {
      push @content, "$key = " . $data->{$key};
    }

    push @files, Application::Configuration::Fs::File->new(
            lookup_path   => $self->target_filename,
            configuration => $self,
            content       => join("\n", @content),
            name          => $self->target_filename,
          );

    return \@files;
  },
);

with qw(Application::Configuration::Type::Base);

1;
