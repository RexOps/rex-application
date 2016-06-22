#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::JBoss::Instance;

use Moose;

use common::sense;

use File::Spec;

use Rex::Commands::File;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Service;

require Rex::Commands;

BEGIN {
  use Rex::Shared::Var;
  share qw($download_count $deploy_file);
};

extends qw(Application::Instance);

has owner => (
  is => "ro",
  lazy => 1,
  default => sub {
    for my $u (qw/jboss/) {
      run "id $u";
      if($? == 0) { return $u; }
    }
  }
);

has group => (
  is => "ro",
  lazy => 1, 
  default => sub {
    for my $u (qw/jboss/) {
      run "id $u";
      if($? == 0) { return $u; }
    }
  }
);

has port => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my ($i) = ($self->instance() =~ m/(\d+)$/);
    return ((10_000 * $i) + 8080);
  }
);

override deploy_app => sub {

  my ($self, $ear, $context) = @_;

  my $tmp_dir;

  $ear = Application::Download::get($ear);

  if( ! -f $ear ) {
    die "File $ear not found.";
  }

  my $deploy_file = Application::Download::get($ear);

  file $deploy_path,
    source => $deploy_file,
    owner  => $self->owner,
    group  => $self->group,
    mode   => '0644';

  file "$deploy_file.dodeploy",
    content => 'dodeploy',
    owner  => $self->owner,
    group  => $self->group,
    mode   => '0644';

  my $is_deployed = is_file("$deploy_file.deployed");

  while(!$is_deployed) {
    Rex::Logger::info("Waiting for JBoss to deploy...");
    $is_deployed = is_file("$deploy_file.deployed");

    if(is_file("$deploy_file.failed")) {
      die "Error deploying application. Please see logfile.";
    }

    sleep 3;
  }

  Rex::Logger::info("Application deployed successfully.");

};


override detect_service_name => sub {
  my ($self) = @_;

  if(can_run "systemctl") {
    my $sysctl_out = run "systemctl list-units | grep jboss-" . $self->instance;

    if($sysctl_out) {
      return "jboss-" . $self->instance;
    }
  }

  die "Can't detect service name.";
};


1;
