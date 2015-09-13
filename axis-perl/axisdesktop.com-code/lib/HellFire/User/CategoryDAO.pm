package HellFire::User::CategoryDAO;

use strict;
use base qw(HellFire::User);

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}      = $dbh;
	$self->{'_guard'}    = $G;
	$self->{'_children'} = undef;

	bless $self, $class;
	return $self;
}

sub get_children {
	my $self = shift;
	return $self->{'_children'} || 0;
}

sub set_children {
	my $self = shift;
	$self->{'_children'} = shift;
	return $self->{'_children'};
}

sub set_group_access {
	my $self = shift;
	$self->{'_gaccess'} = shift;
	return $self->{'_gaccess'};
}

sub get_group_access {
	my $self = shift;
	return $self->{'_gaccess'};
}

sub validate_name {
	my $self = shift;

	my $n = $self->get_name();
	unless( $self->is_unique( $n ) ) {
		$self->set_name( $n . '_' . int( rand( 100000000 ) ) );
	}

	return $self->get_name();
}

sub get_index_left {
	my $self = shift;
	return $self->{'_index_left'};
}

sub set_index_left {
	my $self = shift;
	$self->{'_index_left'} = shift;
	return $self->{'_index_left'};
}

sub get_index_right {
	my $self = shift;
	return $self->{'_index_right'};
}

sub set_index_right {
	my $self = shift;
	$self->{'_index_right'} = shift;
	return $self->{'_index_right'};
}

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	if( ( $self->guard->is_administrator() || $self->get_action( 'user_category_view' ) ) && $id ) {
		my $query = 'select * from user_categories where  find_in_set("DELETED", flags) = 0 and id = ?';
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
			$query = 'select lang_id, alias from user_category_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $params->{lang_id} );
		}
		else {
			$query = 'select lang_id, alias from user_category_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
		}

		$self->set_children( $self->count_children() );

		return 1;
	}
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

	require HellFire::DataType;
	my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	$self->set_parent_id(0);

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from user_categories where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	if( $C->get_action( 'user_category_add' ) || $self->guard->is_administrator() ) {
		my $query = 'insert into user_categories( parent_id, name, ordering, flags, inserted )
		values(?,?,?,?, now())';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string() );
		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		foreach ( @$l ) {
			my $query = 'insert into user_category_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$self->dbh->do( $query, undef, $id, $_->{id}, $self->get_alias( $_->{id} ) ) if( $self->get_alias( $_->{id} ) );
		}

		$self->set_access( $id );
		$self->refresh_index();
		return $id;
	}

	return undef;
}

sub update {
	my $self = shift;

	$self->set_name( 'everybody' )      if( $self->get_id() == 1 );
	$self->set_name( 'administrators' ) if( $self->get_id() == 2 );

	require HellFire::DataType;
	if( $self->get_action( 'user_category_update' ) || $self->guard->is_administrator() ) {
		unless( $self->is_system() ) {
			my $query = 'update user_categories set name = ?, ordering = ?, flags = ? where id = ? ';
			$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_id() );
		}

		my $T     = new HellFire::DataType( $self->dbh );
		my $l     = $T->get_languages();
		my $query = 'delete from user_category_aliases where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
		foreach ( @$l ) {
			my $query = 'insert into user_category_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ) ) if( $self->get_alias( $_->{id} ) );
		}

		my $code = $self->get_group_access();
		foreach my $j ( @$code ) {
			foreach ( keys %$j ) {
				if( $_ =~ /field_(\d+)/ ) {
					if( $j->{$_} eq 'false' || $j->{$_} == 0 ) {
						$self->dbh->do( 'delete from user_category_access where parent_id = ? and group_id = ? and action_id = ?', undef, $self->get_id(), $j->{id}, $1 );
					}
					if( $j->{$_} eq 'true' || $j->{$_} > 0 ) {
						$self->dbh->do( 'insert into user_category_access(parent_id,group_id,action_id) values(?,?,?)', undef, $self->get_id(), $j->{id}, $1 );
					}
				}
			}
		}

		$self->refresh_index();

		#	if( grep(/^SLAVE$/, split( /,/, $self->{info}->{flags} ) ) )	{
		#	    $self->user_to_slave( { id => $id, parent_id => $self->get_parent() } );
		#	}

		return 1;
	}

	return undef;
}

