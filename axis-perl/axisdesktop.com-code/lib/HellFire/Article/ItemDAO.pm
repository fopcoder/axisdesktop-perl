## @file
# Implementation of HellFire::Article::ItemDAO

## @addtogroup Article 
# @{
## @class 
# Manage of articles items

package HellFire::Article::ItemDAO;

## }@

use strict;
use base qw(HellFire::Article);

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self;# = $class->SUPER::new();
	$self->{'_dbh'}   = $dbh;
	$self->{'_guard'} = $G;

	bless $self, $class;
	return $self;
}

sub validate_name {
	my $self = shift;

	my $n = $self->get_name();
	unless( $self->is_unique( $n ) ) {
		$self->set_name( $n . '_' . int( rand( 100000000 ) ) );
	}

	return $self->get_name();
}

sub get_updated {
	my $self = shift;
	return $self->{'_updated'} || '';
}

sub set_updated {
	my $self = shift;
	$self->{'_updated'} = shift;
	return $self->{'_updated'};
}

sub get_content {
	my $self = shift;
	my $val  = shift;

	return $self->{'_content'}->{$val} || '';
}

sub set_content {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_content'}->{$id} = $val;
	return $self->{'_content'}->{$id};
}

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	if( $self->guard->is_administrator() || $self->get_action( 'article_item_view' ) ) {
		my $query1 = 'select i.* from article_items i ';
		my $query2;
		
		if( $params->{with_localization} )	{
			$query2 .= ' inner join article_item_aliases a on i.id = a.parent_id ';
			$query2 .= ' and a.lang_id = '.$params->{lang_id};
		}
		
		if( $params->{with_content} )	{
			$query2 .= ' inner join article_item_content c on i.id = c.parent_id ';
			$query2 .= ' and c.lang_id = '.$params->{lang_id};
		}
		
		
		my $query = 'select *, date_format(updated,"%a, %d %b %Y %H:%i:%s GMT") last_modified from article_items where id = ?';

		my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
		$self->flags_to_hash( $h );

		foreach my $i ( keys %$h ) {
			if( $i =~ /FLAG_(\w+)/ ) {
				$self->set_flag( $1 );
			}
			else {
				my $sf = "set_$i";
				$self->$sf( $h->{$i}, $params ) if( $self->can( $sf ) );
			}
		}

		my $sth;
		if( $params->{lang_id} ) {
			$query = 'select lang_id, alias, description, title, keywords from article_item_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $self->guard->get_lang_id() );
		}
		else {
			$query = 'select lang_id, alias, description, title, keywords from article_item_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_description( $h->{'lang_id'}, $h->{'description'} );
			$self->set_keywords( $h->{'lang_id'}, $h->{'keywords'} );
			$self->set_title( $h->{'lang_id'}, $h->{'title'} );
		}

		#if( $params->{with_content} ) {
			if( $params->{lang_id} ) {
				$query = 'select lang_id, content from article_item_content where parent_id = ? and lang_id = ?';
				$sth   = $self->dbh->prepare( $query );
				$sth->execute( $id, $self->guard->get_lang_id() );
			}
			else {
				$query = 'select lang_id, content from article_item_content where parent_id = ? ';
				$sth   = $self->dbh->prepare( $query );
				$sth->execute( $id );
			}

			while ( my $h = $sth->fetchrow_hashref() ) {
				$self->set_content( $h->{'lang_id'}, $h->{'content'} );
			}
		#}

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

	require HellFire::Article::CategoryDAO;
	my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from article_items where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	my $access = $C->get_action( 'article_item_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $access ) {
		my $query = 'insert into article_items(parent_id, name, ordering, inserted, flags, user_id, updated) 
			values(?,?,?, now(),?,?,now())';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), 'HIDDEN', $self->guard->get_user_id() );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$self->set_access( $id );

		if( $self->get_inserted() ) {
			$self->dbh->do( 'update article_items set inserted = ? where id = ?', undef, $self->get_inserted(), $id );
		}

		foreach ( keys %{ $self->{_aliases} } ) {
			$query = 'insert into article_item_aliases( description, alias, lang_id, parent_id) values( ?, ?, ?, ?)';
			$self->dbh->do( $query, undef, $self->get_description( $_ ), $self->get_alias( $_ ), $_, $id );
		}

		foreach ( keys %{ $self->{_content} } ) {
			$query = 'insert into article_item_content( content, lang_id, parent_id) values( ?, ?, ?)';
			$self->dbh->do( $query, undef, $self->get_content( $_ ), $_, $id );
		}

		return $id;
	}
	else {
		warn( 'cant create item: parent SYSTEM or DELETED' );
		return undef;
	}
}

