#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP::Instance;

use Moose;

use Rex::Apache::Deploy qw/Symlink/;
use File::Spec;
use Data::Dumper;
use Application::Download;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Service;


extends qw(Application::Static::Instance);

has data_directory => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, "shared");
  },
);


1;
