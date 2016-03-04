# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Static;

use Moose;
use Rex::Commands::Run;

has vhost => (
  is => 'ro',
);

has post_configuration => (
  is      => 'ro',
  default => sub { 1 },
);

extends qw(Application::Base);

override get_instances => sub {
  my ($self) = @_;

  my $instance_class = ref($self) . "::Instance";

  return ($instance_class->new(
    app => $self,
    instance => $self->project->vhost,
    instance_path => File::Spec->catdir($self->project->project_path, "www", $self->project->vhost),
  ));

};

Project->register_app_type(1000, __PACKAGE__, sub {
  my @httpd_out = run "rpm -qa | grep httpd";

  if(scalar @httpd_out >= 1) {
    return 1;
  }

  return 0;
});

1;