sub update {
	my $self = shift;

	if( ( $self->get_action( 'article_item_update' ) || $self->guard->is_administrator() ) && $self->get_id() ) {
		my $query = 'update article_items set name = ?, ordering = ?, flags = ?, updated = now() 
		where id = ? and find_in_set("SYSTEM",flags) = 0';
		$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string() || '', $self->get_id() );
		foreach ( keys %{ $self->{_aliases} } ) {
			my $query = 'select * from article_item_aliases where lang_id = ? and parent_id = ?';

			my $C = $self->dbh->selectrow_hashref( $query, undef, $_, $self->get_id() );
			if( $C->{item_id} ) {
				$query = 'update article_item_aliases set alias = ?, description = ? lang_id = ?, parent_id = ? where id = ?';
				$self->dbh->do( $query, undef, $self->get_alias( $_ ), $self->get_description( $_ ), $_, $self->get_id(), $C->{id} );
			}
			else {
				$query = 'replace into article_item_aliases( alias, description, keywords, title,  lang_id, parent_id) values( ?, ?, ?, ?, ?, ?)';
				$self->dbh->do( $query, undef, $self->get_alias( $_ ), $self->get_description( $_ ), $self->get_keywords( $_ ), $self->get_title( $_ ), $_, $self->get_id() );
			}
		}

		foreach ( keys %{ $self->{_content} } ) {
			my $query = 'select * from article_item_content where lang_id = ? and parent_id = ?';

			my $C = $self->dbh->selectrow_hashref( $query, undef, $_, $self->get_id() );
			if( $C->{parent_id} ) {
				$query = 'update article_item_content set content = ? where lang_id = ? and parent_id = ?';
				$self->dbh->do( $query, undef, $self->get_content( $_ ), $_, $self->get_id() );
			}
			else {
				$query = 'insert ignore into article_item_content( content, lang_id, parent_id) values( ?, ?, ?)';
				$self->dbh->do( $query, undef, $self->get_content( $_ ), $_, $self->get_id() );
			}
		}
		return 1;
	}
	else {
		return 0;
	}
}