sub move {
	my $self  = shift;
	my $point = shift || 'append';
	my $dst   = shift;

	if( $self->get_id() == 1 || $self->get_id() == 2 ) {
		return;
	}

	my $DST = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	$DST->load( $dst );

	unless( $point eq 'append' ) {
		$DST->load( $DST->get_parent_id() );
	}

	my $access = ( $self->get_action( 'user_category_delete' ) && $DST->get_action( 'user_category_add' ) ) || $self->guard->is_administrator();

	if( $self->get_id() && $access && !$self->is_system() ) {
		require HellFire::User::FieldDAO;
		require HellFire::User::ItemDAO;

		my $F = new HellFire::User::FieldDAO( $self->dbh, $self->guard );
		$F->set_parent_id( $self->get_id() );
		my $srcf = $F->get_fields();

		$F->set_parent_id( $DST->get_id() );
		my $dstf = $F->get_fields();

		my $ids = $self->get_all_children_id();
		my $ids2 = join( ',', @$ids, $self->get_id() );

		foreach my $i ( @$srcf ) {
			foreach my $j ( @$dstf ) {
				if(
					   $i->get_source_id() == $j->get_source_id
					&& $i->get_source_group_id() == $j->get_source_group_id
					&& $i->get_source_id() > 0
					&& $i->get_source_group_id() > 0
					&& $j->is_inherit
					&& $self->is_inherit
					&&

					#$i->get_parent_id() != $self->get_id() )	{
					$i->get_name() eq $j->get_name()
				  )
				{
					my $query = 'select id from user_items where parent_id in(' . $ids2 . ')';
					my $sth   = $self->dbh->prepare( $query );
					$sth->execute();
					while ( my @h = $sth->fetchrow_array ) {
						$query = 'update user_values_user set parent_id = ? where item_id = ? and parent_id = ?';
						$self->dbh->do( $query, undef, $j->get_id(), $h[0], $i->get_id() );
					}
					$i->{__chk} = 1;
					$i->{__chk} = 2 if( $i->get_parent_id() == $self->get_id() );
				}
				elsif( $i->get_type_id() == $j->get_type_id()
					&& $j->is_inherit
					&& $self->is_inherit
					&& $i->get_id() != $j->get_id()
					&& $i->get_name() eq $j->get_name() )
				{
					$i->{__chk} = 2;
					my $type  = $i->get_type();
					my $query = 'select id from user_items where parent_id in(' . $ids2 . ')';
					my $sth   = $self->dbh->prepare( $query );
					$sth->execute();
					while ( my @h = $sth->fetchrow_array ) {
						$query = 'update user_values_' . $type . ' set parent_id = ? where item_id = ? and parent_id = ?';
						$self->dbh->do( $query, undef, $j->get_id(), $h[0], $i->get_id() );
					}

				}
				elsif( $i->get_type_id() == $j->get_type_id()
					&& $i->get_name() eq $j->get_name()
					&& $j->is_inherit
					&& $i->get_id() == $j->get_id() 
					&& $self->is_inherit
					 )
				{
					$i->{__chk} = 1;
				}
			}
			if( $i->get_parent_id() == $self->get_id() && !$i->{__chk} ) {
				$i->{__chk} = 1;
			}
		}
		foreach my $i ( @$srcf ) {
			unless( $i->{__chk} ) {
				my $type   = $i->get_type();
				my $old_id = $i->get_id();

				$i->set_parent_id( $self->get_id() );
				$i->set_id( 0 );
				$i->save();

				my $ids   = $self->get_all_children_id();
				my $ids2  = join( ',', @$ids, $self->get_id() );
				my $query = 'select id from user_items where parent_id in(' . $ids2 . ')';
				my $sth   = $self->dbh->prepare( $query );
				$sth->execute();
				while ( my @h = $sth->fetchrow_array ) {
					$query = 'update user_values_' . $type . ' set parent_id = ? where item_id = ? and parent_id = ?';
					$self->dbh->do( $query, undef, $i->get_id(), $h[0], $old_id );
				}

				warn '----- ' . $i->get_name();
			}
			if( $i->{__chk} == 2 ) {
				warn 'destroy: ' . $i->get_name() . ' ' . $i->get_id();
				$i->destroy();
			}
		}

		#my $I = new HellFire::User::ItemDAO( $self->dbh, $self->guard );
		#$I->set_parent_id( $c->get_id() );
		#my $ai = $I->get_items();

		my $query = 'update user_categories set parent_id = ?, ordering = ? where id = ?';
		$self->dbh->do( $query, undef, $DST->get_id(), $self->get_ordering(), $self->get_id() );
		$self->refresh_index();
		return 1;
	}
	$self->refresh_index();
	return undef;
}

