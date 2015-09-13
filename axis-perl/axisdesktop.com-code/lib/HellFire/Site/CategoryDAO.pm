package HellFire::Site::CategoryDAO;

use strict;
use base qw(HellFire::Site);

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

sub get_children {
	my $self = shift;
	return $self->{'_children'} || 0;
}

sub set_children {
	my $self = shift;
	my $val = shift || 0;

	$self->{'_children'} = $val;
	return $self->{'_children'};
}

sub count_children {
	my $self = shift;

	my @arr = $self->dbh->selectrow_array(
		'select count(*) from site_categories  
		where find_in_set("DELETED", flags) = 0 and parent_id = ?', undef, $self->get_id()
	);
	return $arr[0];
}

sub load {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );
	my $query;

	if( ( $self->guard->is_administrator() || $self->get_action( 'site_category_view' ) ) && $id ) {
		$query = 'select * from site_categories  where find_in_set("DELETED", flags) = 0 and id = ? ';
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

		$query = 'select * from site_category_aliases where parent_id = ? ';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $id );

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_title( $h->{'lang_id'}, $h->{'title'} );
			$self->set_keywords( $h->{'lang_id'}, $h->{'keywords'} );
			$self->set_description( $h->{'lang_id'}, $h->{'description'} );
		}

		$self->set_children( $self->count_children() );

		return $self->get_id();
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

sub get_all_siblings {
	my $self = shift;
	my $id = shift || 0;

	my $query;
	if( $self->guard->is_administrator() ) {
		$query = 'select id from site_categories 
		where find_in_set("DELETED", flags) = 0 and parent_id = ?  order by ordering';
	}
	else {
		my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
		$query = 'select id from site_categories c inner join site_category_access a on a.parent_id = c.id 
		where find_in_set("DELETED", c.flags) = 0 and c.parent_id = ? and a.group_id in(' . $grp . ') 
		group by id order by c.ordering';
	}
	my $sth = $self->dbh->prepare( $query );
	$sth->execute( $id );

	my @obj;
	while ( my @arr = $sth->fetchrow_array() ) {
		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $arr[0] );
		push @obj, $C;
	}

	return \@obj;
}

sub validate_name {
	my $self = shift;

	my $n = $self->get_name();
	unless( $self->is_unique( $n ) ) {
		$self->set_name( $n . '_' . int( rand( 100000000 ) ) );
	}

	return $self->get_name();
}

sub add {
	my $self = shift;

	require HellFire::DataType;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from site_categories where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	if( $C->get_action( 'site_category_add' ) || $self->guard->is_administrator() ) {
		my $query = 'insert into site_categories( parent_id, name, ordering, flags, inserted, handler_id, config )
		values(?,?,?,?, now(),?, ?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_handler_id(), $self->get_config() );
		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		foreach ( @$l ) {
			my $query = 'insert into site_category_aliases(parent_id,lang_id,alias,title,keywords,description) values(?,?,?,?,?,?)';
			$self->dbh->do( $query, undef, $id, $_->{id}, $self->get_alias( $_->{id} ), $self->get_title( $_->{id} ), $self->get_keywords( $_->{id} ), $self->get_description( $_->{id} ) );
		}

		$self->set_access( $id );
		$self->refresh_index();
		$self->refresh_path( $id );
		return $id;
	}

	return undef;
}

sub update {
	my $self = shift;

	require HellFire::DataType;

	my $access = $self->get_action( 'site_category_update' ) || $self->guard->is_administrator();

	if( $self->get_name() && $self->get_id() && $access ) {
		my $query = 'update site_categories set parent_id = ?, name = ?, ordering = ?, flags = ?, handler_id = ?, config = ? where id = ? ';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_handler_id(), $self->get_config(), $self->get_id() );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		$self->dbh->do( 'delete from site_category_aliases where parent_id = ? ', undef, $self->get_id() );
		foreach ( @$l ) {
			my $query = 'insert into site_category_aliases(parent_id,lang_id,alias,title,keywords,description) values(?,?,?,?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ), $self->get_title( $_->{id} ), $self->get_keywords( $_->{id} ), $self->get_description( $_->{id} ) );
		}

		$self->refresh_index();
		$self->refresh_path();

		return 1;
	}

	return undef;
}