sub move {
	my $self = shift;
	my $id = shift || 0;

	require HellFire::Article::CategoryDAO;
	require HellFire::Article::ValueDAO;
	require HellFire::Article::FieldDAO;
	if( $id ) {
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $self->get_parent_id() );

		my $C2 = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$C2->load( $id );

		my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
		$F->set_parent_id( $C->get_id() );
		my $ff = $F->get_fields();

		my $F2 = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
		$F2->set_parent_id( $C2->get_id() );
		my $ff2 = $F2->get_fields();

		my $access = $self->guard->is_administrator() || ( $C->get_action( 'article_item_delete' ) && $C2->get_action( 'article_item_add' ) );

		if( $self->get_id() && $access && !$self->is_system ) {
			my $query = 'update article_items set parent_id = ? where id = ?';
			$self->dbh->do( $query, undef, $id, $self->get_id() );
			$self->set_parent_id( $id );
			$self->set_access( $self->get_id() );

			foreach my $i ( @$ff ) {
				my $V = new HellFire::Article::ValueDAO( $self->dbh, $self->guard );
				$V->load( $i, $self );

				my $del = 1;
				foreach my $j ( @$ff2 ) {
					if(    $i->get_source_id() == $j->get_source_id
						&& $i->get_source_group_id() == $j->get_source_group_id
						&& $i->get_source_id() > 0
						&& $i->get_source_group_id() > 0
						&& $i->get_name() eq $j->get_name() )
					{
						my $V2 = new HellFire::Article::ValueDAO( $self->dbh, $self->guard );
						$V2->set_type( $V->get_type() );
						$V2->set_type_id( $V->get_type_id() );
						$V2->set_parent_id( $j->get_id );
						$V2->set_item_id( $self->get_id() );
						foreach my $v ( @{ $V->get_value_id() } ) {
							$V2->set_value( $v );
						}
						$V2->save();
						$del = 0 if( $i->get_id() == $j->get_id() );
						last;
					}
					elsif( $i->get_name() eq $j->get_name()
						&& $i->get_type_id() == $j->get_type_id() )
					{
						my $V2 = new HellFire::Article::ValueDAO( $self->dbh, $self->guard );
						$V2->set_type( $V->get_type() );
						$V2->set_type_id( $V->get_type_id() );
						$V2->set_parent_id( $j->get_id );
						$V2->set_item_id( $self->get_id() );
						$V2->set_value( $V->to_string() );
						$V2->save();
						$del = 0 if( $i->get_id() == $j->get_id() );
						last;
					}

				}

				$V->destroy() if( $del );
			}

			#$self->save();

			return 1;
		}
	}
	return undef;
}

sub destroy {
	my $self = shift;

	my $access = $self->get_action( 'article_item_delete' ) || $self->guard->is_administrator();
	if( $self->get_id() && !$self->is_system() && !$self->is_locked() && $access ) {
		require HellFire::File::ItemDAO;
		my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		my $ic = $F->find_by_prefix( 'article/item' );

		my $query = 'select id from file_items where parent_id = ? and item_id = ?';
		my $sth   = $self->dbh->prepare( $query );
		$sth->execute( $ic, $self->get_id() );
		while ( my @arr = $sth->fetchrow_array() ) {
			$F->load( $arr[0] );
			$F->destroy();
		}

		my $pp     = int( $self->get_id() / 1000 );
		my $prefix = 'article/item';
		my $path   = $self->guard->ini->store_dir . "/$prefix/" . $pp . '/' . $self->get_id();
		`rmdir  $path`;

		$self->dbh->selectrow_array( 'call article_item_destroy(?,@c,@m)', undef, $self->get_id() );
		return 1;
	}
	else {
		warn( 'delete_item: item not found' );
	}
	return undef;
}

sub ordering	{
	my $self = shift;
	my $src = shift;
	my $dst = shift;
	
	if( $src && $dst && $self->get_parent_id() )	{
		my @i = split( /,/, $src );
		my $diff = scalar @i;
		my $dst_ord = 0;
		
		my $query = 'select id, ordering from article_items where parent_id = ? order by ordering';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $self->get_parent_id() );
		while( my $h = $sth->fetchrow_hashref() )	{
			$self->dbh->do('update article_items set ordering = ordering - ? where id = ?', undef, $diff * 10, $h->{id} );
			if( $h->{id} == $dst )	{
				$dst_ord = $h->{ordering};
				last;
			}
		}
		
		for( my $k = 0; $k < $diff; $k++ )	{
			$self->dbh->do('update article_items set ordering = ? where id = ?', undef, $dst_ord  - $k * 10, $i[ $k ] ) or die;
		}
	}
}


