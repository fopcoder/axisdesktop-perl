package HellFire::Site::ItemDAO;

use strict;
use base qw(HellFire::Site);

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
	unless( $self->is_unique( $n ) ) {
		$self->set_name( int( rand( 100000000 ) ) . '_' . $n );
	}

	return $self->get_name();
}

sub load {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	if( $self->guard->is_administrator() || $self->get_action( 'site_item_view' ) ) {
		my $query = 'select *, date_format(updated,"%a, %d %b %Y %H:%i:%s GMT") last_modified from site_items where id = ?';

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

		use HellFire::Site::CategoryDAO;
		my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $S->get_top_parent_id( $self->get_parent_id() );
		$prefix .= "/c/" . $self->get_parent_id();

		$query = 'select * from site_item_content where parent_id = ? ';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $id );

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_content( $h->{'lang_id'}, $h->{'content'} );
			$self->set_keywords( $h->{'lang_id'}, $h->{'keywords'} );
			$self->set_description( $h->{'lang_id'}, $h->{'description'} );
			$self->set_title( $h->{'lang_id'}, $h->{'title'} );

			my $path = $self->guard->ini->template_dir . "/$prefix/" . $self->get_content( $h->{lang_id} );
			my $c;
			if( $self->get_content( $h->{lang_id} ) && open( FILE, $path ) ) {
				$self->set_content_data( $h->{lang_id}, join( '', <FILE> ) );
				close FILE;
			}
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

	$self->dump();
}

sub add {
	my $self   = shift;
	my $params = shift;

	require HellFire::Site::CategoryDAO;
	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	$self->validate_name();

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from site_items where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	my $access = $C->get_action( 'site_item_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $access ) {
		my $query = 'insert into site_items(parent_id, name, ordering, inserted, flags, template_id, user_id, handler_id, updated, config) 
			values(?,?,?, now(),?, ?,?,?, now(),?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->get_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_template_id(), $self->guard->get_user_id(), $self->get_handler_id(), $self->get_config() );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$self->set_access( $id );

		my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $S->get_top_parent_id( $self->get_parent_id() );
		$prefix .= "/c/" . $self->get_parent_id();

		if( !-e $self->guard->ini->template_dir . "/$prefix" ) {
			my $dir = $self->guard->ini->template_dir . "/$prefix";
			`mkdir -p $dir`;
		}

		foreach ( keys %{ $self->{_aliases} } ) {
			my $file = int( rand( 10000000000 ) ) . '.tpl';
			open( FILE, ">" . $self->guard->ini->template_dir() . "/$prefix/" . $file ) or die $_;
			print FILE $self->get_content_data( $_ );
			close FILE;

			$query = 'insert into site_item_content( title, content, alias, keywords, description, lang_id, parent_id) values( ?, ?, ?, ?, ?, ?, ?)';
			$self->dbh->do( $query, undef, $self->get_title( $_ ), $file, $self->get_alias( $_ ), $self->get_keywords( $_ ), $self->get_description( $_ ), $_, $id );

			#	    }
		}

		$self->refresh_path( $id );
		return $id;
	}
	else {
		warn( 'cant create item: parent SYSTEM or DELETED' );
		return undef;
	}
}

