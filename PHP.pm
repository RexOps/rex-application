#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP;

use Rex::Commands::Run;
use Moose;

has post_configuration => (
  is      => 'ro',
  default => sub { 1 },
);

has post_migration => (
  is      => 'ro',
  default => sub { 1 },
);

extends qw(Application::Static);

Project->register_app_type(500, __PACKAGE__, sub {
  my @php_out    = run "rpm -qa | grep php";

  if(scalar @php_out >= 1) {
    return 1;
  }

  return 0;
});

1;

