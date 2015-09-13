package HellFire::Article::CategoryDAO;

use strict;
use base qw(HellFire::Article);

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

	$self->reset();
	$self->set_id( $id );

	if( ( $self->guard->is_administrator() || $self->get_action( 'article_category_view' ) ) && $id ) {
		my $query = 'select * from article_categories where  find_in_set("DELETED", flags) = 0 and id = ?';
		my $h     = $self->dbh->selectrow_hashref( $query, undef, $id );
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
			$query = 'select lang_id, alias,title, keywords,description from article_category_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $params->{lang_id} );
		}
		else {
			$query = 'select lang_id, alias,title, keywords,description from article_category_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_title( $h->{'lang_id'}, $h->{'title'} );
			$self->set_keywords( $h->{'lang_id'}, $h->{'keywords'} );
			$self->set_description( $h->{'lang_id'}, $h->{'description'} );
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
	my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from article_categories where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	if( $C->get_action( 'article_category_add' ) || $self->guard->is_administrator() ) {
		my $query = 'insert into article_categories( parent_id, name, ordering, flags, inserted, user_id )
		values(?,?,?,?, now(),?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->guard->get_user_id() );
		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		foreach ( @$l ) {
			my $query = 'insert into article_category_aliases(parent_id,lang_id,alias,title,keywords,description) values(?,?,?,?,?,?)';
			$self->dbh->do( $query, undef, $id, $_->{id}, $self->get_alias( $_->{id} ), $self->get_title( $_->{id} ), $self->get_keywords( $_->{id} ), $self->get_description( $_->{id} ) );
		}

		#	if( grep(/^SLAVE$/, split( /,/, $self->{info}->{flags} ) ) )	{
		#	    $self->article_to_slave( { id => $id, parent_id => $self->get_parent() } );
		#	}

		$self->set_access( $id );
		$self->refresh_index();
		return $id;
	}

	return undef;
}

sub update {
	my $self = shift;

	require HellFire::DataType;
	my $access = $self->get_action( 'article_category_update' ) || $self->guard->is_administrator();
	if( $self->get_id() && $access ) {
		unless( $self->is_system() ) {
			my $query = 'update article_categories set name = ?, ordering = ?, flags = ? where id = ? ';
			$self->dbh->do( $query, undef, $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_id() );
		}

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		my $query = 'delete from article_category_aliases where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
		foreach ( @$l ) {
			my $query = 'insert into article_category_aliases(parent_id,lang_id,alias,title,keywords,description) values(?,?,?,?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ), $self->get_title( $_->{id} ), $self->get_keywords( $_->{id} ), $self->get_description( $_->{id} ) ) if( $self->get_alias( $_->{id} ) );
		}

		my $code = $self->get_group_access();
		foreach my $j ( @$code ) {
			foreach ( keys %$j ) {
				if( $_ =~ /field_(\d+)/ ) {
					if( $j->{$_} eq 'false' || $j->{$_} == 0 ) {
						$self->dbh->do( 'delete from article_category_access where parent_id = ? and group_id = ? and action_id = ?', undef, $self->get_id(), $j->{id}, $1 );
					}
					if( $j->{$_} eq 'true' || $j->{$_} > 0 ) {
						$self->dbh->do( 'insert into article_category_access(parent_id,group_id,action_id) values(?,?,?)', undef, $self->get_id(), $j->{id}, $1 );
					}
				}
			}
		}

		$self->refresh_index();

		#	if( grep(/^SLAVE$/, split( /,/, $self->{info}->{flags} ) ) )	{
		#	    $self->article_to_slave( { id => $id, parent_id => $self->get_parent() } );
		#	}

		return 1;
	}

	return undef;
}

sub reset	{
	my $self = shift;
	foreach ( keys %$self )	{
		next if( $_ eq '_dbh' || $_ eq '_guard' );
		delete $self->{$_};
	}
}

