package Application::Download::URL;

use overload '""' => sub {
  my ($self) = @_;
  return $self->to_s;
};

use Moose;

has proto => ( is => 'ro', isa => 'Str' );
has host  => ( is => 'ro', isa => 'Str' );
has port  => ( is => 'ro', isa => 'Int', default => sub { 80 } );
has path  => ( is => 'ro', isa => 'Str' );
has user => ( is => 'ro', isa => 'Str' );
has password => ( is => 'ro', isa => 'Str' );

sub has_auth {
  my $self = shift;
  $self->user && $self->password;
}

sub to_s_without_auth {
  my $self = shift;

  my $port = $self->port;
  $port = 443 if($self->proto eq "https");

  return
      $self->proto . "://"
    . $self->host
    . ($port == 80 && $self->proto eq "http" ? "" : ( $port == 443 && $self->proto eq "https" ? "" : ":$port" ))
    . $self->path;
}

sub to_s {
  my $self = shift;

  my $port = $self->port;
  $port = 443 if($self->proto eq "https");

  return
      $self->proto . "://"
    . ( $self->has_auth ? $self->user . ":" . $self->password . '@' : "" )
    . $self->host
    . ($port == 80 && $self->proto eq "http" ? "" : ( $port == 443 && $self->proto eq "https" ? "" : ":$port" ))
    . $self->path;
}


1;
