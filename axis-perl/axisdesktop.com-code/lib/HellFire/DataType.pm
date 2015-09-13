package HellFire::DataType;

use strict;

sub new {
    my $class = shift; 
    my $self; 

    $self->{_dbh} = shift;

    bless $self,$class;
    return $self;
}

sub dbh	{
	my $self = shift;
	return $self->{_dbh};
}

sub get_type_alias	{
    my $self = shift;
    my $id = shift;

    my $ret;
    if( $id )	{
	my $query = 'select if(length(a.alias),a.alias,i.name) alias
	    from settings_items i inner join settings_categories c on c.id = i.parent_id
	    left join settings_item_aliases a on a.parent_id = i.id and a.lang_id = ?
	    where c.name = "data_types" and find_in_set("DELETED",i.flags) = 0 and i.id = ? order by i.ordering';
	$ret = $self->dbh->selectrow_array( $query, undef, 1, $id ) ;
    }

    return $ret;
}

sub get_type_name	{
    my $self = shift;
    my $id = shift;

    my $ret;
    if( $id )	{
	my $query = 'select i.name  
	    from settings_items i inner join settings_categories c on c.id = i.parent_id
	    where c.name = "data_types" and find_in_set("DELETED",i.flags) = 0 and i.id = ? order by i.ordering';
	$ret = $self->dbh->selectrow_array( $query, undef, $id );
    }

    return $ret;
}

sub get_data_types   {
    my $self = shift;
    my $params = shift;

    my $query = 'select i.id, i.name, if(length(a.alias),a.alias,i.name) alias
	    from settings_items i inner join settings_categories c on c.id = i.parent_id
	    left join settings_item_aliases a on a.parent_id = i.id and a.lang_id = ?
	    where c.name = "data_types" and find_in_set("DELETED",i.flags) = 0 order by i.ordering';
    my $sth = $self->dbh->prepare($query);
    $sth->execute( $params->{lang_id}||1 );
    my @arr;
    while( my $hash = $sth->fetchrow_hashref() )    {
	$hash->{'selected'} = 'selected' if( $params->{'selected'} == $hash->{id} );
	push @arr, $hash;
    }

    return \@arr;
}

sub get_languages   {
    my $self = shift;
    my $params = shift;
    
    my $query = 'select i.id, i.name, if(length(a.alias),a.alias,i.name) alias 
	    from settings_items i inner join settings_categories c on c.id = i.parent_id
	    left join settings_item_aliases a on a.parent_id = i.id and a.lang_id = ?
	    where c.name = "languages" and find_in_set("DELETED",i.flags) = 0 and find_in_set("HIDDEN",i.flags) = 0 order by i.ordering';
    my $sth = $self->dbh->prepare($query);
    $sth->execute( $params->{lang_id}||1 );
    my @arr;
    while( my $hash = $sth->fetchrow_hashref() )    {
	$hash->{'selected'} = 'selected' if( $params->{'selected'} == $hash->{id} );
	push @arr, $hash;
    }

    return \@arr;
}

sub find_lang	{
    my $self = shift;
	my $lang = shift||'';

	my $query = 'select i.id 
            from settings_items i inner join settings_categories c on c.id = i.parent_id
            where c.name = "languages" and find_in_set("DELETED",i.flags) = 0 and i.name = ?';
	my $id = $self->dbh->selectrow_array( $query,undef, $lang );

	return $id||0;
}

sub find	{
    my $self = shift;
    return $self->find_type( shift||'' );
}

sub find_type	{
    my $self = shift;
	my $lang = shift||'';

	my $query = 'select i.id 
            from settings_items i inner join settings_categories c on c.id = i.parent_id
            where c.name = "data_types" and find_in_set("DELETED",i.flags) = 0 and i.name = ?';
	my $id = $self->dbh->selectrow_array( $query,undef, $lang );

	return $id||0;
}


sub find_file_type	{
    my $self = shift;
	my $val = shift||'';

	my $query = 'select i.id 
            from settings_items i inner join settings_categories c on c.id = i.parent_id
            where c.name = "file_types" and find_in_set("DELETED",i.flags) = 0 and i.name = ?';
			
	return $self->dbh->selectrow_array( $query, undef, $val ) || 0 ;
}

return 1;