sub update {
	my $self   = shift;
	my $params = shift;

	require HellFire::Site::CategoryDAO;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	my $access = $self->get_action( 'site_item_update' ) || $self->guard->is_administrator();

	if( $access && $self->get_id() && $self->get_parent_id() ) {
		my $query = 'update site_items set parent_id = ?, name = ?, template_id = ?, ordering = ?, flags = ?, handler_id = ?, updated = now(), config = ?  where id = ? ';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_template_id(), $self->get_ordering(), $self->flags_to_string(), $self->get_handler_id(), $self->get_config(), $self->get_id() );

		my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $S->get_top_parent_id( $self->get_parent_id() );
		$prefix .= "/c/" . $self->get_parent_id();

		if( !-e $self->guard->ini->template_dir . "/$prefix" ) {
			my $dir = $self->guard->ini->template_dir . "/$prefix";
			`mkdir -p $dir`;
		}

		foreach ( keys %{ $self->{_aliases} } ) {
			my $query = 'select * from site_item_content where lang_id = ? and parent_id = ?';
			my $C = $self->dbh->selectrow_hashref( $query, undef, $_, $self->get_id() );
			if( $C->{parent_id} ) {
				my $file = $C->{content} || int( rand( 10000000000 ) ) . '.tpl';
				my $path = $self->guard->ini->template_dir() . "/$prefix/" . $file;
				open( FILE, ">", $path ) or die $!;
				print FILE $self->get_content_data( $_ );
				close FILE;

				$query = 'update site_item_content set title = ?, alias = ?, content = ?, keywords = ?, description = ? where lang_id = ? and parent_id = ? ';
				$self->dbh->do( $query, undef, $self->get_title( $_ ), $self->get_alias( $_ ), $file, $self->get_keywords( $_ ), $self->get_description( $_ ), $_, $self->get_id() );

			}
			else {
				my $file = int( rand( 10000000000 ) ) . '.tpl';
				open( FILE, ">" . $self->guard->ini->template_dir() . "/$prefix/" . $file ) or die $_;
				print FILE $self->get_content_data( $_ );
				close FILE;

				$query = 'insert ignore into site_item_content( title, content, alias, keywords, description, lang_id, parent_id) values( ?, ?, ?, ?, ?, ?, ?)';
				$self->dbh->do( $query, undef, $self->get_title( $_ ), $file, $self->get_alias( $_ ), $self->get_keywords( $_ ), $self->get_description( $_ ), $_, $self->get_id() );
			}
		}

		$self->refresh_path();

		return 1;
	}
	else {
		return 0;
	}
}

sub move {
	my $self = shift;
	my $id = shift || 0;

	require HellFire::Site::CategoryDAO;
	if( $id ) {
		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $self->get_parent_id() );

		my $C2 = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$C2->load( $id );

		my $access = $self->guard->is_administrator() || ( $C->get_action( 'site_item_delete' ) && $C2->get_action( 'site_item_add' ) );

		if( $self->get_id() && $access && !$self->is_system ) {
			my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
			my $prefix1 = $S->get_top_parent_id( $self->get_parent_id() );
			$prefix1 .= "/c/" . $self->get_parent_id();

			my $prefix2 = $S->get_top_parent_id( $id );
			$prefix2 .= "/c/" . $id;

			if( !-e $self->guard->ini->template_dir . "/$prefix2" ) {
				my $dir = $self->guard->ini->template_dir . "/$prefix2";
				`mkdir -p $dir`;
			}

			foreach ( keys %{ $self->{_aliases} } ) {
				my $query = 'select * from site_item_content where lang_id = ? and parent_id = ?';
				my $C = $self->dbh->selectrow_hashref( $query, undef, $_, $self->get_id() );
				if( $C->{id} ) {
					my $file  = $C->{content};
					my $path1 = $self->guard->ini->template_dir() . "/$prefix1/" . $file;
					my $path2 = $self->guard->ini->template_dir() . "/$prefix2/" . $file;

					`mv $path1 $path2`;
				}
			}

			my $query = 'update site_items set parent_id = ? where id = ?';
			$self->dbh->do( $query, undef, $id, $self->get_id() );
			$self->set_parent_id( $id );

			#$self->save();

			$self->refresh_path;
			return 1;
		}
	}
	return undef;
}

sub copy {
	my $self   = shift;
	my $params = shift;

	my $access = $self->get_action( 'site_item_add' ) || $self->guard->is_administrator();
	if( $access && $self->get_id() ) {
		$self->set_id( 0 );
		$self->set_name( 'copy_' . $self->get_name() );
		$self->save();

		return 1;
	}

	return undef;
}

