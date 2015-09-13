package HellFire::FieldInterface;

use strict;

sub get_comment    {
    my $self = shift;
    my $val = shift;
    return $self->{ '_comments' }->{ $val }||'';
}

sub get_default_value	{
	my $self = shift;
	return $self->{_default_value}||'';
}

sub get_group_access {
	my $self = shift;
	return $self->{'_gaccess'};
}

sub get_source_field_id {
	my $self = shift;
	return $self->{'_source_field_id'} || 0;
}

sub get_source_group_id {
	my $self = shift;
	return $self->{'_source_group_id'} || 0;
}

sub get_source_id {
	my $self = shift;
	return $self->{'_source_id'} || 0;
}

sub get_suffix   {
    my $self = shift;
    my $val = shift;
    return $self->{ '_suffix' }->{ $val }||'';
}

sub get_type {
	my $self = shift;
	return $self->{'_type'} || '';
}

sub get_type_id {
	my $self = shift;
	return $self->{'_type_id'} || 0;
}

sub set_comment    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_comments' }->{ $id } = $val;
    return $self->{ '_comments' }->{ $id };
}

sub set_default_value	{
	my $self = shift;
	$self->{_default_value} = shift;
	return $self->{_default_value};
}

sub set_group_access {
	my $self = shift;
	$self->{'_gaccess'} = shift;
	return $self->{'_gaccess'};
}

sub set_source_field_id {
	my $self = shift;
	$self->{'_source_field_id'} = shift;
	return $self->{'_source_field_id'};
}

sub set_source_group_id {
	my $self = shift;
	$self->{'_source_group_id'} = shift;
	return $self->{'_source_group_id'};
}

sub set_source_id {
	my $self = shift;
	$self->{'_source_id'} = shift;
	return $self->{'_source_id'};
}

sub set_suffix    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_suffix' }->{ $id } = $val;
    return $self->{ '_suffix' }->{ $id };
}

sub set_type {
	my $self = shift;
	$self->{'_type'} = shift;
	return $self->{'_type'};
}

sub set_type_id {
	my $self = shift;
	$self->{'_type_id'} = shift;
	return $self->{'_type_id'};
}

sub to_template {
	my $self = shift;

	#require HellFire::DataType;
	#my $T = new HellFire::DataType( $self->dbh );
	#my $l = $T->get_languages();

	my $ret = {};
	foreach ( keys %$self ) {
		next if( $_ eq '_dbh' );
		next if( $_ eq '_guard' );
		if( $_ eq '_descriptions' ) {
			$ret->{description} = $self->get_description( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_aliases' ) {
			$ret->{alias} = $self->get_alias( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_titles' ) {
			next;
		}

		#if( $_ eq '_aliases' )	{
		#	my @items_aliases;
		#	foreach( @$l )	{
		#		push @items_aliases, {
		#			xtype => 'textfield',
		#			fieldLabel => $_->{alias},
		#			name => 'alias_'.$_->{id},
		#			autoHeight => 1,
		#			value => $self->get_alias( $_->{id} ),
		#		}
		#	}
		#	$ret->{item_aliases} = \@items_aliases;
		#	next;
		#}
		#elsif( $_ eq '_description' )	{
		#	my @items_descriptions;
		#	foreach( @$l )	{
		#		push @items_descriptions, {
		#			xtype => 'textfield',
		#			fieldLabel => $_->{alias},
		#			name => 'description_'.$_->{id},
		#			autoHeight => 1,
		#			value => $self->get_description( $_->{id} ),
		#		}
		#	}
		#	$ret->{item_descriptions} = \@items_descriptions;
		#	next;
		#}
		#elsif(  $_ eq '_action_list' )	{
		#	my @items_action_list;
		#	foreach( @{$self->{$_}} )	{
		#		push @items_action_list, {
		#			xtype => 'textfield',
		#			fieldLabel => $_->{name},
		#			labelStyle => 'width:300px',
		#			width => '100',
		#			disabled => 1,
		#			autoHeight => 1,
		#			value => $_->{name}
		#		}
		#	}
		#	$ret->{item_action_list} = \@items_action_list;
		#	next;
		#}
		next if( $_ eq '_flags' );

		my $k = $_;
		my $f;
		$k =~ s/^_//;
		$f = "get_$k";
		$ret->{$k} = $self->$f if( $self->can( $f ) );
	}

	return $ret;
}




1;

