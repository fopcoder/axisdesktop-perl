package HellFire::User::Value;

#####################################################
#	HellFire::User::Value	
#####################################################

use strict;

sub new {
	my $class = shift;
	my $params = shift;
	my $self = {};

	$self->{ '_id' } = $params->{ 'id' };
	$self->{ '_item_id' } = $params->{ 'item_id' };
	$self->{ '_parent_id' } = $params->{ 'parent_id' };
	$self->{ '_values' } = {};
	$self->{ '_flags' } = {};

	bless $self, $class;
	return $self;
}

sub get_id	{
	my $self = shift;

	return $self->{ '_id' };
}

sub set_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_id' } = $val;
	return $self->{ '_id' };
}

sub get_item_id	{
	my $self = shift;

	return $self->{ '_item_id' };
}

sub set_item_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_item_id' } = $val;
	return $self->{ '_item_id' };
}

sub get_parent_id	{
	my $self = shift;

	return $self->{ '_parent_id' };
}

sub set_parent_id	{
	my $self = shift;
	my $val = shift;

	$self->{ '_parent_id' } = $val;
	return $self->{ '_parent_id' };
}

sub get_value    {
        my $self = shift;

	my @a = values %{$self->{ '_values' }};
        return \@a;
}

sub set_value    {
        my $self = shift;
        my $val = shift;

	my @a = sort keys %{$self->{ '_values' }};
	my $i = pop @a;
	$i++;	
	$self->{ '_values' }->{ $i } = $val;

	@a = values %{$self->{ '_values' }};
        return \@a;
}

sub undef_value	{
	my $self = shift;
	$self->{ '_values' } = undef;
}


sub get_flag    {
	my $self = shift;
	my $val = shift;

	return $self->{ '_flags' }->{ uc $val };
}

sub set_flag    {
	my $self = shift;
	my $val = shift;

	$self->{ '_flags' }->{ uc $val } = 1;

	return $self->{ '_flags' }->{ uc $val };
}

sub to_string     {
        my $self = shift;

        my @arr = values %{$self->{'_values'}};
        return join(',', @arr);
}



return 1;