sub destroy {
	my $self   = shift;
	my $params = shift;

	require HellFire::File::ItemDAO;
	require HellFire::Site::CategoryDAO;
	require HellFire::DataType;

	my $access = $self->get_action( 'site_item_delete' ) || $self->guard->is_administrator();

	if( $self->get_id() && !$self->is_system() && !$self->is_locked() && $access ) {
		my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $S->get_top_parent_id( $self->get_parent_id() );
		$prefix .= "/c/" . $self->get_parent_id();

		my $query = 'select content from site_item_content  where parent_id = ?';
		my $sth   = $self->dbh->prepare( $query );
		$sth->execute( $self->get_id() );
		while ( my @arr = $sth->fetchrow_array() ) {
			if( -e $self->guard->ini->template_dir . "/$prefix/$arr[0]" && $arr[0] ) {
				my $dir = $self->guard->ini->template_dir . "/$prefix/$arr[0]";
				`rm $dir`;
			}
		}

		my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		my $ic = $F->find_by_prefix( 'site/item' );

		$query = 'select id from file_items where parent_id = ? and item_id = ?';
		$sth   = $self->dbh->prepare( $query );
		$sth->execute( $ic, $self->get_id() );
		while ( my @arr = $sth->fetchrow_array() ) {
			$F->load( $arr[0] );
			$F->destroy();
		}

		my $pp = int( $self->get_id() / 1000 );
		$prefix = 'site/item';
		my $path = $self->guard->ini->store_dir . "/$prefix/" . $pp . '/' . $self->get_id();
		`rmdir  $path`;

		$self->dbh->do( 'delete from site_item_content where parent_id = ?', undef, $self->get_id() );
		$self->dbh->do( 'delete from site_item_access where parent_id = ?',  undef, $self->get_id() );
		$self->dbh->do( 'delete from site_items where id = ?',               undef, $self->get_id() );

		return 1;
	}
	else {
		warn( 'delete_item: item not found' );
	}
}

sub is_unique {
	my $self = shift;

	if( $self->get_name() ) {
		my $query = 'select id from site_items where name = ? and parent_id = ?';
		my $id = $self->dbh->selectrow_array( $query, undef, $self->get_name(), $self->get_parent_id() );

		if( $id > 0 && $self->get_id() != $id ) {
			return undef;
		}

		return 1;
	}
	return undef;
}

#   for destroy
sub get_items {
	my $self = shift;

	my $query;

	if( $self->guard->is_administrator() ) {
		$query = 'select id from site_items where parent_id = ?';
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		$query = "select distinct i.id from site_items i 
		inner join site_item_access a on a.parent_id = i.id 
		inner join configuration_actions c on a.action_id = c.id
		where i.parent_id = ? and c.name = 'site_item_delete' and a.group_id in ( $grp )";
	}

	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $self->get_parent_id() );
	my @arr;

	while ( my $id = $sth->fetchrow_array() ) {
		my $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
		$I->load( $id );
		push @arr, $I;
	}
	return \@arr;
}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from site_items where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
	my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
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

	my $query = 'select count(*) from site_item_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->{_dbh}->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into site_item_access( parent_id, group_id, action_id ) 
			select ?, group_id, action_id from site_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub get_content_data {
	my $self = shift;
	my $val  = shift;

	return $self->{'_content_data'}->{$val} || '';
}

sub set_content_data {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_content_data'}->{$id} = $val;
	return $self->{'_content_data'}->{$id} || '';
}

sub refresh_path {
	my $self = shift;
	my $id = shift || $self->get_id();

	require HellFire::Site::CategoryDAO;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	#my $p = $C->refresh_path( $self->get_parent_id() );
	my $p = $C->get_path;
	$p .= '/' . $self->get_name();

	$self->{_dbh}->do( 'update site_items set path = ?, updated = now()  where id = ?', undef, $p, $id );

	return $p;
}

sub get_template_id {
	my $self = shift;
	return $self->{'_template_id'} || 0;
}

sub set_template_id {
	my $self = shift;
	$self->{'_template_id'} = shift;
	return $self->{'_template_id'};
}

sub get_content {
	my $self = shift;
	my $val  = shift;

	return $self->{'_contents'}->{$val} || '';
}

