package HellFire::User::Item;

use strict;
use base qw(HellFire::User);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();

    $self->{ '_aliases' } = {};

    bless $self, $class;
    return $self;
}


sub get_alias    {
    my $self = shift;
    return $self->{ '_alias' };
}

sub set_alias    {
    my $self = shift;
    my $val = shift;

    $self->{ '_alias' } = $val;
    return $self->{ '_alias' };
}


sub get_email    {
    my $self = shift;
    return $self->{ '_email' };
}

sub set_email    {
    my $self = shift;
    my $val = shift;

    $self->{ '_email' } = $val;
    return $self->{ '_email' };
}

sub get_password    {
    my $self = shift;
    return $self->{ '_password' };
}

sub set_password    {
    my $self = shift;
    my $val = shift;

    $self->{ '_password' } = $val;
    return $self->{ '_pasword' };
}

return 1;
