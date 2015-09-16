#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP::FPM::Instance;

use Moose;

use Rex::Apache::Deploy qw/Symlink/;
use File::Spec;
use Data::Dumper;
use Application::Download;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Service;


extends qw(Application::PHP::Instance);

has owner => (
  is => "ro",
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my $php_fpm_config = "/etc/php-fpm.d/" . $self->app->project->vhost . ".conf";
    if(is_file($php_fpm_config)) {
      my ($user_line) = grep { m/^user =/ } split(/\n/, cat $php_fpm_config);
      my ($null, $user) = split(/ = /, $user_line);
      return $user;
    }
  }
);

has group => (
  is => "ro",
  lazy => 1, 
  default => sub {
    my ($self) = @_;
    my $php_fpm_config = "/etc/php-fpm.d/" . $self->app->project->vhost . ".conf";
    if(is_file($php_fpm_config)) {
      my ($group_line) = grep { m/^group =/ } split(/\n/, cat $php_fpm_config);
      my ($null, $group) = split(/ = /, $group_line);
      return $group;
    }
  }
);

override detect_service_name => sub {
  my ($self) = @_;
  return "php-fpm";
};

override activate => sub {
  my ($self) = @_;
  run "ln -snf " . File::Spec->catdir($self->instance_path, "deploy", $self->deploy_version, "public") . " " . $self->doc_root;
  $self->restart();
};

1;
