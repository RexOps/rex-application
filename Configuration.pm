# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Application::Configuration;

use strict;
use warnings;

use Carp;

sub get {
  my ($class, $type, @params) = @_;

  if($type !~ m/::/) {
    $type = "Application::Configuration::Type::\u$type";
  }

  eval "use $type";
  if($@) {
    confess "Error loading configuration class: $type.\nError: $@\n";
  }

  return $type->new(@params);
}

1;