sub is_unique {
	my $self = shift;

	if( $self->get_name() ) {
		my $query = 'select id from article_items where name = ? and parent_id = ?';
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
	my $self = shift;
	my $val = shift || '';
	my $params = shift;

	if( $params->{ parent_id } > 0 )	{
		my $query = 'select id from article_items where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->selectrow_array( $query, undef, $val, $params->{parent_id} )||0;
	}
	elsif( $params->{parent_id} < 0 )	{
		my $query = 'select id from article_items where name = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->fetchall_arrayref( $query, undef, $val );
	}
	else	{
		my $query = 'select id from article_items where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
		return $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() )||0;
	}

    return undef;
}

sub get_action {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select count(*) from article_item_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . ( $self->get_groups() ) . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert ignore into article_item_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from article_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub touch {
	my $self = shift;
	$self->dbh->do( 'update article_items set updated = now() where id = ?', undef, $self->get_id() );
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
		my $query = 'select id from article_items where parent_id = ?';
		my $sth   = $self->dbh->prepare( $query );
		$sth->execute( $pid );

		while ( my $id = $sth->fetchrow_array() ) {
			my $I = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
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
			$query = 'select id from article_items where parent_id = ?';
		}
		else {
			$query = 'select i.id from article_items i inner join article_item_access a on a.parent_id = i.id 
				inner join configuration_actions c on c.id = a.action_id
							where a.group_id in(' . ( $self->get_groups() ) . ') and c.name = "article_item_view" and i.parent_id = ?';
		}
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $pid );

		while ( my $id = $sth->fetchrow_array() ) {
			push @arr, $id;
		}
	}
	return \@arr;
}

sub get_groups {
	my $self = shift;

	my @arr = @{ $self->guard->get_groups() };
	unless( $self->guard->is_cgi() ) {
		push @arr, 0;
	}
	my %temp = ();
	@arr = grep ++$temp{$_} < 2, @arr;

	return join( ',', @arr );
}

sub clear_access {
	my $self = shift;

	if( $self->get_id() ) {
		my $query = 'delete from article_item_access where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
	}
}

sub backup	{
	my $self = shift;
}

sub restore	{
	my $self = shift;
}

sub history	{
	my $self = shift;
}

sub get_link_id	{
	my $self = shift;
}

sub set_link_id	{
	my $self = shift;
}

