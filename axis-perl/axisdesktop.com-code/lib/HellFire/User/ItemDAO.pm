## @file
# Implementation of HellFire::User::ItemDAO

## @addtogroup User
# @{
## @class
# Manage of user items

package HellFire::User::ItemDAO;

## }@

use strict;
use base qw(HellFire::User);

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}   = $dbh;
	$self->{'_guard'} = $G;

	bless $self, $class;
	return $self;
}

sub validate_name {
	my $self = shift;

	my $n = $self->get_name();
	unless( $n ) {
		$n = 'user';
	}
	unless( $self->is_unique( $n ) ) {
		$self->set_name( $n . '_' . int( rand( 100000000 ) ) );
	}

	return $self->get_name();
}

sub get_password {
	my $self = shift;
	return $self->{'_password'} || '';
}

sub set_password {
	my $self = shift;
	$self->{'_password'} = shift;
	return $self->{'_password'};
}

sub get_password2 {
	my $self = shift;
	return $self->{'_password2'} || '';
}

sub set_password2 {
	my $self = shift;
	$self->{'_password2'} = shift;
	return $self->{'_password2'};
}

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	if( $self->guard->is_administrator() || $self->get_action( 'user_item_view' ) ) {
		my $query = 'select * from user_items where id = ?';

		my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
		$self->flags_to_hash( $h );

		foreach my $i ( keys %$h ) {
			if( $i =~ /FLAG_(\w+)/ ) {
				$self->set_flag( $1 );
			}
			else {
				my $sf = "set_$i";
				$self->$sf( $h->{$i} );
			}
		}

		my $sth;
		if( $params->{lang_id} ) {
			$query = 'select lang_id, alias from user_item_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $self->guard->get_lang_id() );
		}
		else {
			$query = 'select lang_id, alias from user_item_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
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

sub login {
	my $self   = shift;
	my $login  = shift || '';
	my $email  = shift || '';
	my $passwd = shift || '';

	my $id = 0;
	if( length $email > 0 ) {
		my $query = 'select id from user_items where email = ? and password = password(?)';
		$id = $self->dbh->selectrow_array( $query, undef, $email, $passwd );
	}
	elsif( length $login > 0 ) {
		my $query = 'select id from user_items where name = ? and password = password(?)';
		$id = $self->dbh->selectrow_array( $query, undef, $login, $passwd );
	}

	return $id;
}

sub add {
	my $self = shift;

	require HellFire::User::CategoryDAO;
	my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from user_items where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	my $access = $C->get_action( 'user_item_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $access ) {

		unless( $self->get_password() ) {
			$self->set_password( $self->guard->generate_key( 10 ) );
		}

		my $query = 'insert into user_items(password, email, parent_id, name, ordering, inserted, flags, updated) 
						values(password(?),?,?,?,?, now(),?,now())';
		$self->dbh->do( $query, undef, $self->get_password(), $self->get_email(), $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), '' );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$self->set_access( $id );

		if( $self->get_inserted() ) {
			$self->dbh->do( 'update user_items set inserted = ? where id = ?', undef, $self->get_inserted(), $id );
		}

		foreach ( keys %{ $self->{_aliases} } ) {
			$query = 'insert into user_item_aliases( alias, lang_id, parent_id) values( ?, ?, ?)';
			$self->dbh->do( $query, undef, $self->get_alias( $_ ) || '', $_, $id );
		}

		return $id;
	}
	else {
		warn( 'cant create item: parent SYSTEM or DELETED' );
		return undef;
	}
}

## @method int update( )
# @brief Update current user
# @return int id if success or 0 if failure
#
# @code
# $I->save();
# @endcode
sub update {
	my $self = shift;

	$self->set_name( 'administrator' ) if( $self->get_id() == 1 );

	if( ( $self->get_action( 'user_item_update' ) || $self->guard->is_administrator() ) && $self->get_id() ) {
		if( length $self->get_password() && $self->get_password() eq $self->get_password2() ) {
			my $query = 'update user_items set name = ?, ordering = ?, flags = ?, updated = now(), email = ?,
								password = password(?) 
								where id = ? and find_in_set("SYSTEM",flags) = 0';
			$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_email(), $self->get_password(), $self->get_id() );
		}
		else {
			my $query = 'update user_items set name = ?, ordering = ?, flags = ?, updated = now(), email = ?
								where id = ? and find_in_set("SYSTEM",flags) = 0';
			$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_email(), $self->get_id() );
		}

		foreach ( keys %{ $self->{_aliases} } ) {
			my $query = 'select * from user_item_aliases where lang_id = ? and parent_id = ?';

			my $C = $self->dbh->selectrow_hashref( $query, undef, $_, $self->get_id() );
			if( $C->{parent_id} ) {
				$query = 'update user_item_aliases set alias = ? where lang_id = ? and parent_id = ?';
				$self->dbh->do( $query, undef, $self->get_alias( $_ ) || '', $_, $self->get_id() );
			}
			else {
				$query = 'insert into user_item_aliases( alias, lang_id, parent_id) values( ?, ?, ?)';
				$self->dbh->do( $query, undef, $self->get_alias( $_ ) || '', $_, $self->get_id() );
			}
		}
		return $self->get_id();
	}
	else {
		warn 'update user denied';
	}

	return undef;
}

