# (c)
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Static;

use Moose;
use Rex::Commands::Run;

extends qw(Application::Base);

has vhost => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    $self->defaults->{vhost};
  },
);

has post_configuration => (
  is      => 'ro',
  default => sub { 1 },
);

has '+defaults' => (
  default => sub {
    my $self = shift;
    return {
      document_root_directory        => "app",
      deploy_stash_directory         => "deploy",
      deploy_configuration_directory => "conf",
      data_directory                 => "shared",
      manager_path                   => "manager",
      instance_prefix                => ( $ENV{"instance_prefix"} || "i" ),
      vhost                          => $ENV{vhost},
      deploy_path => File::Spec->catdir( $self->project->project_path, "www" ),
      },
      ;
  },
);

override get_instances => sub {
  my ($self) = @_;

  my $instance_class = ref($self) . "::Instance";
  return (
    $instance_class->new(
      app           => $self,
      instance      => $self->project->defaults->{vhost},
      instance_path => File::Spec->catdir(
        (
               $self->project->defaults->{deploy_path}
            || $self->project->defaults->{instance_path}
        ),
        $self->project->defaults->{vhost}
      ),
    )
  );

};

override switch => sub {
  my ($self) = @_;
  my $inactive = $self->get_deployable_instance;
  $inactive->activate;
};

Project->register_app_type(
  1000,
  __PACKAGE__,
  sub {
    my @httpd_out = run "rpm -qa | grep httpd";

    if ( scalar @httpd_out >= 1 ) {
      return 1;
    }

    return 0;
  }
);

1;

