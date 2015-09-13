package HellFire::Configuration;

use strict;
use base qw(HellFire);

sub new {
	my $class = shift;
	my $params = shift;
	my $self = $class->SUPER::new();

	bless $self, $class;
	$self->set_name( $self->{ '_name' } );
	return $self;
}

sub set_ordering    {
	my $self = shift;
	$self->{ '_ordering' } = shift;
	return $self->{ '_ordering' };
}

sub get_ordering    {
	my $self = shift;
	return $self->{ '_ordering' }||0;
}

sub set_inserted    {
	my $self = shift;
	$self->{ '_inserted' } = shift;
	return $self->{ '_inserted' };
}

sub get_inserted    {
	my $self = shift;
	return $self->{ '_inserted' }||'';
}

sub set_type    {
	my $self = shift;
	$self->{ '_type' } = shift;
	return $self->{ '_type' };
}

sub get_type    {
	my $self = shift;
	return $self->{ '_type' }||'';
}

sub set_module    {
	my $self = shift;
	$self->{ '_module' } = shift;
	return $self->{ '_module' };
}

sub get_module    {
	my $self = shift;
	return $self->{ '_module' }||'';
}


sub get_alias    {
    my $self = shift;
    my $val = shift;
    return $self->{ '_aliases' }->{ $val }||'';
}

sub set_alias    {
    my $self = shift;
    my $id = shift;
    my $val = shift;
    $self->{ '_aliases' }->{ $id } = $val;
    return $self->{ '_aliases' }->{ $id };
}

sub to_template {
	my $self = shift;
	
	require HellFire::DataType;
	my $T = new HellFire::DataType( $self->dbh );
	my $l = $T->get_languages();
	
	my $ret = {};
	foreach ( keys %$self )	{
		next if( $_ eq '_dbh' );
		next if( $_ eq '_guard' );
		if( $_ eq '_aliases' )	{
			my @items_aliases;
			foreach( @$l )	{
				push @items_aliases, {
					xtype => 'textfield',
					fieldLabel => $_->{alias},
					name => 'alias_'.$_->{id},
					autoHeight => 1,
					value => $self->get_alias( $_->{id} ),
				}
			}
			$ret->{item_aliases} = \@items_aliases;
			next;
		}
		elsif( $_ eq '_description' )	{
			my @items_descriptions;
			foreach( @$l )	{
				push @items_descriptions, {
					xtype => 'textfield',
					fieldLabel => $_->{alias},
					name => 'description_'.$_->{id},
					autoHeight => 1,
					value => $self->get_description( $_->{id} ),
				}
			}
			$ret->{item_descriptions} = \@items_descriptions;
			next;
		}
		elsif(  $_ eq '_action_list' )	{
			my @items_action_list;
			foreach( @{$self->{$_}} )	{
				push @items_action_list, {
					xtype => 'textfield',
					fieldLabel => $_->{name},
					labelStyle => 'width:300px',
					width => '100',
					disabled => 1,
					autoHeight => 1,
					value => $_->{name}
				}
			}
			$ret->{item_action_list} = \@items_action_list;
			next;
		}
		next if( $_ eq '_flags' );
		
		my $k = $_;
		my $f;
		$k =~ s/^_//;
		$f = "get_$k";
		$ret->{$k} = $self->$f;
	}
	
	return $ret;
}


return 1;