sub move {
	my $self = shift;
	my $id = shift || 0;

	require HellFire::User::CategoryDAO;
	require HellFire::User::ValueDAO;
	require HellFire::User::FieldDAO;
	if( $id ) {
		my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $self->get_parent_id() );

		my $C2 = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		$C2->load( $id );

		my $F = new HellFire::User::FieldDAO( $self->dbh, $self->guard );
		$F->set_parent_id( $C->get_id() );
		my $ff = $F->get_fields();

		my $F2 = new HellFire::User::FieldDAO( $self->dbh, $self->guard );
		$F2->set_parent_id( $C2->get_id() );
		my $ff2 = $F2->get_fields();

		my $access = $self->guard->is_administrator() || ( $C->get_action( 'referece_item_delete' ) && $C2->get_action( 'referece_item_add' ) );

		if( $self->get_id() && $access && !$self->is_system ) {

			#my $query = 'update user_items set parent_id = ? where id = ?';
			my $query = 'insert ignore into user_groups(category_id,user_id) values(?,?)';
			$self->dbh->do( $query, undef, $id, $self->get_id() );
			$self->set_parent_id( $id );
			$self->set_access( $self->get_id() );

			foreach my $i ( @$ff ) {
				my $V = new HellFire::User::ValueDAO( $self->dbh, $self->guard );
				$V->load( $i, $self );

				foreach my $j ( @$ff2 ) {
					if(    $i->get_source_id() == $j->get_source_id
						&& $i->get_source_group_id() == $j->get_source_group_id
						&& $i->get_source_id() > 0
						&& $i->get_source_group_id() > 0
						&& $i->get_name() eq $j->get_name() )
					{
						my $V2 = new HellFire::User::ValueDAO( $self->dbh, $self->guard );
						$V2->set_type( $V->get_type() );
						$V2->set_type_id( $V->get_type_id() );
						$V2->set_parent_id( $j->get_id );
						$V2->set_item_id( $self->get_id() );
						foreach my $v ( @{ $V->get_value_id() } ) {
							$V2->set_value( $v );
						}
						$V2->save();
						last;
					}
					elsif( $i->get_name() eq $j->get_name()
						&& $i->get_type_id() == $j->get_type_id() )
					{
						my $V2 = new HellFire::User::ValueDAO( $self->dbh, $self->guard );
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

sub destroy {
	my $self = shift;

	if( $self->get_id() == 1 ) {
		return undef;
	}

	my $access = $self->get_action( 'user_item_delete' ) || $self->guard->is_administrator();
	if( $self->get_id() && !$self->is_system() && !$self->is_locked() && $access ) {
		require HellFire::File::ItemDAO;
		my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		my $ic = $F->find_by_prefix( 'user/item' );

		my $query = 'select id from file_items where parent_id = ? and item_id = ?';
		my $sth   = $self->dbh->prepare( $query );
		$sth->execute( $ic, $self->get_id() );
		while ( my @arr = $sth->fetchrow_array() ) {
			$F->load( $arr[0] );
			$F->destroy();
		}

		my $pp     = int( $self->get_id() / 1000 );
		my $prefix = 'user/item';
		my $path   = $self->guard->ini->store_dir . "/$prefix/" . $pp . '/' . $self->get_id();
		`rmdir  $path`;

		$self->dbh->do( 'call user_item_destroy(?,@c,@m)', undef, $self->get_id() );
		return 1;
	}
	else {
		warn( 'delete_item: item not found' );
	}
	return undef;
}

sub is_unique {
	my $self = shift;

	if( $self->get_name() ) {
		my $query = 'select id from user_items where name = ? and parent_id = ?';
		my $id = $self->dbh->selectrow_array( $query, undef, $self->get_name(), $self->get_parent_id() );

		if( $id > 0 && $self->get_id() != $id ) {
			return undef;
		}

		return 1;
	}
	return undef;
}

## @method int find( string name, hashref params )
# @brief Find item id by name
# @param name : string : search name
# @param params : hashref
#		- parent_id : int :
#			- > 0 : search in this category
#			- -1 : search in all categories
#			- default : search in current item category
# @return int id if found or 0 if not
#
# @code
# $I->find( 'item' );
# $I->find( 'item', { parent_id => -1 } );
# @endcode
sub find {
	my $self   = shift;
	my $val    = shift || '';
	my $params = shift;

	if( $params->{parent_id} > 0 ) {
		my $query = 'select id from user_items where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->selectrow_array( $query, undef, $val, $params->{parent_id} ) || 0;
	}
	elsif( $params->{parent_id} < 0 ) {
		my $query = 'select id from user_items where name = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->fetchall_arrayref( $query, undef, $val );
	}
	else {
		my $query = 'select id from user_items where name = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->selectrow_array( $query, undef, $val ) || 0;
	}

	return undef;
}

## @method int find_by_email( string email )
# @brief Find user id by email
# @param email : string : email
# @return int id
#
# @code
# $I->find_by_email('fre@mail.com');
# @endcode
sub find_by_email {
	my $self  = shift;
	my $email = shift;

	my $query = 'select id from user_items where email = ? and find_in_set("DELETED", flags) = 0';
	return $self->dbh->selectrow_array( $query, undef, $email );
}

sub get_action {
	my $self = shift;
	my $val = shift || '';

	my $grp = join( ',', @{ $self->get_groups() }, 0 );

	my $query = 'select count(*) from user_item_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->{_dbh}->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub clear_access {
	my $self = shift;

	if( $self->get_id() ) {
		my $query = 'delete from user_item_access where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
	}
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into user_item_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from user_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub touch {
	my $self = shift;
	$self->dbh->do( 'update user_items set updated = now() where id = ?', undef, $self->get_id() );
}

sub is_cache {
	my $self = shift;
	return $self->get_flag( 'CACHE' );
}

sub get_all_siblings {
	my $self   = shift;
	my $pid    = shift || $self->get_parent_id() || 0;
	my $params = shift || {};

	my @arr;
	if( $pid ) {
		my $query = 'select id from user_items where parent_id = ?';
		my $sth   = $self->dbh->prepare( $query );
		$sth->execute( $pid );

		while ( my $id = $sth->fetchrow_array() ) {
			my $I = new HellFire::User::ItemDAO( $self->dbh, $self->guard );
			push @arr, $I if( $I->load( $id, $params ) );
		}
	}
	return \@arr;
}

sub get_all_siblings_id {
	my $self   = shift;
	my $pid    = shift || $self->get_parent_id() || 0;
	my $params = shift;

	my @arr;
	if( $pid ) {
		my $query;
		if( $self->guard->is_administrator() ) {
			$query = 'select id from user_items where parent_id = ?';
		}
		else {
			$query = 'select i.id from user_items i inner join user_item_access a on a.parent_id = i.id 
				inner join configuration_actions c on c.id = a.action_id
							where a.group_id in(' . ( $self->get_groups() ) . ') and c.name = "user_item_view" and i.parent_id = ?';
		}
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $pid );

		while ( my $id = $sth->fetchrow_array() ) {
			push @arr, $id;
		}
	}
	return \@arr;
}

=head
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
=cut

sub check_administrator {
	my $self = shift;
	my $id = shift || 0;

	return 1 if( $id == 1 );

	#my $query = 'select 1 from user_items i inner join user_categories c on c.id = i.parent_id and i.id = ? and c.name = "administrator"';
	my $query = 'select 1 from user_items i inner join user_groups g on i.id = g.user_id and i.id = ? inner join user_categories c on c.id = g.category_id and c.name = "administrators"';
	my $ret = $self->dbh->selectrow_array( $query, undef, $id );

	return $ret || 0;
}

sub get_groups {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	my @arr   = ( 0 );
	my $query = '(select category_id from user_groups where user_id = ?)
		union
		(select parent_id from user_items where id = ?)';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $id, $id );

	while ( my @a = $sth->fetchrow_array() ) {
		push @arr, $a[0];
	}

	my %temp = ();
	@arr = grep ++$temp{$_} < 2, @arr;

	return \@arr;
}

sub get_email {
	my $self = shift;
	return $self->{'_email'};
}

sub set_email {
	my $self = shift;
	$self->{'_email'} = shift;
	return $self->{'_email'};
}

sub update_password {
	my $self = shift;
	my $val  = shift;

	$self->dbh->do( 'update user_items set password = password(?) where id = ? limit 1', undef, $self->get_password() || $val, $self->get_id() );
}

sub get_grid {
	my $self   = shift;
	my $params = shift;
	my $dbh    = $self->dbh;

	require HellFire::User::FieldDAO;

	my $cols;
	if( $params->{fields} ) {
		$cols = $params->{fields};
	}
	else {
		my $F = new HellFire::User::FieldDAO( $dbh, $self->guard );
		$F->set_parent_id( $params->{parent_id} );
		$cols = $F->get_fields( { lang_id => $params->{lang_id} } );
	}

	my $sl;    # = $self->get_source_list( $params->{parent_id} );

	push @$sl, $params->{parent_id};
	my $lid = $self->guard->get_lang_id() || 0;

	my $flag_modificator;
	$flag_modificator .= " and find_in_set('DELETED',i.flags) = 0 " unless( $params->{'with_deleted'} );
	$flag_modificator .= " and find_in_set('HIDDEN',i.flags) = 0 "  unless( $params->{'with_hidden'} );

	my $select_modificator = 'select i.id';
	$select_modificator .= ',i.name'     if( $params->{with_name} );
	$select_modificator .= ',i.email'     if( $params->{with_email} );
	$select_modificator .= ',i.ordering' if( $params->{with_ordering} );
	$select_modificator .= ',i.inserted, year(i.inserted) inserted_year, day(i.inserted) inserted_day,
								month(i.inserted) inserted_month, hour(i.inserted) inserted_hour,
								minute(i.inserted) inserted_minute , second(i.inserted) inserted_second ' if( $params->{with_inserted} );
	$select_modificator .= ',i.updated, year(i.updated) updated_year, day(i.updated) updated_day,
								month(i.updated) updated_month,  hour(i.updated) updated_hour,
								minute(i.updated) updated_minute , second(i.updated) updated_second' if( $params->{with_updated} );
	$select_modificator .= ',a.alias' if( $params->{with_alias} );

	#	$select_modificator .= ',i.user_id ' if( $params->{with_user_id}  );

	my $uselect2 = $select_modificator;
	my $SF;

	foreach ( @$cols ) {
		my $type_name = $_->get_type();

		if( $type_name eq 'reference' ) {
			$uselect2 .= ", ( select group_concat(value) from user_values_reference  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
		}
		else {
			$uselect2 .= ", ( select value from user_values_" . $type_name . "  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
		}

		if(    $_->get_name eq $params->{order_id}
			|| $_->get_id eq $params->{order_id} )
		{
			$SF = $_;
		}
	}

	my $from_modificator = ' from user_items i ';
	$from_modificator .= " left join user_item_aliases a
							on a.parent_id = i.id and a.lang_id = $lid " if( $params->{with_alias} );

	$uselect2 .= " $from_modificator where i.id = \@_id $flag_modificator";

	my $sth13 = $dbh->prepare( $uselect2 );

	#my @uselect = "( select i.id col, if(isnull(a.alias),i.name,a.alias) value from user_items i left join user_item_aliases a
	#	on a.parent_id = i.id and a.lang_id = $lid
	#	where i.parent_id in (".join(',',@$sl).") and i.id = ? and find_in_set('DELETED',i.flags) = 0 )";
	#my @uselect = "( select i.id col, if(isnull(a.alias),i.name,a.alias) value from user_items i left join user_item_aliases a
	#	on a.parent_id = i.id and a.lang_id = $lid
	#	where  i.id = ? and find_in_set('DELETED',i.flags) = 0 )";

	#my $SF;
	#
	#foreach( @$cols )	{
	#	my $type_name = $_->get_type();
	#
	#	if( $type_name eq 'reference' )	{
	#		push @uselect, "( select ". $_->get_id()." col, group_concat(value) from user_values_".$type_name."  where parent_id = ".$_->get_id()." and item_id = ? and find_in_set('DELETED',flags) = 0 group by parent_id, item_id)";
	#	}
	#	else	{
	#		push @uselect, "( select ". $_->get_id()." col, value from user_values_".$type_name."  where parent_id = ".$_->get_id()." and item_id = ? and find_in_set('DELETED',flags) = 0 )";
	#	}
	#
	#	if( $_->get_name eq $params->{order_id} )	{
	#		$SF = $_;
	#	}
	#}
	#
	#my $wtfq =  join (' union ', @uselect);
	#my $sth13 = $dbh->prepare( $wtfq );

	my @all_collection;

	my $src1 = $self->get_source_list( $params->{parent_id} );
	my $src_in;
	if( $src1 ) {
		$src_in .= ' or id in(' . join( ',', @{$src1} ) . ') ' if( scalar @$src1 );
	}

	my $id_in;
	if( $params->{id_in} ) {
		$id_in .= ' and id in(' . join( ',', @{ $params->{id_in} } ) . ') ';
	}

	#my $query = 'select id from user_items where (parent_id in ('.join(',',@$sl).') and find_in_set("DELETED",flags) = 0 '.$id_in.') ' . $src_in ;
	my $query = 'select id from user_items i where i.parent_id in (' . join( ',', @$sl ) . ')  ' . $flag_modificator . $id_in;
	my $ref = $dbh->selectall_arrayref( $query );

	foreach ( @$ref ) {
		push @all_collection, $_->[0];
	}

	#	${$params->{count_all}} = scalar @all_collection;
	$params->{count_all} = scalar @all_collection;

	undef $ref;

	my @order_collection;

	if( $params->{order_by} eq 'id' || $params->{order_by} eq 'name' || $params->{order_by} eq 'ordering' ) {
		$query = "select i.id from user_items i
			where i.parent_id in( " . join( ',', @$sl ) . " )   $flag_modificator $id_in $src_in  
			order by  $params->{order_by} $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref( $query );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_by} eq 'alias' ) {
		$query = "select i.id from user_items i inner join user_item_aliases a on a.parent_id = i.id and a.lang_id = $lid  
			where i.parent_id in( " . join( ',', @$sl ) . " )   $flag_modificator $id_in  $src_in
			order by a.alias $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref( $query );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_by} eq 'rand' ) {
		$query = "select i.id from user_items i 
			where i.parent_id in( " . join( ',', @$sl ) . " )   $flag_modificator $id_in $src_in
			order by rand()";
		my $ref = $dbh->selectall_arrayref( $query );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_by} ) {
		my $type_name = $SF->get_type();
		$query = "select i.id 
			from user_items i use index(id_parent), 
				 user_values_$type_name v use index(parent_value) 
					 where (v.item_id=i.id and v.parent_id = ? and i.parent_id in(" . join( ',', @$sl ) . ") and find_in_set('DELETED',i.flags) = 0 and find_in_set('DELETED',v.flags) = 0 $id_in ) $src_in 
					 order by  v.value $params->{order_direction} ";
		my $ref = $dbh->selectall_arrayref( $query, undef, $SF->get_id );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;
	}
	else {
		$query = "select i.id from user_items i use index(parent_ordering) 
			where i.parent_id in( ? ) $flag_modificator $id_in $src_in 
			order by  i.ordering desc";
		my $ref = $dbh->selectall_arrayref( $query, undef, $params->{parent_id} );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;
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

	require HellFire::File::ItemDAO;
	my $File = new HellFire::File::ItemDAO( $self->dbh, $self->guard );

	my $to = $params->{offset} + $params->{limit} > scalar @all_collection ? scalar @all_collection : $params->{offset} + $params->{limit};
	my @arr;
	for( $params->{offset} .. $to - 1 ) {
		my @val;
		$dbh->do( 'set @_id = ?', undef, $all_collection[$_] );
		$sth13->execute();

		my $item = $sth13->fetchrow_hashref();

		#$item->{value} =~ s/\&/\&amp;/g;

		for( my $i = 0 ; $i < scalar @$cols ; $i++ ) {
			$item->{ '__f' . $$cols[$i]->get_id() } ||= '';
			$item->{ '__f' . $$cols[$i]->get_id() } =~ s/\&/\&amp;/g;

			#$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\</\&lt;/g;
			#$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\>/\&gt;/g;

			my $type_name = $$cols[$i]->get_type();
			if( $type_name eq 'reference' ) {

				#$item->{ '__f' . $$cols[$i]->get_id() } =
				# $self->dbh->selectrow_array( 'call base_get_reference_valuep(?,?,?,?,?)', undef, $$cols[$i]->get_source_group_id(), $$cols[$i]->get_source_id(), $$cols[$i]->get_source_field_id(), $self->guard->get_lang_id() || 1, $item->{ '__f' . $$cols[$i]->get_id() } || 0 );
			}
			push @val,
			  {
				value                  => $item->{ '__f' . $$cols[$i]->get_id() },
				cdata                  => ( $type_name eq 'text' ? 1 : 0 ),
				$$cols[$i]->get_name() => 1,
				name                   => $$cols[$i]->get_name(),
				item_id                => $all_collection[$_],
				item_name              => $item->{name}
			  };
		}

		$item->{values} = \@val;
		$item->{href}   = $params->{href};
		$item->{href} .= '/' unless( $params->{href} =~ /\/$/ );
		$item->{href} .= $item->{name} . '.html';

		$params->{item} = $item;

		if( $params->{with_file_groups} ) {
			$item->{file_groups} = $File->get_files_by_group(
				{
					obj => 'HellFire::User::ItemDAO',
					id  => $item->{id}
				},
				$params
			);
		}

		push @arr, $item;
	}

	return \@arr;

}

sub get_source_list {
	my $self = shift;
	my $id   = shift;

	my $query = 'select user_id from user_groups where category_id = ?';
	my @ret;
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $id );
	while ( my @arr = $sth->fetchrow_array() ) {
		push @ret, $arr[0];
	}

	return \@ret;
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
		if( $_ eq '_content' ) {
			$ret->{content} = $self->get_content( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_descriptions' ) {
			$ret->{description} = $self->get_description( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_keywords' ) {
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


sub get_last_modified	{
	my $self = shift;
}

return 1;