sub set_content {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_contents'}->{$id} = $val;
	return $self->{'_contents'}->{$id};
}

sub touch {
	my $self = shift;
	$self->dbh->do( 'update site_items set updated = now() where id = ?', undef, $self->get_id() );
}

sub get_history {
	my $self = shift;

	my $query = 'select inserted, user_id from site_history where parent_id = ? and type = "ITEM" order by inserted desc';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_id() );

	my @ret;
	while ( my $h = $sth->fetchrow_hashref ) {
		$h->{selected} = 1 if( $h->{inserted} eq $self->get_updated() );
		push @ret, $h;
	}

	return \@ret;
}

sub dump {
	my $self = shift;

	require Data::Dumper;
	$Data::Dumper::Indent = 0;
	my $g = $self->guard;
	$self->{_guard} = '';
	my $o = Data::Dumper->Dump( [$self] );

	my $query = 'insert into site_history(parent_id,inserted,user_id,type,object) values(?,now(),?,"ITEM",?)';
	$self->dbh->do( $query, undef, $self->get_id, $g->get_user_id, $o );

	$self->{_guard} = $g;

	return $o;
}

sub ordering	{
	my $self = shift;
	my $src = shift;
	my $dst = shift;
	
	if( $src && $dst && $self->get_parent_id() )	{
		my @i = split( /,/, $src );
		my $diff = scalar @i;
		my $dst_ord = 0;
		
		my $query = 'select id, ordering from site_items where parent_id = ? order by ordering';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $self->get_parent_id() );
		while( my $h = $sth->fetchrow_hashref() )	{
			$self->dbh->do('update site_items set ordering = ordering - ? where id = ?', undef, $diff * 10, $h->{id} );
			if( $h->{id} == $dst )	{
				$dst_ord = $h->{ordering};
				last;
			}
		}
		
		for( my $k = 0; $k < $diff; $k++ )	{
			$self->dbh->do('update site_items set ordering = ? where id = ?', undef, $dst_ord  - $k * 10, $i[ $k ] ) or die;
		}
	}
}

