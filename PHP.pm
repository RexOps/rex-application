#
# (c) 
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::PHP;

use Moose;

has vhost => (
  is => 'ro',
);

extends qw(Application::Base);

1;

