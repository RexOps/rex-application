#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP::FPM::Instance;

use Moose;

use Rex -base;
use Rex::Apache::Deploy qw/Symlink/;
use File::Spec;
use Data::Dumper;
use Application::Download;
use Rex::Commands::Run;


extends qw(Application::Instance);

has deploy_directory => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, "deploy", $self->deploy_version);
  },
);

has doc_root => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, "htdocs");
  },
);

has deploy_version => (
  is => 'ro',
  lazy => 1,
  default => sub {
    return $ENV{version};
  },
);

has is_active => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return 1;
  }
);

override detect_service_name => sub {
  my ($self) = @_;
  return "php-fpm";
};

override deploy_app => sub {

  my ($self, $tar_gz, $context) = @_;

  deploy_to(File::Spec->catdir($self->instance_path, "deploy"));
  document_root($self->doc_root);

  generate_deploy_directory(sub { return $self->deploy_version });

  deploy Application::Download::get($tar_gz); 

};

override activate => sub {
  my ($self) = @_;
  run "ln -snf " . File::Spec->catdir($self->instance_path, "deploy", $self->deploy_version, "public") . " " . $self->doc_root;
  $self->restart();
};


override restart => sub {
  my ($self, $param) = @_;

  sudo sub {
    service $self->service_name => "restart";
  };
};
 
sub purge_old_versions {
  my ($self) = @_;

  my $path = $self->instance_path;
  my @files = ls File::Spec->catdir($path, "deploy");
  my @files_sorted_by_mtime =
    grep { !m/^\./ && is_dir "$path/$_" }
    sort {
      my %stat_a = stat "$path/$a";
      my %stat_b = stat "$path/$b";
      $stat_a{mtime} <=> $stat_b{mtime};
    } @files;

  while (scalar @files_sorted_by_mtime > 2) {
    my $d = shift @files_sorted_by_mtime;
    Rex::Logger::info("Removing $path/$d");
    rmdir "$path/$d";
  }
}



1;