sub move {
	my $self  = shift;
	my $point = shift || 'append';
	my $dst   = shift || 0;

	require HellFire::Site::ItemDAO;
	if( $dst ) {
		my $DST = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$DST->load( $dst );

		unless( $point eq 'append' ) {
			$DST->load( $DST->get_parent_id() );
		}

		my $access = $self->guard->is_administrator() || ( $self->get_action( 'site_category_delete' ) && $DST->get_action( 'site_category_add' ) );

		if( $self->get_id() && $access ) {
			my $query = 'update site_categories set parent_id = ?, ordering = ? where id = ?';
			unless( $point eq 'append' ) {
				$DST->load( $dst );
				if( $point eq 'below' ) {
					$self->set_ordering( $DST->get_ordering() + 1 );
				}
				else {
					$self->set_ordering( $DST->get_ordering() - 1 );
				}
				$self->dbh->do( $query, undef, $DST->get_parent_id(), $self->get_ordering(), $self->get_id() );
				$self->set_parent_id( $DST->get_parent_id() );
			}
			else {
				$self->dbh->do( $query, undef, $DST->get_id(), $self->get_ordering(), $self->get_id() );
				$self->set_parent_id( $DST->get_id() );
			}

			$self->refresh_index();
			$self->refresh_ordering();
			$self->refresh_path;
			return 1;
		}
	}
	return undef;
}

sub refresh_ordering {
	my $self = shift;

	my $s = $self->get_all_siblings( $self->get_parent_id() );
	my $c = 0;
	foreach ( @$s ) {
		$_->set_ordering( $c );
		$_->save();
		$c += 10;
	}
}

sub get_site_tree {
	my $self = shift;
	my $pid = shift || 0;

	my $query = 'select * from site_categories where parent_id = ? and find_in_set("DELETED",flags) = 0 order by ordering';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $pid );

	my @arr;
	while ( my $hash = $sth->fetchrow_hashref() ) {
		$hash->{rows} = $self->get_site_tree( $hash->{id} );
		push @arr, $hash;
	}

	if( scalar @arr > 0 ) {
		return \@arr;
	}
	else {
		return undef;
	}
}

sub get_parent_inherit_list {
	my $self = shift;
	my $id   = shift;
	my @ret;

	my $query = 'select parent_id from site_categories 
			where id = ? and find_in_set("DELETED",flags) = 0 and find_in_set("INHERIT",flags) > 0';
	my @arr = $self->dbh->selectrow_array( $query, undef, $id );

	if( $arr[0] > 0 ) {
		my $rr = $self->get_parent_inherit_list( $arr[0] );
		@ret = @$rr;
		push @ret, $arr[0];
	}

	return \@ret;
}

sub get_parent_list {
	my $self = shift;
	my $id   = shift;
	my @ret;

	my $query = 'select parent_id from site_categories 
			where id = ? and find_in_set("DELETED",flags) = 0 ';
	my @arr = $self->dbh->selectrow_array( $query, undef, $id );

	if( $arr[0] > 0 ) {
		my $rr = $self->get_parent_list( $arr[0] );
		@ret = @$rr;
		push @ret, $arr[0];
	}

	return \@ret;
}

sub refresh_index {
	my $self = shift;
	my $id   = shift || 0;
	my $ind  = shift || 0;

	my $query = 'select id from site_categories where parent_id = ? order by ordering';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $id );
	while ( my @w = $sth->fetchrow_array() ) {
		$ind++;
		$self->dbh->do( 'update site_categories set index_left = ? where id = ?', undef, $ind, $w[0] );
		$ind = $self->refresh_index( $w[0], $ind );
		$ind++;
		$self->dbh->do( 'update site_categories set index_right = ? where id = ?', undef, $ind, $w[0] );
	}

	return $ind;
}

