package HellFire::User::FieldDAO;

use strict;
use base qw(HellFire::FieldInterface HellFire::User);
use HellFire::DataBase;
use HellFire::DataType;

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $g     = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}   = $dbh;
	$self->{'_guard'} = $g;

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

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift || {};

	$self->set_id( $id );

	if( $self->guard->is_administrator() || $self->get_action( 'user_field_view' ) ) {
		my $query = 'select * from user_fields where id = ?';
		my $h     = $self->dbh->selectrow_hashref( $query, undef, $id );
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

		my $T = new HellFire::DataType( $self->dbh );
		$self->set_type( $T->get_type_name( $self->get_type_id() ) );

		my $sth;
		if( $params->{lang_id} ) {
			$query = 'select lang_id, alias, suffix, comment from user_field_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $self->guard->get_lang_id() );
		}
		else {
			$query = 'select lang_id, alias, suffix, comment from user_field_aliases where parent_id = ? ';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id );
		}

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_alias( $h->{'lang_id'}, $h->{'alias'} );
			$self->set_suffix( $h->{'lang_id'}, $h->{'suffix'} );
			$self->set_comment( $h->{'lang_id'}, $h->{'comment'} );
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

	require HellFire::User::CategoryDAO;
	my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from user_fields where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	my $access = $C->get_action( 'user_field_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $access && $self->get_type_id() ) {
		my $query = 'insert into user_fields( parent_id, name, ordering, flags, inserted, source_group_id, source_id, source_field_id, type_id, default_value )
		values(?,?,?,?, now(), ?, ?, ?, ?, ?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_source_group_id(), $self->get_source_id(), $self->get_source_field_id(), $self->get_type_id(), $self->get_default_value() );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$self->set_access( $id );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		foreach ( @$l ) {
			my $query = 'insert into user_field_aliases(parent_id,lang_id,alias,suffix,comment) values(?,?,?,?,?)';
			$self->dbh->do( $query, undef, $id, $_->{id}, $self->get_alias( $_->{id} ), $self->get_suffix( $_->{id} ), $self->get_comment( $_->{id} ) );
		}

		return $id;
	}

	return undef;
}

sub update {
	my $self = shift;

	if( ( $self->get_action( 'user_field_update' ) || $self->guard->is_administrator() ) && $self->get_id() ) {
		my $flags = $self->flags_to_string();
		my $query = 'update user_fields set parent_id = ?, name = ?, ordering = ?, flags = ?, default_value = ? where id = ? and find_in_set("SYSTEM",flags) = 0';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_default_value(), $self->get_id() );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		$query = 'delete from user_field_aliases where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
		foreach ( @$l ) {
			my $query = 'insert into user_field_aliases(parent_id,lang_id,alias,suffix,comment) values(?,?,?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ), $self->get_suffix( $_->{id} ), $self->get_comment( $_->{id} ) );
		}

		my $code = $self->get_group_access();
		foreach my $j ( @$code ) {
			foreach ( keys %$j ) {
				if( $_ =~ /field_(\d+)/ ) {
					if( $j->{$_} eq 'false' || $j->{$_} == 0 ) {
						$self->dbh->do( 'delete from user_field_access where parent_id = ? and group_id = ? and action_id = ?', undef, $self->get_id(), $j->{id}, $1 );
					}
					if( $j->{$_} eq 'true' || $j->{$_} > 0 ) {
						$self->dbh->do( 'insert into user_field_access(parent_id,group_id,action_id) values(?,?,?)', undef, $self->get_id(), $j->{id}, $1 );
					}
				}
			}
		}

		return 1;
	}

	return undef;
}

sub destroy {
	my $self = shift;

	my $access = $self->get_action( 'user_item_delete' ) || $self->guard->is_administrator();
	if( $self->get_id() && $access && !$self->is_system() && !$self->is_locked() && !$self->is_linked() ) {
		$self->dbh->selectrow_array( 'call user_field_destroy(?,@c,@m)', undef, $self->get_id() );
		return 1;
	}
	else {
		warn( 'cant delete field: parent SYSTEM or item SYSTEM or item LINKED' );
	}
	return undef;
}

sub is_unique {
	my $self = shift;
	my $name = shift || '';

	if( length $name > 0 ) {
		my $query = 'select id from user_fields where name = ? and parent_id = ?';
		my $id = $self->dbh->selectrow_array( $query, undef, $name, $self->get_parent_id() );

		if( $id > 0 && $self->get_id() != $id ) {
			return undef;
		}

		return 1;
	}
	return undef;
}

sub is_linked {
	my $self   = shift;
	my $params = shift;

	my $query = 'select count(*) from user_fields where source_field_id = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id() ) || 0;

	return $c;
}

sub is_required	{
	my $self = shift;
	return $self->get_flag( 'REQUIRED' );
}

sub get_fields {
	my $self   = shift;
	my $params = shift;

	my @src;

	if( $params->{show_this} ) {
		push @src, $self->get_parent_id();
	}
	elsif( $params->{show_inherit} ) {
		require HellFire::User::CategoryDAO;
		my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		my $cp = $C->get_parent_inherit_list( $self->get_parent_id() );
		push @src, reverse @$cp;
	}
	else {
		push @src, $self->get_parent_id();
		require HellFire::User::CategoryDAO;
		my $C = new HellFire::User::CategoryDAO( $self->dbh, $self->guard );
		my $cp = $C->get_parent_inherit_list( $self->get_parent_id() );
		push @src, reverse @$cp;
	}

	my @type_id;
	my $T = new HellFire::DataType( $self->dbh );
	foreach ( split( /,/, $params->{type} ) ) {
		$_ =~ s/^\s+|\s+$//;
		my $id = $T->find_type( $_ );
		push @type_id, $id if( $id );
	}

	my @arr;
	my $counter = 0;
	foreach ( @src ) {
		my $inh;
		$inh = ' and find_in_set("INHERIT", flags) > 0 ' if( $_ != $self->get_parent_id() );
		if( scalar @type_id ) {
			$inh .= ' and type_id in(' . join( ',', @type_id ) . ') ';
		}
		my $query = "select id from user_fields 
			where parent_id = ? and find_in_set('DELETED', flags) = 0 $inh   
			order by ordering";
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $_ );

		while ( my $hash = $sth->fetchrow_hashref() ) {
			my $F = new HellFire::User::FieldDAO( $self->dbh, $self->guard );
			push @arr, $F if( $F->load( $hash->{'id'}, { lang_id => $params->{lang_id} } ) );
		}
	}

	return \@arr;
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

	my $query = 'select count(*) from user_field_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub clear_access {
	my $self = shift;

	if( $self->get_id() ) {
		my $query = 'delete from user_field_access where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
	}
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into user_field_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from user_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub get_combo {
	my $self     = shift;
	my $selected = shift;

	my $query = 'call user_field_combo(?,?,?,?,@c,@m) ';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_id, $self->get_type_id, $self->guard->get_lang_id(), undef ) or die $self->dbh->errstr;
	my @arr;
	while ( my $h = $sth->fetchrow_hashref() ) {
		$h->{selected} = ' selected ' if( $selected->{ $h->{id} } );
		push @arr, $h;
	}

	return \@arr;
}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from user_fields where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
	my $id = $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
}

return 1;