sub move {
	my $self = shift;
	my $point = shift || 'append';
	my $dst   = shift;

	my $DST = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$DST->load( $dst );
	
	unless( $point eq 'append' ) {
		$DST->load( $DST->get_parent_id() );
	}

	my $access = ( $self->get_action( 'article_category_delete' ) && $DST->get_action( 'article_category_add' ) ) || $self->guard->is_administrator();

	if( $self->get_id() && $access && !$self->is_system() ) {
		require HellFire::Article::FieldDAO;
		require HellFire::Article::ItemDAO;

		my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
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
					my $query = 'select id from article_items where parent_id in(' . $ids2 . ')';
					my $sth   = $self->dbh->prepare( $query );
					$sth->execute();
					while ( my @h = $sth->fetchrow_array ) {
						$query = 'update article_values_reference set parent_id = ? where item_id = ? and parent_id = ?';
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
					my $query = 'select id from article_items where parent_id in(' . $ids2 . ')';
					my $sth   = $self->dbh->prepare( $query );
					$sth->execute();
					while ( my @h = $sth->fetchrow_array ) {
						$query = 'update article_values_' . $type . ' set parent_id = ? where item_id = ? and parent_id = ?';
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
				my $query = 'select id from article_items where parent_id in(' . $ids2 . ')';
				my $sth   = $self->dbh->prepare( $query );
				$sth->execute();
				while ( my @h = $sth->fetchrow_array ) {
					$query = 'update article_values_' . $type . ' set parent_id = ? where item_id = ? and parent_id = ?';
					$self->dbh->do( $query, undef, $i->get_id(), $h[0], $old_id );
				}
			}
			if( $i->{__chk} == 2 ) {
				warn 'destroy: ' . $i->get_name() . ' ' . $i->get_id();
				$i->destroy();
			}
		}

		my $query = 'update article_categories set parent_id = ?, ordering = ? where id = ?';
		unless( $point eq 'append' ) {
			$DST->load( $dst );
			if( $point eq 'below' )	{
				$self->set_ordering( $DST->get_ordering() + 1);
			}
			else	{
				$self->set_ordering( $DST->get_ordering() - 1);
			}
			$self->dbh->do( $query, undef, $DST->get_parent_id(), $self->get_ordering(), $self->get_id() );
		}
		else	{
			$self->dbh->do( $query, undef, $DST->get_id(), $self->get_ordering(), $self->get_id() );
		}
		
		$self->refresh_index();
		$self->refresh_ordering();
		
		return 1;
	}
	
	return undef;
}

sub refresh_ordering	{
	my $self = shift;
	
	my $s = $self->get_all_siblings( $self->get_parent_id() );
	my $c = 0;
	foreach ( @$s )	{
		$_->set_ordering( $c );
		$_->save();
		$c += 10;
	}
}

sub copy {
	my $self = shift;

	my $access = $self->get_action( 'article_category_update' ) || $self->guard->is_administrator();
	if( $self->get_id() && $access ) {
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $self->get_id() );
		$C->set_id( 0 );
		$C->save();

		require HellFire::Article::FieldDAO;

		my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
		$F->set_parent_id( $self->get_id() );
		my $srcf = $F->get_fields();
		foreach ( @$srcf ) {
			$_->copy( { parent_id => $C->get_id() } );
		}

		return $C;
	}

	return undef;
}

sub get_all_siblings {
	my $self   = shift;
	my $id     = shift || 0;
	my $params = shift;

	my $query;
	if( $self->guard->is_administrator() ) {
		$query = 'select id from article_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?  order by ordering';
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		$query = 'select r.id from article_categories r inner join article_category_access a on a.parent_id = r.id 
				inner join configuration_actions c on c.id = a.action_id
				where find_in_set("DELETED", r.flags) = 0 and r.parent_id = ? and c.name = "article_item_view" and a.group_id in(' . $grp . ') 
				order by r.ordering';
	}

	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $id );

	if( $params->{ return_hashref } )	{
		my $h;
		while ( my @arr = $sth->fetchrow_array() ) {
			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
			$C->load( $arr[0], $params );
			$h->{ $C->get_id() } = $C;
		}
		return $h;
	}
	else	{
		my @obj;
		while ( my @arr = $sth->fetchrow_array() ) {
			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
			$C->load( $arr[0], $params );
			push @obj, $C;
		}
		return \@obj;
	}
}

