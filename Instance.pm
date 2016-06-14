#
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Instance;

use Moose;
use File::Spec;
use Data::Dumper;
use File::Basename qw/dirname/;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Service;
require Rex::Commands;

use Array::Diff;

use overload
  '==' => sub { shift->_comp(@_) },
  'eq' => sub { shift->_comp(@_) },
  '""' => sub { shift->to_s() };

has app           => ( is => 'ro' );
has instance      => ( is => 'ro' );
has instance_path => ( is => 'ro' );

has is_active => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    if ( is_file( File::Spec->catfile( $self->instance_path, "active" ) ) ) {
      return 1;
    }

    return 0;
  }
);

has service_name => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->detect_service_name;
  }
);

has sleep_by_start => ( is => "ro", default => sub { 0 } );

has configuration_path => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir( $self->instance_path,
      $self->app->project->defaults->{deploy_configuration_directory} );
  }
);

has configuration_template_variables => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->app->project->configuration_template_variables();
  },
);

has port => (
  is      => 'ro',
  isa     => 'Int',
  lazy    => 1,
  default => sub { 80 },
);

sub activate {
  my ($self) = @_;
  sudo sub {
    my $fh =
      file_write( File::Spec->catfile( $self->instance_path, "active" ) );
    $fh->close;
  };
}

sub deactivate {
  my ($self) = @_;
  sudo sub {
    rm( File::Spec->catfile( $self->instance_path, "active" ) );
  };
}

sub detect_service_name  { die "Must be overwritten by upper class."; }
sub kill                 { die "Must be overwritten by upper class."; }
sub rescue               { die "Must be overwritten by upper class."; }
sub purge_work_directory { die "Must be overwritten by upper class."; }
sub deploy_app           { die "Must be overwritten by upper class."; }
sub deploy_lib           { die "Must be overwritten by upper class."; }

sub configure_app {
  my ( $self, $configuration_source, $configuration_dest, $params ) = @_;

  my $preview = $ENV{REX_APPLICATION_CONFIGURATION_PREVIEW} // 0;

  if ( ref $configuration_source eq "CODE" ) {
    my $cfg_ret = $configuration_source->($self);
    if ( ref($cfg_ret) =~ m/::/ ) {
      $configuration_source = $cfg_ret;
    }
    else {
      return $cfg_ret;
    }
  }

  if ( ref $params eq "CODE" ) {
    $params = $params->( $self, $configuration_source );
  }
  else {
    $params = $self->configuration_template_variables();
  }

  my $cfg_o = $configuration_source;

  if ( !ref $cfg_o ) {
    my ($cfg_type) = ( $configuration_source =~ m|^([^:]+)://| );
    if ($cfg_type) {
      my $klass = "Application::Configuration::Type::\u$cfg_type";
      eval "use $klass";
      if ($@) {
        confess "Error loading configuration type: $klass.\nError: $@\n";
      }

      # convert $params to a true hash
      my %values = %{$params};

      $cfg_o =
        $klass->new( source => $configuration_source, parameter => \%values );
    }
    else {
      confess "No configuration type found.";
    }
  }

  my $conf_dest = $self->configuration_path;

  $configuration_dest ||=
       $self->app->project->defaults->{configuration_path}
    || $self->app->project->defaults->{configuration_directory}
    || "app";

  if ( ref $configuration_dest eq "CODE" ) {
    $configuration_dest = $configuration_dest->($self);
  }

  if ( $configuration_dest !~ m/^\// ) {
    # relative path
    $configuration_dest = "$conf_dest/$configuration_dest";
  }

  sudo sub {

    if ( !$preview ) {

      # ensure that configuration directory exists
      Rex::Logger::info("Creating: $configuration_dest");
      file $configuration_dest,
        ensure => 'directory',
        owner  => $self->owner,
        group  => $self->group,
        mode   => '0755';
    }

    my $files = $cfg_o->files;
    for my $file ( @{$files} ) {

      my $dest_file = File::Spec->catfile( $configuration_dest, $file->name );

      Rex::Logger::info("Uploading configuration file: $dest_file")
        if !$preview;
      Rex::Logger::info("Preview configuration file: $dest_file") if $preview;

      my $content;
      if (
        $dest_file =~ m/\.(txt|conf|ini|json|yaml|yml|config|properties|xml)$/
        && length( $file->content ) != 0 )
      {
        $content = template( \$file->content,
          $self->app->project->configuration_template_variables );
      }
      else {
        $content = $file->content;
      }

      if ( !$preview ) {

        my %source_content = (
          ref $content eq "SCALAR"
          ? ( source => ${$content} )
          : ( content => $content ) );

        file dirname($dest_file),
          ensure => "directory",
          mode   => '0755',
          owner  => $self->owner,
          group  => $self->group;

        file $dest_file,
          mode  => '0664',
          owner => $self->owner,
          group => $self->group,
          %source_content;

      }
      else {

        # only preview
        print "\n"
          . ( ref $content ? "Upload file: " . ${$content} : $content ) . "\n";
      }
    }
  };

}

sub restart {
  my ( $self, $param ) = @_;

  sudo sub {
    service $self->service_name => "restart";
  };
}

sub stop {
  my ( $self, $param ) = @_;

  sudo sub {
    service $self->service_name => "stop";
  };
}

sub start {
  my ( $self, $param ) = @_;

  if ( !service $self->service_name => "status" ) {
    $self->service_start;
  }
}

sub service_start {
  my ($self) = @_;
  sudo sub {
    service $self->service_name => "start";
  };
}

sub wait_for_start {
  my ($self) = @_;

}

sub _comp {
  my ( $self, $other ) = @_;

  if ( !ref $other ) { return 0; }

  return ( $self->instance_path eq $other->instance_path );
}

sub to_s {
  my ($self) = @_;

  die "Instance has no name. (use 'instance' attribute)"
    if ( !$self->instance );
  return $self->instance;
}

1;
