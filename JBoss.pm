#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::JBoss;

use Moose;
use File::Spec;

use Rex::Commands::Fs;
use Rex::Commands::Run;

use Application::JBoss::Instance;

extends qw(Application::Base);

override get_instances => sub {
  my ($self) = @_;

  my $jboss_path = File::Spec->catdir($self->project->project_path, "jboss");

  if(!is_dir($jboss_path)) {
    return ();
  }

  my @jbosses = grep {
    is_dir(File::Spec->catdir($jboss_path, $_))
    && is_dir(File::Spec->catdir($jboss_path, $_, "deployments"))
  } list_files $jboss_path;

  my @ret;

  for my $j_instance (@jbosses) {
    push @ret, Application::JBoss::Instance->new(
      app           => $self,
      instance      => $j_instance,
      instance_path => File::Spec->catdir($jboss_path, $j_instance),
    );
  }

  return @ret;
};

1;