sub count_children {
	my $self = shift;

	my @arr;
	@arr = $self->dbh->selectrow_array(
		'select count(*) from article_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?', undef, $self->get_id()
	);

=head
	if( $self->guard->is_administrator() )  {
	@arr = $self->dbh->selectrow_array('select count(*) from article_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?', undef, $self->get_id() );
	}
	else    {
	my $grp = join(',',@{$self->guard->get_groups()}, 0);
	@arr = $self->dbh->selectrow_array('select count(*) from article_categories r 
		inner join article_category_access a on a.parent_id = r.id 
		inner join configuration_actions c on c.id = a.action_id
		where find_in_set("DELETED", r.flags) = 0 and r.parent_id = ?  and c.name = "article_item_view" and a.group_id in('.$grp.') ', undef, $self->get_id() );
	}
=cut    

	return $arr[0];
}

sub refresh_index {
	my $self = shift;
	my $id   = shift || 0;
	my $ind  = shift || 0;

	my $query = 'select id from article_categories where parent_id = ? order by ordering';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $id );
	while ( my @w = $sth->fetchrow_array() ) {
		$ind++;
		$self->dbh->do( 'update article_categories set index_left = ? where id = ?', undef, $ind, $w[0] );
		$ind = $self->refresh_index( $w[0], $ind );
		$ind++;
		$self->dbh->do( 'update article_categories set index_right = ? where id = ?', undef, $ind, $w[0] );
	}

	return $ind;
}

sub is_unique {
	my $self = shift;
	my $name = shift || '';

	if( length $name > 0 ) {
		my $query = 'select id from article_categories where name = ? and parent_id = ?';
		my $id = $self->dbh->selectrow_array( $query, undef, $name, $self->get_parent_id() );

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

	my $query = 'select count(*) from article_category_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into article_category_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from article_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub destroy {
	my $self = shift;

	require HellFire::Article::FieldDAO;
	require HellFire::Article::ItemDAO;

	my $ac = $self->get_all_children();
	push @$ac, $self;
	foreach my $c ( @$ac ) {
		my $ch = $c->count_children();
		next if $ch;

		if( ( $c->get_action( 'article_category_delete' ) || $self->guard->is_administrator() ) && !$c->is_system() ) {
			my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
			$F->set_parent_id( $c->get_id() );
			my $af = $F->get_fields();

			my $I = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
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

			my $query = 'delete from article_category_aliases where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
			$query = 'delete from article_category_access where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
			$query = 'delete from article_categories where id = ?';
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

sub get_flat_references {
	my $self      = shift;
	my $parent_id = shift || 0;
	my $prefix    = shift || '';
	my $arr       = shift;

	my $query = 'select c.id id, if(length(a.alias)>0,a.alias,c.name) name 
		from article_categories c left join article_category_aliases a
		on a.parent_id = c.id and a.lang_id = ?  
		where c.parent_id  = ? and find_in_set("DELETED",c.flags) = 0 order by c.ordering';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $self->guard->get_lang_id(), $parent_id );
	while ( my $hash = $sth->fetchrow_hashref() ) {

		#my $p = "$prefix.".$hash->{name} ;
		#$p =~ s/^\.//;
		my $p = "$prefix...";
		push @$arr, { id => $hash->{id}, alias => $p . $hash->{name} };
		$self->get_flat_references( $hash->{id}, $p, $arr );
	}
}

sub get_parent_inherit_list {
	my $self = shift;
	my $id   = shift;
	my @ret;
	my $dbh = $self->dbh;

	my $query = 'select parent_id from article_categories 
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

	my $query = 'select source_id from article_sources where category_id = ?';
	my @ret;
	my $sth = $self->{'dbh'}->prepare( $query );
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

	my $query = 'select parent_id from article_categories 
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

	my $query = 'select id, index_right-index_left c from article_categories where index_left > ? and index_right < ? order by c';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_index_left(), $self->get_index_right() );
	my @arr;

	while ( my @a = $sth->fetchrow_array() ) {
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $a[0], $params );
		push @arr, $C;
	}

	return \@arr;
}

sub get_subfolders	{
	my $self = shift;
	my $params = shift;
	
	my $query = 'select id from article_categories where find_in_set("DELETED",flags) = 0 and find_in_set("HIDDEN",flags) = 0 and parent_id = ? order by ordering desc';
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $self->get_id() );
	my @res;
	while( my $h = $sth->fetchrow_hashref() )	{
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $h->{id}, { no_clean => 1, lang_id => $self->guard->get_lang_id() } );
		push @res, $C->to_template();
		$res[-1]->{href} = $params->{href};
		$res[-1]->{href} .= '/' unless( $res[-1]->{href} =~ /\/$/);
		$res[-1]->{href} .= $res[-1]->{name};
	}
	
	return \@res;
}

sub get_all_children_id {
	my $self = shift;

	my $query = 'select id, index_right-index_left c from article_categories where index_left > ? and index_right < ? order by c';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_index_left(), $self->get_index_right() );
	my @arr;

	while ( my @a = $sth->fetchrow_array() ) {
		push @arr, $a[0];
	}

	return \@arr;
}

