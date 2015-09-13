package HellFire::User::Category;

#####################################################
#	HellFire::User::Category	
#####################################################

use strict;
use base qw(HellFire::User);

sub new {
	my $class = shift;
	my $params = shift;
	my $self = $class->SUPER::new();

	$self->{ '_index_left' } = $params->{ 'index_left' };
	$self->{ '_index_right' } = $params->{ 'index_right' };
	$self->{ '_aliases' } = {};

	bless $self, $class;
	return $self;
}

sub get_index_left	{
	my $self = shift;

	return $self->{ '_index_left' };
}

sub set_index_left	{
	my $self = shift;
	my $val = shift;

	$self->{ '_index_left' } = $val;
	return $self->{ '_index_left' };
}

sub get_index_right	{
	my $self = shift;

	return $self->{ '_index_right' };
}

sub set_index_right	{
	my $self = shift;
	my $val = shift;

	$self->{ '_index_right' } = $val;
	return $self->{ '_index_right' };
}

sub get_alias    {
        my $self = shift;
        my $val = shift;

        return $self->{ '_aliases' }->{ $val };
}

sub set_alias    {
        my $self = shift;
        my $id = shift;
        my $val = shift;

        $self->{ '_aliases' }->{ $id } = $val;
        return $self->{ '_aliases' }->{ $id };
}


return 1;
