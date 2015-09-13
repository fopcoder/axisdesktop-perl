package HellFire::Configuration::CategoryDAO;

use strict;
use base qw(HellFire::Configuration);

sub new {
	my $class = shift;
	my $dbh = shift;
	my $G = shift;
	my $params = shift;

	my $self = $class->SUPER::new();
	$self->{ '_dbh' } = $dbh;
	$self->{ '_guard' } = $G;

	bless $self, $class;
	return $self;
}

sub load    {
	my $self = shift;
	my $id = shift || 0;

	my $query = 'select * from configuration where id = ?';
	my $h = $self->{ '_dbh' }->selectrow_hashref( $query, undef, $id );
	$self->flags_to_hash( $h );

	foreach my $i ( keys %$h )	{
		if( $i =~ /FLAG_(\w+)/ )	{
			$self->set_flag( $1 );
		}
		else	{
			my $e = '$self->set_'.$i.'("'.$h->{$i}.'")';
			eval($e);
		}
	} 

	$query = 'select * from configuration_aliases where parent_id = ? ';
	my $sth = $self->{ '_dbh' }->prepare( $query );
	$sth->execute( $id ); 
	
	while( my $h = $sth->fetchrow_hashref() )	{
		$self->set_alias( $h->{ 'lang_id' }, $h->{ 'alias' } );	
	}

	return 1;
}

sub validate_name	{
    my $self = shift;

	my $n = $self->get_name();
    unless( $self->is_unique( $n ) )   {
	$self->set_name( $n.'_'.int(rand(100000000) ) );
    }

    return $self->get_name();
}

sub add	{
	my $self = shift;
	my $dbh = $self->dbh;

	$self->validate_name();

	unless( $self->get_ordering() ) {
		my $ord = $dbh->selectrow_array('select max(ordering)+10 from configuration' );
		$self->set_ordering( $ord );
	}

	if( $self->get_name() )	{
		my $flags = $self->flags_to_string();
		my $query = 'insert ignore into configuration( name, ordering, flags, inserted )
			values(?,?,?, now())';
		$dbh->do( $query, undef, $self->get_name(), $self->get_ordering(), $flags );	
		my $id = $self->{_dbh}->last_insert_id(undef,undef,undef,undef);
		$self->set_id( $id );

		my $T = new HellFire::DataType( $dbh );
		my $l = $T->get_languages();
          	foreach( @$l )  {
			my $query = 'insert into configuration_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$dbh->do( $query, undef, $id, $_->{id}, $self->get_alias($_->{id})) if( $self->get_alias($_->{id}) );
		}
		return $id;	
	} 

	return undef;
}

sub update	{
	my $self = shift;
	my $dbh = $self->dbh;

	$self->validate_name();

	if( $self->get_name() && $self->get_id() )	{
		my $flags = $self->flags_to_string();
		my $query = 'update configuration set ordering = ?, flags = ? where id = ? ';
		$dbh->do( $query, undef, $self->get_ordering(), $flags, $self->get_id() );	

		my $T = new HellFire::DataType( $dbh );
		my $l = $T->get_languages();
		$query = 'delete from configuration_aliases where parent_id = ?';
		$dbh->do( $query, undef, $self->get_id() );
          	foreach( @$l )  {
			my $query = 'insert into configuration_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias($_->{id})) if( $self->get_alias($_->{id}) );
		}
		return 1;	
	} 

	return undef;
}

sub get_store_modules	{
	my $self = shift;

	my $query = 'select id from configuration
					where find_in_set("DELETED", flags) = 0 and type = "STORE"
					order by ordering';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute();

	my @obj;
    while( my @arr = $sth->fetchrow_array() )    {
		my $C = new HellFire::Configuration::CategoryDAO( $self->dbh );
		$C->load( $arr[0] );
		push @obj, $C;
	}
	
	return \@obj;
}

sub get_tool_modules	{
	my $self = shift;

	my $query = 'select id from configuration
					where find_in_set("DELETED", flags) = 0 and type = "TOOL"
					order by ordering';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute();

	my @obj;
    while( my @arr = $sth->fetchrow_array() )    {
		my $C = new HellFire::Configuration::CategoryDAO( $self->dbh );
		$C->load( $arr[0] );
		push @obj, $C;
	}
	
	return \@obj;
}

# deprecated
sub get_all_siblings	{
	my $self = shift;

	my $query = 'select id from configuration where find_in_set("DELETED", flags) = 0 and type IN( "STORE","TOOL") order by ordering';
	my $sth = $self->{ '_dbh' }->prepare( $query );
	$sth->execute();

	my @obj;
        while( my @arr = $sth->fetchrow_array() )    {
		my $C = new HellFire::Configuration::CategoryDAO( $self->{ '_dbh' } );
		$C->load( $arr[0] );
		push @obj, $C;
	}
	
	return \@obj;
}


sub is_unique	{
    my $self = shift;
    my $name = shift || '';

    if( length $name > 0 )	{
	my $query = 'select id from configuration where name = ? ';
	my $id = $self->{_dbh}->selectrow_array( $query, undef, $name );

	if( $id > 0 && $self->get_id() != $id )	{
	    return undef;
	}

	return 1;
    }
    return undef;
}



sub delete      {
	my $self = shift;
	my $params = shift;

	if( $self->get_id() )    {
		my $query = 'update configuration set flags = concat_ws(",",flags,"DELETED"), name = concat("_del_",name) where id = ?';
		$self->{_dbh}->do( $query, undef, $self->get_id() );

		return 1;
	}
	else    {
		warn('delete_item: item not found');
	}
}

sub get_actions	{
    my $self = shift;
    my $id = shift||0;

    my @arr;
    my $query = 'select a.* from configuration_actions a';

    if( $id )	{
	$query .= ' inner join configuration c on c.id = a.parent_id where c.id = ?';
	my $sth = $self->{_dbh}->prepare( $query );
	$sth->execute( $id );
	while( my $h = $sth->fetchrow_hashref() )   {
	    push @arr, $h;
	}
    }
    else    {
	my $sth = $self->{_dbh}->prepare( $query );
	$sth->execute();
	while( my $h = $sth->fetchrow_hashref() )   {
	    push @arr, $h;
	}
    }

    return \@arr;
}

sub find    {
    my $self = shift;
    my $name = shift||'';

    my $id = $self->{_dbh}->selectrow_array('select id from configuration where name = ?', undef, $name );
    return $id;
}

sub get_handlers        {
    my $self = shift;

    my $query = 'select id from configuration where type = "HANDLER" and find_in_set("DELETED",flags) = 0 order by name';
    my $sth = $self->{_dbh}->prepare( $query );
    $sth->execute();
    my @arr;
    while( my @w = $sth->fetchrow_array() ) {
        my $H = new HellFire::Configuration::CategoryDAO( $self->dbh, $self->guard );
        $H->load( $w[0] );
        push @arr, $H;
    }

    return \@arr;
}

return 1;
