package HellFire::File;

use strict;
use base qw(HellFire);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();

    $self->{ '_flags' } = {};

    bless $self, $class;
    return $self;
}

sub get_tmp	{
    my $self = shift;
    return $self->{ '_tmp' };
}

sub set_tmp	{
    my $self = shift;
    $self->{ '_tmp' } = shift;
    return $self->{ '_tmp' };
}

sub get_item_id	{
    my $self = shift;
    return $self->{ '_item_id' }||0;
}

sub set_item_id	{
    my $self = shift;
    $self->{ '_item_id' } = shift;
    return $self->{ '_item_id' };
}

sub get_type	{
    my $self = shift;
    return $self->{ '_type' };
}

sub set_type	{
    my $self = shift;
    $self->{ '_type' } = shift ;
    return $self->{ '_type' };
}

sub get_prefix	{
    my $self = shift;
    return $self->{ '_prefix' };
}

sub set_prefix	{
    my $self = shift;
    $self->{ '_prefix' } = shift ;
    return $self->{ '_prefix' };
}

sub get_type_id	{
    my $self = shift;
    return $self->{ '_type_id' };
}

sub set_type_id	{
    my $self = shift;
    $self->{ '_type_id' } = shift;
    return $self->{ '_type_id' };
}

sub get_path	{
    my $self = shift;
    return $self->{ '_path' };
}

sub set_path	{
    my $self = shift;
    $self->{ '_path' } = shift;
    return $self->{ '_path' };
}

sub get_url	{
    my $self = shift;
    return $self->{ '_url' };
}

sub set_url	{
    my $self = shift;
    $self->{ '_url' } = shift;
    return $self->{ '_url' };
}

sub format_size	{
    my $self = shift;
    my $val = shift;

    if( $val > 1000 && $val <= 1000000 )        {
	$val = sprintf("%.2f", $val/1024 );
	$val .= ' k';
    }
    elsif( $val > 1000000 && $val <= 1000000000 )       {
	$val = sprintf("%.2f", $val/1024/1024 );
	$val .= ' M';
    }
    elsif( $val > 1000000000 )        {
	$val = sprintf("%.2f", $val/1024/1024/1024 );
	$val .= ' G';
    }
    
    return $val;
}

sub get_ordering	{
	my $self = shift;
	return $self->{_ordering}||0;
}

sub set_ordering	{
	my $self = shift;
	$self->{_ordering} = shift;
	return $self->{_ordering};
}


sub get_inserted	{
	my $self = shift;
	return $self->{_inserted}||'';
}

sub set_inserted	{
	my $self = shift;
	$self->{_inserted} = shift;
	return $self->{_inserted};
}

sub get_user_id	{
	my $self = shift;
	return $self->{_user_id}||0;
}

sub set_user_id	{
	my $self = shift;
	$self->{_user_id} = shift;
	return $self->{_user_id};
}

return 1;
