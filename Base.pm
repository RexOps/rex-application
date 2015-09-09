#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Base;

use Moose;
use Rex::Commands::Run;
use Rex::Commands::Service;
use Data::Dumper;

has project => ( is => 'ro' );

sub get_inactive {
  my ($self) = @_;
  my ($inactive) = grep { ! $_->is_active } $self->get_instances;
  return $inactive;
}

sub get_active {
  my ($self) = @_;
  my ($active) = grep { $_->is_active } $self->get_instances;
  return $active;
}

sub get_deployable_instance {
  my ($self) = @_;

  my @instances = $self->get_instances;
  my $instance = $self->get_inactive;

  if(! $instance && scalar(@instances) == 1) {
    $instance = $self->get_active;
  }

  if(! $instance) {
    die "Can't find any instances.";
  }

  return $instance;
}

sub get_instances {
  die "Must be overwritten by upper class.";
}

sub switch {
  my ($self) = @_;

  my $inactive = $self->get_deployable_instance; # this is the inactive one
  my $active = $self->get_active;

  if($inactive == $active) {
    Rex::Logger::info("Instance already active.");
    return;
  }

  sudo sub {
    $inactive->activate;

    if($active) {
      $active->deactivate;
    }

    if( $self->project->has_httpd ) {
      service httpd => "restart";
    }
  };
}


1;
