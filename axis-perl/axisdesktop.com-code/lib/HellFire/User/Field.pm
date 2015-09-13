package HellFire::User::Field;

#####################################################
#	HellFire::User::Field	
#####################################################

use strict;
use base qw(HellFire::User);

sub new {
	my $class = shift;
	my $params = shift;
	my $self = $class->SUPER::new();

	$self->{ '_source_group_id' } = $params->{ 'source_group_id' };
	$self->{ '_source_category_id' } = $params->{ 'source_category_id' };
	$self->{ '_source_field_id' } = $params->{ 'source_field_id' };
	$self->{ '_type_id' } = $params->{ 'type_id' };
	$self->{ '_aliases' } = {};

	bless $self, $class;
	return $self;
}

sub get_source_group_id	{
	my $self = shift;

	return $self->{ '_source_group_id' };
}

sub set_source_group_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_source_group_id' } = $val;
	return $self->{ '_source_group_id' };
}

sub get_source_category_id	{
	my $self = shift;

	return $self->{ '_source_category_id' };
}

sub set_source_category_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_source_category_id' } = $val;
	return $self->{ '_source_category_id' };
}

sub get_source_field_id	{
	my $self = shift;

	return $self->{ '_source_field_id' };
}

sub set_source_field_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_source_field_id' } = $val;
	return $self->{ '_source_field_id' };
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

sub get_type_id	{
	my $self = shift;

	return $self->{ '_type_id' };
}

sub set_type_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_type_id' } = $val;
	return $self->{ '_type_id' };
}


return 1;