sub get_all_siblings {
	my $self   = shift;
	my $id     = shift || 0;
	my $params = shift;

	my $query;
	if( $self->guard->is_administrator() ) {
		$query = 'select id from user_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?  order by ordering';
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		$query = 'select r.id from user_categories r inner join user_category_access a on a.parent_id = r.id 
				inner join configuration_actions c on c.id = a.action_id
				where find_in_set("DELETED", r.flags) = 0 and r.parent_id = ? and c.name = "user_item_view" and a.group_id in(' . $grp . ') 
				order by r.ordering';
	}

	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $id );

	my @obj;
	while ( my @arr = $sth->fetchrow_array() ) {
		my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $arr[0], $params );
		push @obj, $C;
	}

	return \@obj;
}

sub count_children {
	my $self = shift;

	my @arr;
	@arr = $self->dbh->selectrow_array(
		'select count(*) from user_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?', undef, $self->get_id()
	);

=head
	if( $self->guard->is_administrator() )  {
	@arr = $self->dbh->selectrow_array('select count(*) from user_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?', undef, $self->get_id() );
	}
	else    {
	my $grp = join(',',@{$self->guard->get_groups()}, 0);
	@arr = $self->dbh->selectrow_array('select count(*) from user_categories r 
		inner join user_category_access a on a.parent_id = r.id 
		inner join configuration_actions c on c.id = a.action_id
		where find_in_set("DELETED", r.flags) = 0 and r.parent_id = ?  and c.name = "user_item_view" and a.group_id in('.$grp.') ', undef, $self->get_id() );
	}
=cut    

	return $arr[0];
}

sub refresh_index {
	my $self = shift;
	my $id   = shift || 0;
	my $ind  = shift || 0;

	my $query = 'select id from user_categories where parent_id = ? order by ordering';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $id );
	while ( my @w = $sth->fetchrow_array() ) {
		$ind++;
		$self->dbh->do( 'update user_categories set index_left = ? where id = ?', undef, $ind, $w[0] );
		$ind = $self->refresh_index( $w[0], $ind );
		$ind++;
		$self->dbh->do( 'update user_categories set index_right = ? where id = ?', undef, $ind, $w[0] );
	}

	return $ind;
}

