#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP::FPM;

use Moose;
use Application::PHP::FPM::Instance;
use Data::Dumper;

use Rex::Apache::Deploy qw/Symlink/;

extends qw(Application::PHP);

override get_instances => sub {
  my ($self) = @_;

  return Application::PHP::FPM::Instance->new(
    app => $self,
    instance => $self->project->vhost,
    instance_path => File::Spec->catdir($self->project->project_path, "www", $self->project->vhost),
  );

};

override switch => sub {
  my ($self) = @_;
  $self->get_instances->activate;
};

1;