#sub get_grid1 {
#	my $self   = shift;
#	my $params = shift;
#	my $dbh    = $self->dbh;
#
#	require HellFire::Article::FieldDAO;
#
#	my $cols;
#	unless( $params->{no_fields} ) {
#		if( $params->{fields} ) {
#			$cols = $params->{fields};
#		}
#		else {
#			my $F = new HellFire::Article::FieldDAO( $dbh, $self->guard );
#			$F->set_parent_id( $params->{parent_id} );
#			$cols = $F->get_fields( $params );
#		}
#	}
#
#	my $sl;    # = $Ref->get_source_list( $params->{parent_id} );
#
#	push @$sl, $params->{parent_id};
#	my $lid = $self->guard->get_lang_id() || 0;
#
#	my $uselect2 = 'select i.name, if(isnull(a.alias),i.name,a.alias) value ';
#	$uselect2 .=  ', inserted, year(inserted) inserted_year, day(inserted) inserted_day, month(inserted) inserted_month ' if( $params->{with_inserted} );
#    $uselect2 .=  ', user_id ' if( $params->{with_user_id} );
#	my $SF;
#
#	foreach ( @$cols ) {
#		my $type_name = $_->get_type();
#
#		if( $type_name eq 'reference' ) {
#			$uselect2 .= ", ( select group_concat(value) from article_values_reference  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
#		}
#		else {
#			$uselect2 .= ", ( select value from article_values_" . $type_name . "  where parent_id = " . $_->get_id() . " and item_id = \@_id and find_in_set('DELETED',flags) = 0 ) __f" . $_->get_id();
#		}
#
#		if( $_->get_name eq $params->{order_id} ||
#			$_->get_id eq $params->{order_id} 
#			)	{
#			$SF = $_;
#		}
#	}
#	$uselect2 .= " from article_items i left join article_item_aliases a 
#				on a.parent_id = i.id and a.lang_id = $lid
#				where i.id = \@_id and find_in_set('DELETED',i.flags) = 0 ";
#
#	my $sth13 = $dbh->prepare( $uselect2 );
#
#	my @all_collection;
#
#	my $id_in;
#	if( $params->{id_in} ) {
#		$id_in .= ' and id in(' . join( ',', @{ $params->{id_in} } ) . ') ';
#	}
#
#	#if( $params->{id_not_in} )	{
#	#	$id_in .= ' and id not in('.join(',',@{$params->{id_not_in}}).') ';
#	#}
#
#	my $query = 'select id from article_items where parent_id in (' . join( ',', @$sl ) . ') and find_in_set("DELETED",flags) = 0 ' . $id_in;
#
#	my $ref = $dbh->selectall_arrayref( $query );
#
#	foreach ( @$ref ) {
#		push @all_collection, $_->[0];
#	}
#
#	${ $params->{count_all} } = scalar @all_collection;
#
#	undef $ref;
#
#	my @order_collection;
#
#	if( $params->{order_id} eq 'id' || $params->{order_id} eq 'name' || $params->{order_id} eq 'inserted' ) {
#		$query = "select id from article_items  
#			where parent_id in( " . join( ',', @$sl ) . " )  and find_in_set('DELETED',flags) = 0 $id_in  
#			order by  $params->{order_id} $params->{order_direction}";
#		my $ref = $dbh->selectall_arrayref( $query );
#
#		foreach ( @$ref ) {
#			push @order_collection, $_->[0];
#		}
#
#		undef $ref;
#
#	}
#	elsif( $params->{order_id} eq 'alias' ) {
#		$query = "select i.id from article_items i inner join article_item_aliases a on a.parent_id = i.id and a.lang_id = $lid  
#			where i.parent_id in( " . join( ',', @$sl ) . " )  and find_in_set('DELETED',i.flags) = 0 $id_in 
#			order by a.alias $params->{order_direction}";
#		my $ref = $dbh->selectall_arrayref( $query );
#
#		foreach ( @$ref ) {
#			push @order_collection, $_->[0];
#		}
#
#		undef $ref;
#
#	}
#	elsif( $params->{order_id} eq 'rand' ) {
#		$query = "select id from article_items  
#			where parent_id in( " . join( ',', @$sl ) . " )  and find_in_set('DELETED',flags) = 0 $id_in 
#			order by rand()";
#		my $ref = $dbh->selectall_arrayref( $query );
#
#		foreach ( @$ref ) {
#			push @order_collection, $_->[0];
#		}
#
#		undef $ref;
#
#	}
#	elsif( $params->{order_id} ) {
#		my $type_name = $SF->get_type();
#		$query = "select i.id 
#			from article_items i use index(id_parent), 
#				 article_values_$type_name v use index(parent_value) 
#					 where v.item_id=i.id and v.parent_id = ? and i.parent_id in(" . join( ',', @$sl ) . ") and find_in_set('DELETED',i.flags) = 0 and find_in_set('DELETED',v.flags) = 0 $id_in 
#					 order by  v.value $params->{order_direction} ";
#		my $ref = $dbh->selectall_arrayref( $query, undef, $SF->get_id );
#
#		foreach ( @$ref ) {
#			push @order_collection, $_->[0];
#		}
#
#		undef $ref;
#	}
#	else {
#		$query = "select id from article_items use index(parent_ordering) 
#			where parent_id in( ? ) and find_in_set('DELETED',flags) = 0 $id_in 
#			order by  ordering desc";
#		my $ref = $dbh->selectall_arrayref( $query, undef, $params->{parent_id} );
#
#		foreach ( @$ref ) {
#			push @order_collection, $_->[0];
#		}
#
#		undef $ref;
#	}
#
#	my %temp = ();
#	@temp{@all_collection} = ();
#	foreach ( @order_collection ) {
#		delete $temp{$_};
#	}
#
#	my @diff_collection = keys %temp;
#	undef %temp;
#
#	@all_collection = undef;
#	if( lc $params->{order_direction} eq 'desc' ) {
#		@all_collection = @order_collection;
#		push @all_collection, @diff_collection;
#	}
#	else {
#		@all_collection = @diff_collection;
#		push @all_collection, @order_collection;
#	}
#
#	my $to = $params->{offset} + $params->{limit} > scalar @all_collection ? scalar @all_collection : $params->{offset} + $params->{limit};
#	my @arr;
#	for( $params->{offset} .. $to - 1 ) {
#		my @val;
#		$dbh->do( 'set @_id = ?', undef, $all_collection[$_] );
#		$sth13->execute();
#
#		my $item = $sth13->fetchrow_hashref();
#		$item->{value} =~ s/\&/\&amp;/g;
#
#		for( my $i = 0 ; $i < scalar @$cols ; $i++ ) {
#			$item->{ '__f' . $$cols[$i]->get_id() } ||= '';
#			$item->{ '__f' . $$cols[$i]->get_id() } =~ s/\&/\&amp;/g;
#
#			#$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\</\&lt;/g;
#			#$item->{ '__f'.$$cols[$i]->get_id() } =~ s/\>/\&gt;/g;
#
#			my $type_name = $$cols[$i]->get_type();
#			if( $type_name eq 'reference' ) {
#				$item->{ '__f' . $$cols[$i]->get_id() } =
#				  $self->dbh->selectrow_array( 'call base_get_reference_valuep(?,?,?,?,?)', undef, $$cols[$i]->get_source_group_id(), $$cols[$i]->get_source_id(), $$cols[$i]->get_source_field_id(), $self->guard->get_lang_id() || 1, $item->{ '__f' . $$cols[$i]->get_id() } || 0 );
#			}
#			push @val,
#			  {
#				value                  => $item->{ '__f' . $$cols[$i]->get_id() },
#				cdata                  => ( $type_name eq 'text' ? 1 : 0 ),
#				$$cols[$i]->get_name() => 1,
#				name                   => $$cols[$i]->get_name(),
#				item_id                => $all_collection[$_],
#				item_name              => $item->{name}
#			  };
#		}
#		push @arr, { id => $all_collection[$_], alias => $item->{value}, name => $item->{name}, values => \@val };
#	}
#
#	return \@arr;
#}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from article_categories where name = ? and parent_id = ?';
	my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
}

sub clear_access {
	my $self = shift;

	if( $self->get_id() ) {
		my $query = 'delete from article_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
	}
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
			my $query = 'select 1 from article_category_access
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

sub to_template {
	my $self = shift;
	
	#require HellFire::DataType;
	#my $T = new HellFire::DataType( $self->dbh );
	#my $l = $T->get_languages();
	
	my $ret = {};
	foreach ( keys %$self )	{
		next if( $_ eq '_dbh' );
		next if( $_ eq '_guard' );
		if( $_ eq '_descriptions' )	{
			$ret->{description} = $self->get_description( $self->guard->get_lang_id() );
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


return 1;