sub get_grid {
	my $self   = shift;
	my $params = shift;
	my $dbh    = $self->dbh;

	#require HellFire::Article::FieldDAO;

	my $cols;
	#unless( $params->{no_fields} ) {
	#	if( $params->{fields} ) {
	#		$cols = $params->{fields};
	#	}
	#	else {
	#		my $F = new HellFire::Article::FieldDAO( $dbh, $self->guard );
	#		$F->set_parent_id( $params->{parent_id} );
	#		$cols = $F->get_fields( $params );
	#	}
	#}

	my $sl;    # = $Ref->get_source_list( $params->{parent_id} );

	push @$sl, $params->{category_id}||$params->{parent_id};
	my $lid = $self->guard->get_lang_id() || 0;

	my $flag_modificator;
	$flag_modificator .= " and find_in_set('DELETED',i.flags) = 0 " unless( $params->{'with_deleted'} );
	$flag_modificator .= " and find_in_set('HIDDEN',i.flags) = 0 " unless( $params->{'with_hidden'} );

	my $select_modificator = 'select i.id';
	$select_modificator .= ',i.parent_id' if( $params->{category_id} );
	$select_modificator .= ',i.name' if( $params->{with_name} );
	$select_modificator .= ',i.ordering' if( $params->{with_ordering} );
	$select_modificator .= ',i.inserted, year(i.inserted) inserted_year, day(i.inserted) inserted_day,
								month(i.inserted) inserted_month, hour(i.inserted) inserted_hour,
								minute(i.inserted) inserted_minute , second(i.inserted) inserted_second ' if( $params->{with_inserted} );
	$select_modificator .= ',i.updated, year(i.updated) updated_year, day(i.updated) updated_day,
								month(i.updated) updated_month,  hour(i.updated) updated_hour,
								minute(i.updated) updated_minute , second(i.updated) updated_second' if( $params->{with_updated} );
	$select_modificator .= ',i.user_id ' if( $params->{with_user_id}  );
	$select_modificator .= ',a.alias' if( $params->{with_alias} );
	$select_modificator .= ',a.description' if( $params->{with_description} );
	$select_modificator .= ',a.keywords' if( $params->{with_keywords} );
	$select_modificator .= ',a.title' if( $params->{with_title} );

	my $uselect2 = $select_modificator;
	
	my %cat_href;
	
	if( $params->{category_id} )	{
		my $query = 'select id, name from article_categories where id in('.$params->{category_id}.')';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute();
		while( my $h = $sth->fetchrow_hashref() )	{
			$cat_href{ $h->{id} } = $h->{name};
		}
	}
	
	my $SF;

	foreach ( @$cols ) {
		my $type_name = $_->get_type();

		if( $type_name eq 'reference' ) {
			$uselect2 .= ", ( select group_concat(value) from article_values_reference  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
		}
		else {
			$uselect2 .= ", ( select value from article_values_" . $type_name . "  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
		}

		if( $_->get_name eq $params->{order_id} ||
			$_->get_id eq $params->{order_id} 
			)	{
			$SF = $_;
		}
	}

	my $from_modificator = ' from article_items i ';
	$from_modificator .= " left join article_item_aliases a
							on a.parent_id = i.id and a.lang_id = $lid " if( $params->{with_title} || $params->{with_alias} || $params->{with_keywords} || $params->{with_description} );

	
	$uselect2 .= " $from_modificator where i.id = \@_id $flag_modificator";

	my $sth13 = $dbh->prepare( $uselect2 );

	my @all_collection;

	my $id_in;
	if( $params->{id_in} ) {
		$id_in .= ' and id in(' . join( ',', @{ $params->{id_in} } ) . ') ';
	}

	#if( $params->{id_not_in} )	{
	#	$id_in .= ' and id not in('.join(',',@{$params->{id_not_in}}).') ';
	#}

	my $query = 'select id from article_items i where i.parent_id in (' . join( ',', @$sl ) . ')  '.$flag_modificator . $id_in;
	my $ref = $dbh->selectall_arrayref( $query );

	foreach ( @$ref ) {
		push @all_collection, $_->[0];
	}

	#${ $params->{count_all} } = scalar @all_collection;
	$params->{count_all} = scalar @all_collection;

	undef $ref;

	my @order_collection;

	if( $params->{order_by} eq 'id' || $params->{order_by} eq 'name' || $params->{order_by} eq 'inserted' || $params->{order_by} eq 'ordering' ) {
		$query = "select id from article_items  i 
			where i.parent_id in( " . join( ',', @$sl ) . " )  $flag_modificator $id_in  
			order by  $params->{order_by} $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref( $query );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}
		undef $ref;

	}
	elsif( $params->{order_by} eq 'alias' ) {
		$query = "select i.id from article_items i inner join article_item_aliases a on a.parent_id = i.id and a.lang_id = $lid  
			where i.parent_id in( " . join( ',', @$sl ) . " )  $flag_modificator $id_in 
			order by a.alias $params->{order_direction}";
		my $ref = $dbh->selectall_arrayref( $query );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;

	}
	elsif( $params->{order_by} eq 'rand' ) {
		$query = "select i.id from article_items i 
			where i.parent_id in( " . join( ',', @$sl ) . " )  $flag_modificator $id_in 
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
			from article_items i use index(id_parent), 
				 article_values_$type_name v use index(parent_value) 
					 where v.item_id=i.id and v.parent_id = ? and i.parent_id in(" . join( ',', @$sl ) . ") $flag_modificator and find_in_set('DELETED',v.flags) = 0 $id_in 
					 order by  v.value $params->{order_direction} ";
		my $ref = $dbh->selectall_arrayref( $query, undef, $SF->get_id );

		foreach ( @$ref ) {
			push @order_collection, $_->[0];
		}

		undef $ref;
	}
	else {
		$query = "select i.id from article_items i use index(parent_ordering) 
			where i.parent_id in( ".join( ',', @$sl )." ) $flag_modificator $id_in 
			order by  i.ordering desc";
		my $ref = $dbh->selectall_arrayref( $query );

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
				$item->{ '__f' . $$cols[$i]->get_id() } =
				  $self->dbh->selectrow_array( 'call base_get_reference_valuep(?,?,?,?,?)', undef, $$cols[$i]->get_source_group_id(), $$cols[$i]->get_source_id(), $$cols[$i]->get_source_field_id(), $self->guard->get_lang_id() || 1, $item->{ '__f' . $$cols[$i]->get_id() } || 0 );
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

		$item->{ values } = \@val;
		$item->{ href } = $params->{href};
		
		if( $params->{category_id} && $params->{category_id} ne $item->{parent_id} )	{
			$item->{ href } .= '/'.$cat_href{ $item->{parent_id} };
		}
		
        $item->{ href } .= '/' unless( $params->{href} =~ /\/$/);
        $item->{ href } .= $item->{name}.'.html';

		$params->{ item } = $item;

		if( $params->{with_index_file_groups} )	{
			$params->{with_file_groups} = $params->{with_index_file_groups};
			
			$item->{file_groups} = $File->get_files_by_group( {
				obj => 'HellFire::Article::ItemDAO',
				id => $item->{id} },
				$params  );
		}
		
		push @arr, $item;
	}

	return \@arr;
}

