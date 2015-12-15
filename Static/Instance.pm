#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Static::Instance;

use Moose;

use Rex::Apache::Deploy qw/Symlink/;
use File::Spec;
use Data::Dumper;
use Application::Download;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Service;


extends qw(Application::Instance);

has stash_directory => (
  is => 'ro',
  writer => '_set_stash_directory',
  trigger => sub {
    my ($self) = @_;
    $self->_clear_deploy_directory;
  },
  default => sub { "deploy" },
);

has deploy_directory => (
  is      => 'ro',
  lazy    => 1,
  clearer => '_clear_deploy_directory',
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, $self->stash_directory, $self->deploy_version);
  },
);

has deploy_version => (
  is => 'ro',
  lazy => 1,
  trigger => sub {
    my ($self) = @_;
    $self->_clear_deploy_directory;
  },
  default => sub {
    return $ENV{version};
  },
);


has doc_root => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, "app");
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

has owner => (
  is => "ro",
  lazy => 1,
  default => sub { "apache"; }
);

has group => (
  is => "ro",
  lazy => 1, 
  default => sub { "apache"; }
);

override detect_service_name => sub { "httpd"; };

override deploy_app => sub {
  my ($self, $tar_gz, $context) = @_;

  if (!can_run "unzip") {
    die('unzip command not found.');
  }

  deploy_to(File::Spec->catdir($self->instance_path, $self->stash_directory));
  document_root($self->doc_root);

  generate_deploy_directory(sub { return $self->deploy_version });

  my $file = Application::Download::get($tar_gz);
  sudo sub {
    deploy $file;
  };

  sudo sub {
    chown $self->owner, $self->deploy_directory,
      recursive => 1;

    chgrp $self->group, $self->deploy_directory,
      recursive => 1;
  };

};

override activate => sub {
  my ($self) = @_;
  run "ln -snf " . $self->deploy_directory . " " . $self->doc_root;
  $self->restart();
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

sub create_symlinks {
  my ($self, $links) = @_;

  my $app_dir  = $self->deploy_directory;
  my $data_dir = $self->data_directory;
  
  sudo sub {

    for my $d (@{ $links }) {
      my $app_abs_path  = File::Spec->catdir($app_dir, $d);
      my $data_abs_path = File::Spec->catdir($data_dir, $d);

      Rex::Logger::info("Creating symlink: $data_abs_path -> $app_abs_path");

      file $data_abs_path, 
        ensure => "directory",
        owner  => $self->owner,
        group  => $self->group,
        mode   => "0755";

      if(is_dir($app_abs_path)) {
        my @entries = list_files $app_abs_path;
        if(scalar @entries > 0) {
          run "cp -a $app_abs_path/* $data_abs_path";
        }
      }

      rmdir $app_abs_path;
      ln $data_abs_path, $app_abs_path;
    }

  };
}


1;
