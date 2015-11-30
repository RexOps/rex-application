#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Tomcat;

use Moose;
use File::Spec;

use Rex::Commands::Fs;
use Rex::Commands::Run;

use Application::Tomcat::Instance;

extends qw(Application::Base);

has name => (is => 'ro', isa => 'Str', default => sub {''});

override get_instances => sub {
  my ($self) = @_;

  my $instance_class = ref($self) . "::Instance";

  my $tomcat_path = File::Spec->catdir($self->project->project_path, "tomcat");

  if(!is_dir($tomcat_path)) {
    return ();
  }

  my $app_name = $self->name;

  my @tomcats = grep { $app_name ? m/^\Q$app_name\E\d+/ : 1 }
  grep {
    is_dir(File::Spec->catdir($tomcat_path, $_))
    && is_dir(File::Spec->catdir($tomcat_path, $_, "webapps"))
  } list_files $tomcat_path;

  my @ret;

  for my $tc_instance (@tomcats) {
    push @ret, $instance_class->new(
      app           => $self,
      instance      => $tc_instance,
      instance_path => File::Spec->catdir($tomcat_path, $tc_instance),
    );
  }

  return @ret;
};


Project->register_app_type(100, __PACKAGE__, sub {
  my @tomcat_out = run "rpm -qa | grep tomcat";

  if(scalar @tomcat_out >= 1) {
    return 1;
  }

  return 0;
});

1;

