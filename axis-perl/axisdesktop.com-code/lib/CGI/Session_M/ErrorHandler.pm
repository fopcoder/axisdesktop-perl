package CGI::Session_M::ErrorHandler;

use strict;

sub set_error {
    my $class   = shift;
    my $message = shift;
    $class = ref($class) || $class;
    no strict 'refs';
    ${ "$class\::errstr" } = sprintf($message || "", @_);
    return;
}

*error = \&errstr;
sub errstr {
    my $class = shift;
    $class = ref( $class ) || $class;

    no strict 'refs';
    return ${ "$class\::errstr" } || '';
}

1;