sub is_unique {
	my $self = shift;
	my $name = shift || '';

	if( length $name > 0 ) {
		my $query = 'select id from user_categories where name = ?';
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

	my $query = 'select count(*) from user_category_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into user_category_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from user_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub destroy {
	my $self = shift;

	if( $self->get_id() == 1 || $self->get_id() == 2 ) {
		return undef;
	}

	require HellFire::User::FieldDAO;
	require HellFire::User::ItemDAO;

	my $ac = $self->get_all_children();
	push @$ac, $self;
	foreach my $c ( @$ac ) {
		my $ch = $c->count_children();
		next if $ch;

		if( ( $c->get_action( 'user_category_delete' ) || $self->guard->is_administrator() ) && !$c->is_system() ) {
			my $F = new HellFire::User::FieldDAO( $self->dbh, $self->guard );
			$F->set_parent_id( $c->get_id() );
			my $af = $F->get_fields();

			my $I = new HellFire::User::ItemDAO( $self->dbh, $self->guard );
			$I->set_parent_id( $c->get_id() );
			my $ai = $I->get_items();

			my $res = 1;
			foreach my $i ( @$ai ) {
				$res &&= $i->destroy();
			}

			next unless( $res );

			$res = 1;
			foreach my $f ( @$af ) {
				$res &&= $f->destroy() if( $f->get_parent_id() == $c->get_id() );
			}

			next unless( $res );

			my $query = 'delete from user_category_aliases where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
			$query = 'delete from user_category_access where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
			$query = 'delete from user_categories where id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
			undef $c;
		}

	}

	$self->refresh_index();

	if( defined $self ) {
		return undef;
	}
	else {
		return 1;
	}

}

#====================================================================

sub get_flat_users {
	my $self      = shift;
	my $parent_id = shift || 0;
	my $prefix    = shift || '';
	my $arr       = shift;

	my $query = 'select c.id id, if(length(a.alias)>0,a.alias,c.name) name 
		from user_categories c left join user_category_aliases a
		on a.parent_id = c.id and a.lang_id = ?  
		where c.parent_id  = ? and find_in_set("DELETED",c.flags) = 0 order by c.ordering';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $self->guard->get_lang_id(), $parent_id );
	while ( my $hash = $sth->fetchrow_hashref() ) {

		#my $p = "$prefix.".$hash->{name} ;
		#$p =~ s/^\.//;
		my $p = "$prefix...";
		push @$arr, { id => $hash->{id}, alias => $p . $hash->{name} };
		$self->get_flat_users( $hash->{id}, $p, $arr );
	}
}

sub get_parent_inherit_list {
	my $self = shift;
	my $id   = shift;
	my @ret;
	my $dbh = $self->dbh;

	my $query = 'select parent_id from user_categories 
			where id = ? and find_in_set("DELETED",flags) = 0 and find_in_set("INHERIT",flags) > 0';
	my @arr = $dbh->selectrow_array( $query, undef, $id );

	if( $arr[0] > 0 ) {
		my $rr = $self->get_parent_inherit_list( $arr[0] );
		@ret = @$rr;
		push @ret, $arr[0];
	}

	return \@ret;
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

sub get_parent_list {
	my $self = shift;
	my $id   = shift;
	my @ret;

	my $query = 'select parent_id from user_categories 
			where id = ? and find_in_set("DELETED",flags) = 0 ';
	my @arr = $self->{dbh}->selectrow_array( $query, undef, $id );

	if( $arr[0] > 0 ) {
		my $rr = $self->get_parent_list( $arr[0] );
		@ret = @$rr;
		push @ret, $arr[0];
	}

	return \@ret;
}

sub get_all_children {
	my $self   = shift;
	my $params = shift;

	my $query = 'select id, index_right-index_left c from user_categories where index_left > ? and index_right < ? order by c';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_index_left(), $self->get_index_right() );
	my @arr;

	while ( my @a = $sth->fetchrow_array() ) {
		my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $a[0], $params );
		push @arr, $C;
	}

	return \@arr;
}

sub get_all_children_id {
	my $self = shift;

	my $query = 'select id, index_right-index_left c from user_categories where index_left > ? and index_right < ? order by c';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_index_left(), $self->get_index_right() );
	my @arr;

	while ( my @a = $sth->fetchrow_array() ) {
		push @arr, $a[0];
	}

	return \@arr;
}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from user_categories where name = ? and parent_id = ?';
	my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
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

sub get_access_list {
	my $self = shift;

	require HellFire::User::CategoryDAO;
	require HellFire::Configuration::ItemDAO;

	my $UC = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	my $grp = $UC->get_all_siblings();
	$UC->set_name( 'guest' );
	$UC->set_id( 0 );
	push @$grp, $UC;

	my $I = new HellFire::Configuration::ItemDAO( $self->dbh, $self->guard );
	my $act = $I->get_action_list( $I->find( 'user_lib' ) );

	my @arr;
	foreach my $g ( @$grp ) {
		next if( $g->get_name() eq 'administrator' );

		foreach my $a ( @$act ) {
			my $query = 'select 1 from user_category_access
						where parent_id = ? and group_id = ? and action_id = ?';
			my $h = {
				group     => $g->get_name(),
				group_id  => $g->get_id(),
				action    => $a->{name},
				action_id => $a->{id},
				value     => $self->dbh->selectrow_array( $query, undef, $self->get_id(), $g->get_id(), $a->{id} ) || 0
			};

			push @arr, $h;
		}
	}
	return \@arr;
}

return 1;
