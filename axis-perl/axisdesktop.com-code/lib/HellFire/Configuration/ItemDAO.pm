package HellFire::Configuration::ItemDAO;

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
    $self->{ '_aliases' } = {};
    $self->{ '_description' } = {};

	bless $self, $class;
	return $self;
}

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	if( $self->guard->is_administrator() || $self->get_action( 'configuration_item_view' ) ) {
		my $query = 'select * from configuration where id = ?';
		my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
		$self->flags_to_hash( $h );

		foreach my $i ( keys %$h ) {
			if( $i =~ /FLAG_(\w+)/ ) {
				$self->set_flag( $1 );
			}
			else {
				my $sf = "set_$i";
				$self->$sf( $h->{$i}, $params );
			}
		}

		my $sth;
		if( $params->{lang_id} ) {
			$query = 'select lang_id, alias, description from configuration_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $self->guard->get_lang_id() );
		}
		else {
			$query = 'select lang_id, alias, description from configuration_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_description( $h->{'lang_id'}, $h->{'description'} );
		}
        
        if( $params->{with_action_list} )   {
            $self->{_action_list} = $self->get_action_list( $self->get_id() );
        }

		return $self->get_id();
	}
    
	return undef;
}

sub save {
	my $self = shift;

	if( $self->get_id() ) {
		$self->update();
	}
	else {
		$self->set_id( $self->add() );
	}
}

sub add {
    my $self = shift;
}

sub update	{
	my $self = shift;

    require HellFire::DataType;
	$self->validate_name();

    my $access = $self->get_action( 'configuration_item_update' ) || $self->guard->is_administrator();

	if( $self->get_id() && $access )	{
		my $flags = $self->flags_to_string();
		my $query = 'update configuration set ordering = ?, module = ?, flags = ? where id = ? ';
		$self->dbh->do( $query, undef, $self->get_ordering(), $self->get_module(), $flags, $self->get_id() );	

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		$query = 'delete from configuration_aliases where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
        foreach( @$l )  {
			my $query = 'insert into configuration_aliases(parent_id,lang_id,alias, description) values(?,?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ), $self->get_description( $_->{id} ) );
		}
        
        my $code = $self->get_json_access();
		foreach my $j ( @$code ) {
            if( $j->{value} eq 'false' || $j->{value} == 0 ) {
                $self->dbh->do( 'delete from configuration_access where parent_id = ? and group_id = ? and action_id = ?', undef, $self->get_id(), $j->{group_id}, $j->{action_id} );
            }
            if( $j->{value} eq 'true' || $j->{value} > 0 ) {
                $self->dbh->do( 'insert ignore into configuration_access(parent_id,group_id,action_id) values(?,?,?)', undef, $self->get_id(), $j->{group_id}, $j->{action_id}  );
            }
		}
        
		return 1;	
	} 

	return undef;
}

sub get_grid {
	my $self   = shift;
	my $params = shift;

    my @arr;
    #if( $self->guard->is_administrator() || $self->get_action( 'configuration_item_list' ) ) {
        my $type = join(',', map{ $self->dbh->quote($_) } split /,/, $params->{type} );
        my $lid = $self->guard->get_lang_id() || 0;
    
        my @all_collection;
        my $query = 'select id from configuration';
        if( $type )	{
            $query .= ' where type in(' . $type . ') ';
        }
    
        my $ref = $self->dbh->selectall_arrayref( $query );
        foreach ( @$ref ) {
            push @all_collection, $_->[0];
        }
    
        ${ $params->{count_all} } = scalar @all_collection;
    
        undef $ref;
        
        my @order_collection;
    
        if( $params->{order_id} eq 'id' || $params->{order_id} eq 'name' || $params->{order_id} eq 'inserted' || $params->{order_id} eq 'ordering' ) {
            $query = "select id from configuration  ";
            if( $type )	{
                $query .= " where type in( $type ) ";
            }
            $query .= " order by  $params->{order_id} $params->{order_direction}";
            my $ref = $self->dbh->selectall_arrayref( $query );
    
            foreach ( @$ref ) {
                push @order_collection, $_->[0];
            }
        }
        elsif( $params->{order_id} eq 'alias' ) {
            $query = "select i.id from configuration i inner join configuration_aliases a on a.parent_id = i.id and a.lang_id = $lid  ";
            if( $type )	{
                $query .= " where type in( $type ) ";
            }
            $query .= "	order by a.alias $params->{order_direction}";
            my $ref = $self->dbh->selectall_arrayref( $query );
    
            foreach ( @$ref ) {
                push @order_collection, $_->[0];
            }
        }
        else {
            $query = "select id from configuration";
            if( $type )	{
                $query .= " where type in( $type ) ";
            }
            $query .= " order by  ordering desc";
            my $ref = $self->dbh->selectall_arrayref( $query );
    
            foreach ( @$ref ) {
                push @order_collection, $_->[0];
            }
        }
    
        my %temp = ();
        @temp{@all_collection} = ();
        foreach ( @order_collection ) {
            delete $temp{$_};
        }
    
        my @diff_collection = keys %temp;
        undef %temp;
    
        @all_collection = undef;
        if( lc $params->{order_direction} eq 'desc' ) {
            @all_collection = @order_collection;
            push @all_collection, @diff_collection;
        }
        else {
            @all_collection = @diff_collection;
            push @all_collection, @order_collection;
        }
    
        my $uselect2 = 'select i.name, if(isnull(a.alias),i.name,a.alias) alias ';
        $uselect2 .=  ', inserted, year(inserted) inserted_year, day(inserted) inserted_day, month(inserted) inserted_month ' if( $params->{with_inserted} );
        $uselect2 .=  ', ordering ' if( $params->{with_ordering} );
        $uselect2 .=  ', version ' if( $params->{with_version} );
        $uselect2 .= " from configuration i left join configuration_aliases a 
                    on a.parent_id = i.id and a.lang_id = $lid
                    where i.id = \@_id ";
    
        my $sth13 = $self->dbh->prepare( $uselect2 );
    
        my $to = $params->{offset} + $params->{limit} > scalar @all_collection ? scalar @all_collection : $params->{offset} + $params->{limit};
        
        for( $params->{offset} .. $to - 1 ) {
            my @val;
            $self->dbh->do( 'set @_id = ?', undef, $all_collection[$_] );
            $sth13->execute();
    
            my $item = $sth13->fetchrow_hashref();
            $item->{alias} =~ s/\&/\&amp;/g;
    
            push @arr, {
                %$item,
                id => $all_collection[$_]
            };
        }
    #}
	return \@arr;
    
}

