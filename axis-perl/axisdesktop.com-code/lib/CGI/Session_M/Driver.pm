package CGI::Session_M::Driver;

use strict;

use CGI::Session_M::ErrorHandler;

@CGI::Session_M::Driver::ISA     = qw(CGI::Session_M::ErrorHandler);

sub new {
    my $class = shift;
    my $args  = shift || {};

    unless ( ref $args ) {
        die "$class->new(): Invalid argument type passed to driver";
    }

    # Set defaults.

    if (! $args->{TableName}) {
        $args->{TableName} = 'sessions';
    }

    if (! $args->{IdColName}) {
        $args->{IdColName} = 'id';
    }

    if (! $args->{DataColName}) {
        $args->{DataColName} = 'a_session';
    }

    # perform a shallow copy of $args, to prevent modification
    my $self = bless ({%$args}, $class);
    return $self if $self->init();
    return $self->set_error( "%s->init() returned false", $class);
}

sub init { 1 }

sub retrieve {
    die "retrieve(): " . ref($_[0]) . " failed to implement this method!";
}

sub store {
    die "store(): " . ref($_[0]) . " failed to implement this method!";
}

sub remove {
    die "remove(): " . ref($_[0]) . " failed to implement this method!";
}

sub traverse {
    die "traverse(): " . ref($_[0]) . " failed to implement this method!";
}

sub dump {
    require Data::Dumper;
    my $d = Data::Dumper->new([$_[0]], [ref $_[0]]);
    return $d->Dump;
}


1;


