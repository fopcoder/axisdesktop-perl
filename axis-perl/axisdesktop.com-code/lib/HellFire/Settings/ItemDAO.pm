package HellFire::Settings::ItemDAO;

use strict;
use base qw(HellFire::Settings);
use HellFire::DataBase;

sub new {
    my $class = shift;
    my $dbh = shift;
    my $G = shift;

    my $self = $class->SUPER::new();
    $self->{ '_dbh' } = $dbh;
    $self->{ '_guard' } = $G;

    bless $self, $class;
    return $self;
}

sub validate_name	{
    my $self = shift;

    my $n = $self->get_name();
    unless( $self->is_unique( $n ) )   {
	$self->set_name( $n.'_'.int(rand(100000000) ) );
    }

    return $self->get_name();
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

sub load    {
    my $self = shift;
    my $id = shift || $self->get_id() || 0;
    my $params = shift;

    $self->set_id( $id );

    if( $self->guard->is_administrator() || $self->get_action('settings_item_view') )  {
	my $query = 'select * from settings_items where id = ?';

	my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
    $self->flags_to_hash( $h );

	foreach my $i ( keys %$h )	{
	    if( $i =~ /FLAG_(\w+)/ )	{
		$self->set_flag( $1 );
	    }
	    else	{
		my $sf = "set_$i";
                $self->$sf( $h->{$i} );
	    }
	} 

	my $sth;
	if( $params->{ lang_id} )	{
		$query = 'select lang_id, alias from settings_item_aliases where parent_id = ? and lang_id = ?';
		$sth = $self->dbh->prepare( $query );
		$sth->execute( $id, $self->guard->get_lang_id() ); 
	}
	else	{
		$query = 'select lang_id, alias from settings_item_aliases where parent_id = ? ';
		$sth = $self->dbh->prepare( $query );
		$sth->execute( $id ); 
	}

	while( my $h = $sth->fetchrow_hashref() )	{
	    $self->set_alias( $h->{ 'lang_id' }, $h->{ 'alias' } );	
	}

	return $self->get_id();
    }
    return undef;
}

sub save	{
    my $self = shift;

    if( $self->get_id() )   {
	$self->update();
    }
    else    {
	$self->set_id( $self->add() );
    }
}

sub add	{
    my $self = shift;

    require HellFire::Settings::CategoryDAO;
    my $C = new HellFire::Settings::CategoryDAO( $self->dbh, $self->guard );
    $C->load( $self->get_parent_id() );

    unless( $self->get_ordering() ) {
	my $ord = $self->dbh->selectrow_array('select max(ordering) from settings_items where parent_id = ?', undef, $self->get_parent_id() );
	$ord += 10;
	$self->set_ordering( $ord );
    }

    my $access = $C->get_action('settings_item_add') || $self->guard->is_administrator();

    if( $self->get_parent_id() && $access )    {
	my $query = 'insert into settings_items(parent_id, name, ordering, inserted, flags, user_id, updated) 
			values(?,?,?, now(),?,?,now())';
	$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), '', $self->guard->get_user_id() ) ;

	my $id = $self->dbh->last_insert_id(undef,undef,undef,undef);
	$self->set_access( $id );

	foreach( keys %{$self->{_aliases}} )	{
	    $query = 'insert into settings_item_aliases( alias, lang_id, parent_id) values( ?, ?, ?)';
	    $self->dbh->do( $query, undef, $self->get_alias($_)||'', $_, $id );
	}   

	return $id;
    }
    else    {
	warn('cant create item: parent SYSTEM or DELETED');
	return undef;
    }
}