sub get_version_date    {
    my $self = shift;
    return $self->{_version_date}||'';
}

sub set_version_date    {
    my $self = shift;
    $self->{_version_date} = shift;
    return $self->{_version_date};
}

sub get_version    {
    my $self = shift;
    return $self->{_version}||'';
}

sub set_version    {
    my $self = shift;
    $self->{_version} = shift;
    return $self->{_version};
}

sub get_description {
	my $self = shift;
	my $val  = shift;

	return $self->{'_description'}->{$val} || '';
}

sub set_description {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_description'}->{$id} = $val;
	return $self->{'_description'}->{$id};
}

sub get_action_list {
    my $self = shift;
    my $id = shift || 0;

    my @arr;
    
    if( $self->guard->is_administrator() || $self->get_action( 'configuration_action_list' ) ) {
        my $query = 'select a.* from configuration_actions a';
        
        if( $id ) {
            $query .= ' inner join configuration c on c.id = a.parent_id where c.id = ? order by a.name';
            my $sth = $self->dbh->prepare( $query );
            $sth->execute( $id );
            while ( my $h = $sth->fetchrow_hashref() ) {
                push @arr, $h;
            }
        }
        else {
            $query .= ' order by a.name';
            my $sth = $self->dbh->prepare( $query );
            $sth->execute();
            while ( my $h = $sth->fetchrow_hashref() ) {
                push @arr, $h;
            }
        }
    }

    return \@arr;
}

sub find    {
    my $self = shift;
    my $name = shift||'';

    my $id = $self->dbh->selectrow_array('select id from configuration where name = ?', undef, $name );
    return $id;
}

sub get_access_list {
    my $self = shift;
    
    require HellFire::User::CategoryDAO;
    my $UC  = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	my $grp = $UC->get_all_siblings();
	$UC->set_name( 'guest' );
	$UC->set_id( 0 );
	push @$grp, $UC;
    
    my $I = new HellFire::Configuration::ItemDAO( $self->dbh, $self->guard );
	my $act = $I->get_action_list( $I->find( 'configuration_lib' ) );
    
    my @arr;
	foreach my $g ( @$grp ) {
		next if( $g->get_name() eq 'administrator' );

		foreach my $a ( @$act ) {
            my $query = 'select 1 from configuration_access
                        where parent_id = ? and group_id = ? and action_id = ?';
            my $h = {
                group => $g->get_name(),
                group_id => $g->get_id(),
                action => $a->{name},
                action_id => $a->{id},
                value => $self->dbh->selectrow_array( $query, undef, $self->get_id(), $g->get_id(), $a->{id}  )||0
            };
			
       		push @arr, $h;
		}
	}
    return \@arr;
}

sub set_json_access {
	my $self = shift;
	$self->{'_gaccess'} = shift;
	return $self->{'_gaccess'};
}

sub get_json_access {
	my $self = shift;
	return $self->{'_gaccess'};
}

sub validate_name	{
    my $self = shift;

	my $n = $self->get_name();
    unless( $self->is_unique( $n ) )   {
        $n .= '_' if( $n );
        $self->set_name( $n.int(rand(100000000) ) );
    }

    return $self->get_name();
}

sub is_unique {
    my $self = shift;
    my $name = shift || '';

    if( length $name > 0 ) {
        my $query = 'select id from configuration where name = ? ';
        my $id = $self->dbh->selectrow_array( $query, undef, $name );

        if( $id > 0 && $self->get_id() != $id ) {
            return undef;
        }

        return 1;
    }
    return undef;
}

sub get_action {
	my $self = shift;
	my $val = shift || '';

	my $grp;

	if( $self->guard->is_cgi ) {
		$grp = join( ',', @{ $self->guard->get_groups() } );
	}
	else {
		$grp = join( ',', @{ $self->guard->get_groups() }, 0 );
	}

	my $query = 'select count(*) from configuration_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

return 1;