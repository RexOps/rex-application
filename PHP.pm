#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP;

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

1;