sub update	{
    my $self = shift;

    if( ( $self->get_action('settings_item_update') || $self->guard->is_administrator() ) && $self->get_id() )	{
	my $query = 'update settings_items set name = ?, ordering = ?, flags = ?, updated = now() 
	    where id = ? and find_in_set("SYSTEM",flags) = 0';
	$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string()||'', $self->get_id() );
	foreach( keys %{$self->{_aliases}} )	{
	    my $query = 'select * from settings_item_aliases where lang_id = ? and parent_id = ?';

	    my $C = $self->dbh->selectrow_hashref( $query, undef, $_,  $self->get_id() );
	    if( $C->{id} )	{
		$query = 'update settings_item_aliases set alias = ?, lang_id = ?, parent_id = ? where id = ?';
		$self->dbh->do( $query, undef, $self->get_alias($_)||'', $_, $self->get_id(), $C->{id} ) ;
	    }
	    else	{
		$query = 'replace into settings_item_aliases( alias, lang_id, parent_id) values( ?, ?, ?)';
		$self->dbh->do( $query, undef, $self->get_alias($_)||'', $_, $self->get_id() ) ;
	    }
	}   
	return 1;
    }
    else    {
	return 0;
    }
}

sub move	{
    my $self = shift;
    my $id = shift||0;

    require HellFire::Settings::CategoryDAO;
    require HellFire::Settings::ValueDAO;
    require HellFire::Settings::FieldDAO;
    if( $id)	{
	my $C = new HellFire::Settings::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	my $C2 = new HellFire::Settings::CategoryDAO( $self->dbh, $self->guard );
	$C2->load( $id );

	my $F = new HellFire::Settings::FieldDAO( $self->dbh, $self->guard );
	$F->set_parent_id( $C->get_id() );
	my $ff = $F->get_fields();

	my $F2 = new HellFire::Settings::FieldDAO( $self->dbh, $self->guard );
	$F2->set_parent_id( $C2->get_id() );
	my $ff2 = $F2->get_fields();

	my $access = $self->guard->is_administrator() || ( $C->get_action('referece_item_delete') && $C2->get_action('referece_item_add') );

	if( $self->get_id() && $access && !$self->is_system )	{
	    my $query = 'update settings_items set parent_id = ? where id = ?'; 
	    $self->dbh->do( $query, undef, $id, $self->get_id()  );	
	    $self->set_parent_id( $id );
	    $self->set_access( $self->get_id() );

	    foreach my $i ( @$ff )	{
		    my $V = new HellFire::Settings::ValueDAO( $self->dbh, $self->guard );
		    $V->load( $i, $self );

		    foreach my $j ( @$ff2 )	{
			    if( $i->get_source_id() == $j->get_source_id &&
			    $i->get_source_group_id() == $j->get_source_group_id &&
			    $i->get_source_id() > 0  && $i->get_source_group_id() > 0 &&
			    $i->get_name() eq $j->get_name() )      {
				    my $V2 = new HellFire::Settings::ValueDAO( $self->dbh, $self->guard );
				    $V2->set_type( $V->get_type() );
				    $V2->set_type_id( $V->get_type_id() );
				    $V2->set_parent_id( $j->get_id );
				    $V2->set_item_id( $self->get_id() );
				    foreach my $v ( @{$V->get_value_id()} )	{
					    $V2->set_value( $v );
				    }
				    $V2->save();
				    last;
			    }
			    elsif( $i->get_name() eq $j->get_name() && 
			    $i->get_type_id() == $j->get_type_id() )	{
				    my $V2 = new HellFire::Settings::ValueDAO( $self->dbh, $self->guard );
				    $V2->set_type( $V->get_type() );
				    $V2->set_type_id( $V->get_type_id() );
				    $V2->set_parent_id( $j->get_id );
				    $V2->set_item_id( $self->get_id() );
				    $V2->set_value( $V->to_string() );
				    $V2->save();
				    last;
			    }

		    }

		    $V->destroy();
	    }
#$self->save();

	    return 1;	
	}
    }
    return undef;
}


