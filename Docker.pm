#
# (c) Jan Gehring
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Docker;

use Moose;
use Data::Dumper;

use Rex::Helper::Run;
use Rex::Commands::Run;

use Docker::Client;

use Application::Docker::Instance;

extends qw(Application::Base);

has name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->defaults->{instance_prefix};
    }
);

has '+defaults' => (
    default => sub {
        my $self = shift;
        return { instance_prefix => ( $ENV{"instance_prefix"} || "i" ), },;
    },
);

has docker => (
    is      => 'ro',
    isa     => 'Docker::Client',
    lazy    => 1,
    default => sub {
        return Docker::Client->new;
    },
);

has '+need_start_before_deploy' => ( default => sub { 0 }, );

override get_instances => sub {
    my ($self) = @_;

    my $instance_class = ref($self) . "::Instance";

    my $app_name = $self->name;
    my @containers =
      grep { $app_name ? $self->_test( $app_name, $_->{Names} ) : 1 }
      @{ $self->docker->containers->list };

    my @ret;

    for my $c_instance (@containers) {
        push @ret,
          $instance_class->new(
            app           => $self,
            instance      => $c_instance->{Names}->[0],
            instance_path => $c_instance->{Id},
            is_active     => 1,
          );
    }

    # push a new instance on the stack which is "inactive"
    my $count = scalar(@containers) + 1;
    my $new_name = $self->name . "-" . sprintf( "%02i", $count );
    push @ret,
      $instance_class->new(
        app       => $self,
        instance  => $new_name,
        is_active => 0,
      );

    return @ret;
};

sub _test {
    my ( $self, $name, $names ) = @_;
    for my $n ( @{$names} ) {
        if ( $n =~ m/^\/$name\-\d+$/ ) { return 1; }
    }

    return 0;
}

Project->register_app_type(
    90,
    __PACKAGE__,
    sub {
        if ( can_run("docker") ) {
            return 1;
        }
        return 0;
    }
);

1;