sub refresh_path {
	my $self = shift;
	my $id = shift || $self->get_id;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	my $pid = $self->get_parent_list( $id );
	push @$pid, $id;
	shift @$pid;
	my $p = '/';

	foreach ( @$pid ) {
		$C->load( $_ );
		$p .= $C->get_name() . '/';
	}
	$p =~ s/\/$//;

	$self->dbh->do( 'update site_categories set path = ?, updated = now()  where id = ?', undef, $p, $id );

	my $sth = $self->dbh->prepare( 'select id from site_items where parent_id = ?' );
	$sth->execute( $id );

	while ( my @arr = $sth->fetchrow_array ) {
		my $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
		$I->load( $arr[0] );
		$I->refresh_path;
	}

	$sth = $self->dbh->prepare( 'select id from site_categories where parent_id = ?' );
	$sth->execute( $id );

	while ( my @arr = $sth->fetchrow_array ) {
		$C->load( $arr[0] );
		$C->refresh_path;
	}

	return $p;
}

sub is_unique {
	my $self = shift;
	my $name = shift || '';

	if( length $name > 0 ) {
		my $query = 'select id from site_categories where name = ? and parent_id = ?';
		my $id = $self->dbh->selectrow_array( $query, undef, $name, $self->get_parent_id() );

		if( $id > 0 && $self->get_id() != $id ) {
			return undef;
		}

		return 1;
	}
	return undef;
}

sub destroy {
	my $self   = shift;
	my $params = shift;

	my $access = $self->guard->is_administrator() || $self->get_action( 'site_category_delete' );

	require HellFire::Site::ItemDAO;

	if( $self->get_id() ) {
		my $ac = $self->get_all_children();
		push @$ac, $self;
		foreach my $c ( @$ac ) {
			warn 444;
			my $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
			$I->set_parent_id( $c->get_id() );
			my $ai = $I->get_items();

			foreach my $i ( @$ai ) {
				$i->destroy();
			}

			# remove content catalog

			my $query = 'delete from site_category_aliases where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );

			$query = 'delete from site_category_access where parent_id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );

			$query = 'delete from site_categories where id = ?';
			$self->dbh->do( $query, undef, $c->get_id() );
		}

		$self->refresh_index();

	}
	else {
		warn( 'delete_item: item not found' );
	}
}

sub get_all_children {
	my $self = shift;

	my $query = 'select id,  index_right-index_left cc from site_categories where index_left > ? and index_right < ? order by cc';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_index_left(), $self->get_index_right() );
	my @arr;

	while ( my $aa = $sth->fetchrow_array() ) {
		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $aa );
		push @arr, $C;
	}

	return \@arr;
}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from site_categories where name = ? and parent_id = ?';
	my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
}

sub find_by_path {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from site_categories where path = ?';
	my $id = $self->dbh->selectrow_array( $query, undef, $val ) || 0;

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
	my $query = 'select count(*) from site_category_access a inner join configuration_actions c on c.id = a.action_id 
			where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );

	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert ignore into site_category_access( parent_id, group_id, action_id ) 
					select ?, group_id, action_id from site_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub get_domain {
	my $self = shift;

	my $query = 'select c.id from site_categories c left join site_aliases s on c.id = s.parent_id  
			where c.name = ? or s.name = ? limit 1';
	my $pid = $self->dbh->selectrow_array( $query, undef, $ENV{HTTP_HOST}, $ENV{HTTP_HOST} );

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	$C->set_parent_id( 0 );
	$C->load( $pid );

	return $C;
}


sub get_top_parent_id {
	my $self = shift;
	my $id   = shift;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	do {
		$C->load( $id );
		$id = $C->get_parent_id();
	} while ( $C->get_parent_id() );

	return $C->get_id();
}

sub touch {
	my $self = shift;
	$self->dbh->do( 'update site_categories set updated = now() where id = ?', undef, $self->get_id() );
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
	my $act = $I->get_action_list( $I->find( 'site_lib' ) );
    
    my @arr;
	foreach my $g ( @$grp ) {
		next if( $g->get_name() eq 'administrator' );

		foreach my $a ( @$act ) {
			my $query = 'select 1 from site_category_access
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


return 1;