#   for destroy
sub get_items {
	my $self = shift;

	my $query;

	if( $self->guard->is_administrator() ) {
		$query = 'select id from article_items where parent_id = ?';
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		$query = "select distinct i.id from article_items i 
		inner join article_item_access a on a.parent_id = i.id 
		inner join configuration_actions c on a.action_id = c.id
		where i.parent_id = ? and c.name = 'article_item_delete' and a.group_id in ( $grp )";
	}

	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $self->get_parent_id() );
	my @arr;

	while ( my $id = $sth->fetchrow_array() ) {
		my $I = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
		$I->load( $id );
		push @arr, $I;
	}
	return \@arr;
}


sub to_template {
	my $self = shift;
	
	#require HellFire::DataType;
	#my $T = new HellFire::DataType( $self->dbh );
	#my $l = $T->get_languages();
	
	my $ret = {};
	foreach ( keys %$self )	{
		next if( $_ eq '_dbh' );
		next if( $_ eq '_guard' );
		if( $_ eq '_content' )	{
			$ret->{content} = $self->get_content( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_descriptions' )	{
			$ret->{description} = $self->get_description( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_keywords' )	{
			next;
		}
		elsif( $_ eq '_aliases' )	{
			$ret->{alias} = $self->get_alias( $self->guard->get_lang_id() );
			next;
		}
		elsif( $_ eq '_titles' )	{
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

sub get_access_list {
    my $self = shift;
    
    require HellFire::User::CategoryDAO;
	require HellFire::Configuration::ItemDAO;
	
    my $UC  = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	my $grp = $UC->get_all_siblings();
	$UC->set_name( 'guest' );
	$UC->set_id( 0 );
	push @$grp, $UC;
    
    my $I = new HellFire::Configuration::ItemDAO( $self->dbh, $self->guard );
	my $act = $I->get_action_list( $I->find( 'article_lib' ) );
    
    my @arr;
	foreach my $g ( @$grp ) {
		next if( $g->get_name() eq 'administrator' );

		foreach my $a ( @$act ) {
			if(  $a->{name} =~ /article_item/ )	{
				my $query = 'select 1 from article_item_access
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
	}
    return \@arr;
}

sub set_last_modified	{
	my $self = shift;
	$self->{_last_modified} = shift;
	return $self->{_last_modified};
}

sub get_last_modified	{
	my $self = shift;
	return $self->{_last_modified}||'';
}

return 1;
