#
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Static::Instance;

use Moose;

use File::Spec;
use Data::Dumper;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Service;
use Rex::Commands::Upload;
use File::Basename 'basename', 'dirname';

extends qw(Application::Instance);

has stash_directory => (
  is      => 'ro',
  lazy    => 1,
  writer  => '_set_stash_directory',
  trigger => sub {
    my ($self) = @_;
    $self->_clear_deploy_directory;
  },
  default => sub { shift->app->project->defaults->{deploy_stash_directory} },
);

has deploy_directory => (
  is      => 'ro',
  lazy    => 1,
  clearer => '_clear_deploy_directory',
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir( $self->instance_path, $self->stash_directory,
      $self->deploy_version );
  },
);

has deploy_version => (
  is      => 'ro',
  lazy    => 1,
  trigger => sub {
    my ($self) = @_;
    $self->_clear_deploy_directory;
  },
  default => sub {
    my $self = shift;
    return
         $self->app->project->defaults->{deploy_version}
      || $ENV{version}
      || $self->app->project->deploy_start_time;
  },
);

has data_directory => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->app->project->defaults->{data_path}
      || File::Spec->catdir( $self->instance_path,
      $self->app->project->defaults->{data_directory} );
  },
);

has doc_root => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->app->project->defaults->{document_root_path}
      || File::Spec->catdir( $self->instance_path,
      $self->app->project->defaults->{document_root_directory} );
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
  is      => "ro",
  lazy    => 1,
  default => sub { "apache"; }
);

has group => (
  is      => "ro",
  lazy    => 1,
  default => sub { "apache"; }
);

override detect_service_name => sub { "httpd"; };

override deploy_app => sub {
  my ( $self, $tar_gz, $context ) = @_;

  if ( !can_run "unzip" ) {
    die('unzip command not found.');
  }

  my $deploy_to =
    File::Spec->catdir( $self->instance_path, $self->stash_directory,
    $self->deploy_version );

  sudo sub {
    file $deploy_to,
      ensure => "directory",
      owner  => $self->owner,
      group  => $self->group,
      mode   => "0755";
  };

  my $file = $self->app->download($tar_gz);

  sudo sub {
    upload $file, "/tmp/" . basename($file);
    extract "/tmp/" . basename($file),
      to    => $deploy_to,
      owner => $self->owner,
      group => $self->group;
    unlink "/tmp/" . basename($file);
  };

};

override activate => sub {
  my ($self) = @_;
  sudo sub {
    file dirname( $self->doc_root ),
      ensure => "directory",
      owner  => $self->owner,
      group  => $self->group,
      mode   => "0755";

    run "ln -snf " . $self->deploy_directory . " " . $self->doc_root;
  };
  $self->restart();
};

# override some methods we don't need here
override rescue               => sub { };
override kill                 => sub { };
override purge_work_directory => sub { };
override deploy_lib           => sub { };

sub purge_old_versions {
  my ($self) = @_;

  my $path = $self->instance_path;
  my @files = ls File::Spec->catdir( $path, "deploy" );
  my @files_sorted_by_mtime =
    grep { !m/^\./ && is_dir "$path/$_" }
    sort {
    my %stat_a = stat "$path/$a";
    my %stat_b = stat "$path/$b";
    $stat_a{mtime} <=> $stat_b{mtime};
    } @files;

  while ( scalar @files_sorted_by_mtime > 2 ) {
    my $d = shift @files_sorted_by_mtime;
    Rex::Logger::info("Removing $path/$d");
    rmdir "$path/$d";
  }
}

sub create_symlinks {
  my ( $self, $links ) = @_;

  my $app_dir  = $self->deploy_directory;
  my $data_dir = $self->data_directory;

  sudo sub {

    for my $d ( @{$links} ) {
      my $app_abs_path  = File::Spec->catdir( $app_dir,  $d );
      my $data_abs_path = File::Spec->catdir( $data_dir, $d );

      Rex::Logger::info("Creating symlink: $data_abs_path -> $app_abs_path");

      file $data_abs_path,
        ensure => "directory",
        owner  => $self->owner,
        group  => $self->group,
        mode   => "0755";

      if ( is_dir($app_abs_path) ) {
        my @entries = list_files $app_abs_path;
        if ( scalar @entries > 0 ) {
          run "cp -a $app_abs_path/* $data_abs_path";
        }
      }

      rmdir $app_abs_path;
      ln $data_abs_path, $app_abs_path;
    }

  };
}

1;