sub destroy	{
    my $self = shift;

    my $access = $self->get_action('settings_item_delete') || $self->guard->is_administrator();
    if( $self->get_id() && !$self->is_system() && !$self->is_locked() && $access )	{
	require HellFire::File::ItemDAO;
	my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
	my $ic = $F->find_by_prefix('reference/item');	

	my $query = 'select id from file_items where parent_id = ? and item_id = ?';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $ic, $self->get_id() );
	while( my @arr = $sth->fetchrow_array() )    {
	    $F->load( $arr[0] );
	    $F->destroy();
	}

	my $pp = int($self->get_id()/1000);
        my $prefix = 'reference/item';
        my $path = $self->guard->ini->store_dir."/$prefix/".$pp.'/'.$self->get_id();
        `rmdir  $path`;

	$self->dbh->do('call settings_item_destroy(?,@c,@m)', undef, $self->get_id() );
	return 1;
    }
    else    {
	warn('delete_item: item not found');
    }
    return undef;
}

sub is_unique	{
    my $self = shift;

    if( $self->get_name() )	{
	my $query = 'select id from settings_items where name = ? and parent_id = ?';
	my $id = $self->dbh->selectrow_array( $query, undef, $self->get_name(), $self->get_parent_id() );

	if( $id > 0 && $self->get_id() != $id  )	{
	    return undef;
	}

	return 1;
    }
    return undef;
}

sub find    {
    my $self = shift;
    my $val = shift ||'';

    my $query = 'select id from settings_items where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
    my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() )||0;

    return $id
}

sub get_action  {
    my $self = shift;
    my $val = shift||'';

    my $query = 'select count(*) from settings_item_access a inner join configuration_actions c on c.id = a.action_id 
                    where a.parent_id = ? and a.group_id in('.( $self->get_groups() ).') and c.name = ?';
    my $c = $self->dbh->selectrow_array($query, undef, $self->get_id(), $val);
    return $c||0;
}

sub set_access    {
    my $self = shift;
    my $id = shift||$self->get_id()||0;

    if( $id )	{
        my $query = 'insert into settings_item_access( parent_id, group_id, action_id ) 
                        select ?, group_id, action_id from settings_category_access where parent_id = ?';
        $self->dbh->do( $query, undef, $id, $self->get_parent_id() );
    }
}

sub touch   {
    my $self = shift;
    $self->dbh->do('update settings_items set updated = now() where id = ?', undef, $self->get_id());
}

sub is_cache    {
    my $self = shift;
    return $self->get_flag('CACHE');
}

sub get_all_siblings   {
        my $self = shift;
        my $pid = shift || $self->get_parent_id() ||0;
	my $params = shift||{};

        my @arr;
        if( $pid )      {
                my $query = 'select id from settings_items where parent_id = ?';
                my $sth = $self->dbh->prepare( $query );
                $sth->execute( $pid );

                while( my $id = $sth->fetchrow_array() )    {
                        my $I = new HellFire::Settings::ItemDAO( $self->dbh, $self->guard );
                        push @arr, $I if( $I->load( $id, $params ) );
                }
        }
        return \@arr;
}

sub get_all_siblings_id   {
        my $self = shift;
        my $pid = shift || $self->get_parent_id() ||0;
	my $params = shift;

        my @arr;
        if( $pid )      {
		my $query;
		if( $self->guard->is_administrator() )	{
                	$query = 'select id from settings_items where parent_id = ?'; 
		}
		else	{
                	$query = 'select i.id from settings_items i inner join settings_item_access a on a.parent_id = i.id 
				inner join configuration_actions c on c.id = a.action_id
                    		where a.group_id in('.( $self->get_groups() ).') and c.name = "settings_item_view" and i.parent_id = ?';
		}
                my $sth = $self->dbh->prepare( $query );
                $sth->execute( $pid );

                while( my $id = $sth->fetchrow_array() )    {
                        push @arr, $id;
                }
        }
        return \@arr;
}

sub get_groups	{
	my $self = shift;
	
	my @arr = @{$self->guard->get_groups()};
	unless( $self->guard->is_cgi() )	{
		push @arr, 0;
	}
	my %temp = ();
	@arr = grep ++$temp{$_} < 2, @arr;

	return join(',',@arr);
}

