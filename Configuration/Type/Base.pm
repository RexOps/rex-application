#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Configuration::Type::Base;

use Moose::Role;

requires qw(files);

has source => (
  is  => 'ro',
  isa => 'Str',
);

has parameter => (
  is  => 'ro',
  isa => 'HashRef | Undef',
  default => sub {{}},
);

1;
