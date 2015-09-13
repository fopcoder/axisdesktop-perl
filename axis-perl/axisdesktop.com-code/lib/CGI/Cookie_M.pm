package CGI::Cookie_M;

use strict;
use CGI::Util_M qw(rearrange unescape escape);
use overload '""' => \&as_string, 'cmp' => \&compare, 'fallback' => 1;

sub fetch {
  my $self = shift;
  my $raw_cookie = $ENV{HTTP_COOKIE} || $ENV{COOKIE};
  return () unless $raw_cookie;
  return $self->parse( $raw_cookie );
}

sub parse {
  my ( $self, $raw_cookie ) = @_;
  return () unless $raw_cookie;
  my %results;
  my @pairs = split "[;,] ?", $raw_cookie;
  for my $pair ( @pairs ) {
    $pair =~ s/^\s+//;
    $pair =~ s/\s+$//;
    my ( $key, $value ) = split( "=", $pair, 2 );
    next if !defined( $value );
    my @values = ();
    if ( $value ne '' ) {
      @values = map unescape( $_ ), split( /[&;]/, $value . '&dmy' );
      pop @values;
    }
    $key = unescape( $key );

    $results{$key} ||= $self->new( -name => $key, -value => \@values );
  }
  return wantarray ? %results : \%results;
}

sub raw_fetch {
  my $raw_cookie = $ENV{HTTP_COOKIE} || $ENV{COOKIE};
  return () unless $raw_cookie;
  my %results;
  my @pairs = split "; ?", $raw_cookie;
  for my $pair ( @pairs ) {
    $pair =~ s/^\s+|\s+$//;    # trim leading trailing whitespace
    my ( $key, $value ) = split "=", $pair;

    $value = defined $value ? $value : '';
    $results{$key} = $value;
  }
  return wantarray ? %results : \%results;
}

sub new {
  my ( $class, @params ) = @_;
  $class = ref( $class ) || $class;
  my ( $name, $value, $path, $domain, $secure, $expires, $httponly )
   = rearrange(
    [
      'NAME', [ 'VALUE', 'VALUES' ],
      'PATH',   'DOMAIN',
      'SECURE', 'EXPIRES',
      'HTTPONLY'
    ],
    @params
   );
  return undef unless defined $name and defined $value;
  my $self = {};
  bless $self, $class;
  $self->name( $name );
  $self->value( $value );
  $path ||= "/";
  $self->path( $path )         if defined $path;
  $self->domain( $domain )     if defined $domain;
  $self->secure( $secure )     if defined $secure;
  $self->expires( $expires )   if defined $expires;
  $self->httponly( $httponly ) if defined $httponly;
  return $self;
}

sub as_string {
  my $self = shift;
  return "" unless $self->name;
  my $name   = escape( $self->name );
  my $value  = join "&", map { escape( $_ ) } $self->value;
  my @cookie = ( "$name=$value" );
  push @cookie, "domain=" . $self->domain   if $self->domain;
  push @cookie, "path=" . $self->path       if $self->path;
  push @cookie, "expires=" . $self->expires if $self->expires;
  push @cookie, "secure"                    if $self->secure;
  push @cookie, "HttpOnly"                  if $self->httponly;
  return join "; ", @cookie;
}

sub compare {
  my ( $self, $value ) = @_;
  return "$self" cmp $value;
}

sub name {
  my ( $self, $name ) = @_;
  $self->{'name'} = $name if defined $name;
  return $self->{'name'};
}

sub value {
  my ( $self, $value ) = @_;
  if ( defined $value ) {
    my @values
     = ref $value eq 'ARRAY' ? @$value
     : ref $value eq 'HASH'  ? %$value
     :                         ( $value );
    $self->{'value'} = [@values];
  }
  return wantarray ? @{ $self->{'value'} } : $self->{'value'}->[0];
}

sub domain {
  my ( $self, $domain ) = @_;
  $self->{'domain'} = $domain if defined $domain;
  return $self->{'domain'};
}

sub secure {
  my ( $self, $secure ) = @_;
  $self->{'secure'} = $secure if defined $secure;
  return $self->{'secure'};
}

sub expires {
  my ( $self, $expires ) = @_;
  $self->{'expires'} = CGI::Util_M::expires( $expires, 'cookie' )
   if defined $expires;
  return $self->{'expires'};
}

sub path {
  my ( $self, $path ) = @_;
  $self->{'path'} = $path if defined $path;
  return $self->{'path'};
}

sub httponly {
  my ( $self, $httponly ) = @_;
  $self->{'httponly'} = $httponly if defined $httponly;
  return $self->{'httponly'};
}

1;

