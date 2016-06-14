#
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Docker::Instance;

use Moose;

use Data::Dumper;

require Rex::Commands;

extends qw(Application::Instance);

has '+instance' => ( is => 'ro', default => sub { '' } );
has '+instance_path' => (
    is      => 'ro',
    writer  => '_set_instance_path',
    default => sub { '' },
);

override deploy_app => sub {
    my ( $self, $app, $context ) = @_;
    my $params = Rex::Commands::get("params");

    my @env_keys = grep { m/^env\./ } keys %{$params};
    my @env;
    for my $e (@env_keys) {
        my ( undef, $name ) = split( /\./, $e );
        push @env, "$name=$params->{$e}";
    }

    my @bind_keys = grep { m/^bind\./ } keys %{$params};
    my @binds;
    for my $b (@bind_keys) {
        my ( undef, $name ) = split( /\./, $b );
        push @binds, "$name:$params->{$b}";
    }

    my @link_keys = grep { m/^link\./ } keys %{$params};
    my @links;
    for my $l (@link_keys) {
        my ( undef, $name ) = split( /\./, $l );
        push @binds, "$name:$params->{$l}";
    }

    my @port_keys = grep { m/^port\./ } keys %{$params};
    my %port_bindings;
    for my $p (@port_keys) {
        my ( undef, $name ) = split( /\./, $p );
        $port_bindings{$name} = [ { HostPort => $params->{$p} } ];
    }

    my $id = $self->app->docker->containers->create(
        {
            Image      => $app,
            Env        => \@env,
            HostConfig => {
                Binds        => \@binds,
                Links        => \@links,
                PortBindings => \%port_bindings,
            },
        },
        $self->instance
    );

    $self->_set_instance_path($id);
    $self->start;
};

override kill => sub {
    my ($self) = @_;
    Rex::Logger::info( "Killing container: " . $self->instance_path );
    $self->app->docker->containers->kill( $self->instance_path );
};

override restart => sub {
    my ($self) = @_;
    Rex::Logger::info( "Restarting container: " . $self->instance_path );
    $self->app->docker->containers->restart( $self->instance_path );
};

override stop => sub {
    my ($self) = @_;
    Rex::Logger::info( "Stopping container: " . $self->instance_path );
    $self->app->docker->containers->stop( $self->instance_path );
};

override start => sub {
    my ($self) = @_;
    Rex::Logger::info( "Starting container: " . $self->instance_path );
    $self->app->docker->containers->start( $self->instance_path );
};

override activate => sub {
    my ($self) = @_;
};

override deactivate => sub {
    my ($self) = @_;
};

1;