sub get_grid {
	my $self   = shift;
	my $params = shift;

	require HellFire::Site::ItemDAO;
	require HellFire::User::ItemDAO;
	require HellFire::DataType;

	my $T = new HellFire::DataType( $self->dbh );

	my $sl;

	push @$sl, $params->{parent_id};

	my @uselect;
	if( $self->guard->is_administrator() ) {
		@uselect = "( select id col, name value from site_items where parent_id in (" . join( ',', @$sl ) . ") and id = ? and find_in_set('DELETED',flags) = 0 )";
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		@uselect = "( select distinct i.id col, i.name value from site_items i inner join site_item_access a on a.parent_id = i.id inner join configuration_actions c on c.id = a.action_id 
			where i.parent_id in (" . join( ',', @$sl ) . ") and i.id = ? and find_in_set('DELETED',i.flags) = 0 
			and c.name = 'site_item_view' )"
	}

	my $cols = [];

	foreach ( @$cols ) {
		my $type_name = $T->get_type_name( $_->get_type_id() );
		push @uselect, "( select " . $_->get_id() . " col, value from site_values_" . $type_name . " use index(item_parent) where parent_id = " . $_->get_id() . " and item_id = ? and find_in_set('DELETED',flags) = 0 )";

	}

	my $wtfq = join( ' union ', @uselect );
	my $sth13 = $self->dbh->prepare( $wtfq );

	#warn("==   $wtfq  ===");

	my $query;
	my @all_collection;
	if( $self->guard->is_administrator() ) {
		$query = 'select id from site_items where parent_id in (' . join( ',', @$sl ) . ') and find_in_set("DELETED",flags) = 0';
	}
	else {
		$query = 'select distinct i.id from site_items i inner join site_item_access a on a.parent_id = i.id inner join configuration_actions c on c.id = a.action_id 
			where i.parent_id in (' . join( ',', @$sl ) . ') and find_in_set("DELETED",i.flags) = 0 and c.name = "site_item_view" ';
	}

	my $ref = $self->dbh->selectall_arrayref( $query );

	foreach ( @$ref ) {
		push @all_collection, $_->[0];
	}

	${ $params->{count_all} } = scalar @all_collection;

	undef $ref;

	my @order_collection;

	if( $self->guard->is_administrator() ) {
		$query = "select id from site_items  
	where parent_id in( " . join( ',', @$sl ) . " )  and find_in_set('DELETED',flags) = 0 
	order by  $params->{order_id} $params->{order_direction}";
	}
	else {
		$query = "select distinct i.id from site_items i inner join site_item_access a on a.parent_id = i.id inner join configuration_actions c on c.id = a.action_id
	where i.parent_id in( " . join( ',', @$sl ) . " )  and find_in_set('DELETED',i.flags) = 0 and c.name = 'site_item_view'
	order by  $params->{order_id} $params->{order_direction}";
	}

	$ref = $self->dbh->selectall_arrayref( $query );

	foreach ( @$ref ) {
		push @order_collection, $_->[0];
	}

	undef $ref;


	my %temp = ();
	@temp{@all_collection} = ();
	foreach ( @order_collection ) {
		delete $temp{$_};
	}

	my @diff_collection = keys %temp;
	undef %temp;

	@all_collection = undef;
	if( $params->{order_direction} eq 'desc' ) {
		@all_collection = @order_collection;
		push @all_collection, @diff_collection;
	}
	else {
		@all_collection = @diff_collection;
		push @all_collection, @order_collection;
	}

	my $to = $params->{offset} + $params->{limit} > scalar @all_collection ? scalar @all_collection : $params->{offset} + $params->{limit};
	my @arr;
	for( $params->{offset} .. $to - 1 ) {
		my @ids;
		push @ids, $all_collection[$_];
		for( my $i = 0 ; $i < scalar @$cols ; $i++ ) {
			push @ids, $all_collection[$_];
		}

		my @val;
		$sth13->execute( @ids );

		my %val13;
		my $item = $sth13->fetchrow_hashref();
		$item->{value} =~ s/\&/\&amp;/g;
		while ( my $hash13 = $sth13->fetchrow_hashref() ) {
			$val13{ $hash13->{col} } = $hash13->{value};
		}

		for( my $i = 0 ; $i < scalar @$cols ; $i++ ) {
			$val13{ $$cols[$i]->{id} } ||= '';
			$val13{ $$cols[$i]->{id} } =~ s/\&/\&amp;/g;
			$val13{ $$cols[$i]->{id} } =~ s/\</\&lt;/g;
			$val13{ $$cols[$i]->{id} } =~ s/\>/\&gt;/g;
			push @val, { value => $val13{ $$cols[$i]->{id} }, cdata => ( $$cols[$i]->{type_name} eq 'text' ? 1 : 0 ) };
		}

		my $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
		$I->load( $item->{col} );

		my $U = new HellFire::User::ItemDAO( $self->dbh, $self->guard );
		$U->load( $I->get_user_id() );

		#push @arr, { id => $item->{col}, alias => $item->{value}, title => $I->get_alias( $self->guard->get_lang_id() ) , values_loop => \@val };
		push @arr, {
			id => $item->{col},
			name => $item->{value},
			alias => $I->get_alias( $self->guard->get_lang_id() ),
			inserted => $I->get_inserted(),
			owner => $U->get_name(),
			ordering => $I->get_ordering()
		};
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
		if( $_ eq '_contents' )	{
			next;
		}
		elsif( $_ eq '_descriptions' )	{
			next;
		}
		elsif( $_ eq '_aliases' )	{
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
		$ret->{$k} = $self->$f;
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
	my $act = $I->get_action_list( $I->find( 'site_lib' ) );
    
    my @arr;
	foreach my $g ( @$grp ) {
		next if( $g->get_name() eq 'administrator' );

		foreach my $a ( @$act ) {
			if(  $a->{name} =~ /site_item/ )	{
				my $query = 'select 1 from site_item_access
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
