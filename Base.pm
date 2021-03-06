#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Base;

use Moose;
use Rex::Commands::Run;
use Rex::Commands::Service;
use Data::Dumper;
use Application::Download;

has project => ( is => 'ro' );

# control if the configuration should be placed before or after the
# dapplication deployment.
has post_configuration => (
    is      => 'ro',
    default => sub { 0 },
);

# control if the db migration should be done after deployment.
has post_migration => (
    is      => 'ro',
    default => sub { 0 },
);

has defaults => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return {
            document_root_directory        => "app",
            deploy_stash_directory         => "deploy",
            deploy_configuration_directory => "conf",
            data_directory                 => "shared",
            manager_path                   => "manager",
            instance_prefix => ( $ENV{"instance_prefix"} || "i" ),
          },
          ;
    },
);

has need_start_before_deploy => (
    is      => 'ro',
    default => sub { 1 },
);

sub download {
    my ( $self, $url ) = @_;
    if ( -f $url ) { return $url; }
    return Application::Download::get($url);
}

sub get_inactive {
    my ($self) = @_;
    my ($inactive) = grep { !$_->is_active } $self->get_instances;
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
    my $instance  = $self->get_inactive;

    if ( !$instance && scalar(@instances) == 1 ) {
        $instance = $self->get_active;
    }

    if ( !$instance ) {
        die "Can't find any instances.";
    }

    return $instance;
}

sub get_instances {
    die "Must be overwritten by upper class.";
}

sub switch {
    my ($self) = @_;

    my $inactive = $self->get_deployable_instance;    # this is the inactive one
    my $active   = $self->get_active;

    if ( $inactive == $active ) {
        Rex::Logger::info("Instance already active.");
        return;
    }

    sudo sub {
        $inactive->activate;

        if ($active) {
            $active->deactivate;
        }
    };
}

1;
