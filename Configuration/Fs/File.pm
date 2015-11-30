# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Configuration::Fs::File;

use Moose;
use IO::All;
use File::Basename qw(basename);

use Rex::Commands::File;

has lookup_path => (
  is => 'ro',
  isa => 'Str',
);

has name => (
  is => 'ro',
  isa => 'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return basename($self->lookup_path);
  },
);

has configuration => (
  is => 'ro',
  does => 'Application::Configuration::Type::Base',
);

has content => (
  is => 'ro',
  isa => 'Str',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $parameter = $self->configuration->parameter;
    if(ref $parameter eq "CODE") {
      $parameter = $parameter->();
    }

    return template($self->lookup_path, $parameter);
  },
);

with qw(Application::Configuration::Fs::Base);

1;