sub clear_access    {
    my $self = shift;

    if( $self->get_id() )   {
        my $query = 'delete from settings_item_access where parent_id = ?';
        $self->dbh->do( $query, undef, $self->get_id() );
    }
}

sub get_grid	{
	my $self = shift;
	my $params = shift;
	my $dbh = $self->dbh;

	require HellFire::Settings::FieldDAO;

	my $cols;
	if( $params->{fields} ) {
		$cols = $params->{fields};
	}
	else    {
		my $F = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
		$F->set_parent_id( $params->{parent_id} );
		$cols = $F->get_fields( { lang_id => $params->{lang_id}, 
					with_fields => $params->{with_fields},
					without_fields => $params->{without_fields}   
					} );
	}

	my $sl;# = $Ref->get_source_list( $params->{parent_id} );

	push @$sl, $params->{parent_id};
	my $lid = $self->guard->get_lang_id() ||0;
=head
	my @uselect = "( select i.id col, if(isnull(a.alias),i.name,a.alias) value from settings_items i left join settings_item_aliases a 
		on a.parent_id = i.id and a.lang_id = $lid
		where i.parent_id in (".join(',',@$sl).") and i.id = ? and find_in_set('DELETED',i.flags) = 0 )";
	my @uselect = " 
( select \@_id col, if(isnull(a.alias),i.name,a.alias) value from settings_items i left join settings_item_aliases a 
		on a.parent_id = i.id and a.lang_id = $lid
		where i.id = \@_id and find_in_set('DELETED',i.flags) = 0 )";

