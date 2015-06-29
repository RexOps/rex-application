#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Base;

use Moose;
use Rex::Commands::Run;
use Rex::Commands::Service;

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

sub get_instances {
  die "Must be overwritten by upper class.";
}

sub switch {
  my ($self) = @_;

  my $inactive = $self->get_inactive;
  my $active = $self->get_active;

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
