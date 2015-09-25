#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP::FPM;

use Moose;
use Application::PHP::FPM::Instance;
use Data::Dumper;

use Rex::Commands::Run;
use Rex::Apache::Deploy qw/Symlink/;

extends qw(Application::PHP);

override switch => sub {
  my ($self) = @_;
  $self->get_instances->activate;
};

Project->register_app_type(100, __PACKAGE__, sub {
  my @php_out    = run "rpm -qa | grep php-fpm";

  if(scalar @php_out >= 1) {
    return 1;
  }

  return 0;
});

1;