=cut

	my $uselect2 = 'select if(isnull(a.alias),i.name,a.alias) value ';

	my $SF;

	foreach( @$cols )	{
		my $type_name = $_->get_type();

		if( $type_name eq 'reference' )	{
			$uselect2 .= ", ( select group_concat(value) from settings_values_reference  where parent_id = ".$_->get_id()." and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f".$_->get_id(); 
			#$uselect2 .= ", base_get_settings_value(".$_->get_source_group_id.",".$_->get_source_id.",".$_->get_source_field_id.",".$lid.","."(select group_concat(value) from settings_values_reference  where parent_id = ".$_->get_id()." and item_id = \@_id and find_in_set('DELETED',flags) = 0 )".") __fv".$_->get_id();
		}
		else	{
			$uselect2 .= ", ( select value from settings_values_".$type_name."  where parent_id = ".$_->get_id()." and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f".$_->get_id();
		}

		if( $_->get_name eq $params->{order_id} )	{
			$SF = $_;
		}
	}


	$uselect2 .= " from settings_items i left join settings_item_aliases a 
                on a.parent_id = i.id and a.lang_id = $lid
                where i.id = \@_id and find_in_set('DELETED',i.flags) = 0 ";
	
	my $sth13 = $dbh->prepare( $uselect2 );

	my @all_collection;

	my $id_in;
	if( $params->{id_in} )	{
		$id_in .= ' and id in('.join(',',@{$params->{id_in}}).') ';
	}

	my $query = 'select id from settings_items where parent_id in ('.join(',',@$sl).') and find_in_set("DELETED",flags) = 0 '.$id_in ;

	my $ref = $dbh->selectall_arrayref($query);

	foreach ( @$ref )   {
		push @all_collection, $_->[0];
	}

	${$params->{count_all}} = scalar @all_collection;

	undef $ref;

	my @order_collection;

	if( $params->{order_id} eq 'id' || $params->{order_id} eq 'name' )	{
		$query = "select id from settings_items  
			where parent_id in( ".join(',',@$sl)." )  and find_in_set('DELETED',flags) = 0 $id_in  
			order by  $params->{order_id} $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref($query);

		foreach ( @$ref )   {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_id} eq 'alias' )	{
		$query = "select i.id from settings_items i inner join settings_item_aliases a on a.parent_id = i.id and a.lang_id = $lid  
			where i.parent_id in( ".join(',',@$sl)." )  and find_in_set('DELETED',i.flags) = 0 $id_in 
			order by a.alias $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref($query);

		foreach ( @$ref )   {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_id} eq 'rand' )	{
		$query = "select id from settings_items  
			where parent_id in( ".join(',',@$sl)." )  and find_in_set('DELETED',flags) = 0 $id_in 
			order by rand()";
		my $ref = $dbh->selectall_arrayref($query);

		foreach ( @$ref )   {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_id}  )	{
		my $type_name = $SF->get_type();
		$query = "select i.id 
			from settings_items i use index(id_parent), 
			     settings_values_$type_name v use index(parent_value) 
				     where v.item_id=i.id and v.parent_id = ? and i.parent_id in(".join(',',@$sl).") and find_in_set('DELETED',i.flags) = 0 and find_in_set('DELETED',v.flags) = 0 $id_in 
				     order by  v.value $params->{order_direction} ";
		my $ref = $dbh->selectall_arrayref($query, undef, $SF->get_id );

		foreach ( @$ref )   {
			push @order_collection, $_->[0];
		}

		undef $ref;
	}
	else	{
		$query = "select id from settings_items use index(parent_ordering) 
			where parent_id in( ? ) and find_in_set('DELETED',flags) = 0 $id_in 
			order by  ordering desc";
		my $ref = $dbh->selectall_arrayref($query, undef, $params->{parent_id});

		foreach ( @$ref )   {
			push @order_collection, $_->[0];
		}

		undef $ref;
	}

	my %temp = ();
	@temp{@all_collection} = ();
	foreach (@order_collection) {
		delete $temp{$_};
	}

	my @diff_collection = keys %temp;
	undef %temp;

	@all_collection = undef;
	if( lc $params->{order_direction} eq 'desc' )  {
		@all_collection = @order_collection;
		push @all_collection, @diff_collection;
	}
	else	{
		@all_collection = @diff_collection;
		push @all_collection, @order_collection;
	}

	my $to = $params->{offset}+$params->{limit} > scalar @all_collection ? scalar @all_collection : $params->{offset}+$params->{limit};
	my @arr;
	for( $params->{offset} .. $to-1 )   {
		my @val;
		$dbh->do('set @_id = ?', undef, $all_collection[$_] );		
		$sth13->execute( ) ;

		my $item = $sth13->fetchrow_hashref();
		$item->{value} =~ s/\&/\&amp;/g;

		for( my $i = 0; $i < scalar @$cols; $i++ )      {
			$item->{ '__f'.$$cols[$i]->get_id() } ||= '';
			$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\&/\&amp;/g;
			$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\</\&lt;/g;
			$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\>/\&gt;/g;

			my $type_name = $$cols[$i]->get_type();
			if( $type_name eq 'reference' )	{
				#$item->{ '__f'.$$cols[$i]->get_id() } = $dbh->selectrow_array("select group_concat(name) from settings_items where id in(".($item->{ '__f'.$$cols[$i]->get_id() }||0).")");
				$item->{ '__f'.$$cols[$i]->get_id() } = $self->dbh->selectrow_array( 
	'call base_get_reference_valuep(?,?,?,?,?)', undef, $$cols[$i]->get_source_group_id(), $$cols[$i]->get_source_id(), $$cols[$i]->get_source_field_id(), $self->guard->get_lang_id()||1, $item->{ '__f'.$$cols[$i]->get_id() }||0   );
			}
			push @val, { value => $item->{ '__f'.$$cols[$i]->get_id() }, 
					cdata => ( $type_name eq 'text' ? 1 : 0 ), 
					$$cols[$i]->get_name() => 1, 
					name => $$cols[$i]->get_name()  };
		}
		push @arr, { id => $all_collection[$_], alias => $item->{value}||'', values => \@val };
	}

	return \@arr;
}



return 1;
