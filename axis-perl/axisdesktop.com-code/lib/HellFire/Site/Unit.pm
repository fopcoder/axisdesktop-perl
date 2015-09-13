package HellFire::Site::Unit;

use strict;
use base qw(HellFire::Site);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();

    $self->{ '_aliases' } = {};
    $self->{ '_contents' } = {};
    $self->{ '_keywords' } = {};
    $self->{ '_descriptions' } = {};
    $self->{ '_titles' } = {};

    bless $self, $class;
    return $self;
}

sub get_keywords    {
    my $self = shift;
    my $val = shift;

    return $self->{ '_keywords' }->{ $val }||'';
}

sub set_keywords    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_keywords' }->{ $id } = $val;
    return $self->{ '_keywords' }->{ $id };
}

sub get_description    {
    my $self = shift;
    my $val = shift;

    return $self->{ '_descriptions' }->{ $val }||'';
}

sub set_description    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_descriptions' }->{ $id } = $val;
    return $self->{ '_descriptions' }->{ $id };
}

sub get_title    {
    my $self = shift;
    my $val = shift;
    return $self->{ '_titles' }->{ $val }||'';
}

sub set_title    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_titles' }->{ $id } = $val;
    return $self->{ '_titles' }->{ $id };
}

sub get_handler_id      {
    my $self = shift;
    return $self->{ '_handler_id' }||0;
}

sub set_handler_id      {
    my $self = shift;
    my $val = shift||0;

    $self->{ '_handler_id' } = $val;
    return $self->{ '_handler_id' };
}

sub get_path    {
    my $self = shift;
    return $self->{ '_path' }||'';
}

sub set_path    {
    my $self = shift;
    $self->{ '_path' } = shift;
    return $self->{ '_path' };
}

sub get_updated   {
    my $self = shift;
    return $self->{ '_updated' }||'';
}

sub set_updated   {
    my $self = shift;
    $self->{ '_updated' } = shift;
    return $self->{ '_updated' };
}

sub is_system   {
    my $self = shift;
    return $self->get_flag('SYSTEM');
}

sub is_locked   {
    my $self = shift;
    return $self->get_flag('LOCKED');
}

sub is_cache    {
    my $self = shift;
    return $self->get_flag('CACHE');
}


return 1;
