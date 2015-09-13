package HellFire::Site::TemplateDAO;

use strict;
use base qw(HellFire::Site);
use HellFire::Site::CategoryDAO;

sub new {
	my $class  = shift;
	my $dbh    = shift;
	my $G      = shift;
	my $params = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}     = $dbh;
	$self->{'_guard'}   = $G;
	$self->{'_content'} = {};

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
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	$self->set_id( $id );

	if( $self->get_id() ) {
		my $query = 'select * from site_templates where id = ?';

		my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
		$self->flags_to_hash( $h );

		foreach my $i ( keys %$h ) {
			if( $i =~ /FLAG_(\w+)/ ) {
				$self->set_flag( $1 );
			}
			else {
				my $e = '$self->set_' . $i . '("' . $h->{$i} . '")';
				eval( $e );
			}
		}

		$query = 'select * from site_template_content where parent_id = ? ';
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $id );

		while ( my $h = $sth->fetchrow_hashref() ) {
			$self->set_content( $h );
			$self->set_alias( $h->{lang_id}, $h->{alias} );
		}

		return 1;
	}
	return undef;
}

sub set_content {
	my $self = shift;
	my $o    = shift;

	my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
	my $prefix = $C->get_top_parent_id( $self->get_parent_id() );
	$prefix .= '/t';

	$self->{_content}->{ $o->{lang_id} } = $o;

	if( length $self->{_content}->{ $o->{lang_id} }->{content} > 0 ) {
		if( open FILE, $self->guard->ini->template_dir . "/$prefix/" . $self->{_content}->{ $o->{lang_id} }->{content} ) {
			$self->{_content}->{ $o->{lang_id} }->{body} = join( '', <FILE> );
			close FILE;
		}
	}
}

sub get_content {
	my $self    = shift;
	my $lang_id = shift;

	return $self->{_content}->{$lang_id};
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
	my $self   = shift;
	my $params = shift;

	$self->validate_name();

	my $access = $self->get_action( 'site_template_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $self->get_name() && $access ) {
		my $query = 'insert into site_templates(parent_id, name, inserted, flags) values(?,?,now(),?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->get_name(), $self->flags_to_string() );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );

		use HellFire::DataType;
		my $T = new HellFire::DataType( $self->dbh );
		my @items_l10n;
		my $l = $T->get_languages();

		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $C->get_top_parent_id( $self->get_parent_id() );
		$prefix .= '/t';

		if( !-e $self->guard->ini->template_dir . "/$prefix" ) {
			my $dir = $self->guard->ini->template_dir . "/$prefix";
			`mkdir -p $dir`;
		}

		foreach ( @$l ) {
			my $co = $self->get_content( $_->{id} );

			my $file = $co->{content} || int( rand( 10000000000 ) ) . '.tpl';
			my $path = $self->guard->ini->template_dir . "/$prefix/" . $file;
			open( FILE, ">", $path ) or die $!;
			print FILE $co->{body};
			close FILE;
			$co->{content} = $file;

			my $query = 'insert into site_template_content(parent_id, alias, lang_id, content) values(?,?,?,?)';
			$self->dbh->do( $query, undef, $id, $co->{alias} || '', $_->{id}, $co->{content} );

		}

		#$self->set_access( $id );

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

	my $access = $self->get_action( 'site_templat_update' ) || $self->guard->is_administrator();

	if( $access && $self->get_id() ) {
		my $query = 'update site_templates set name = ?, flags = ?  where id = ? ';
		$self->{'_dbh'}->do( $query, undef, $self->validate_name(), $self->flags_to_string(), $self->get_id() );

		$self->{_dbh}->do( 'delete from site_template_content where parent_id = ?', undef, $self->get_id() );

		use HellFire::DataType;
		my $T = new HellFire::DataType( $self->dbh );
		my @items_l10n;
		my $l = $T->get_languages();

		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $C->get_top_parent_id( $self->get_parent_id() );
		$prefix .= '/t';

		if( !-e $self->guard->ini->template_dir . "/$prefix" ) {
			my $dir = $self->guard->ini->template_dir . "/$prefix";
			`mkdir -p $dir`;
		}

		foreach ( @$l ) {
			my $co = $self->get_content( $_->{id} );

			my $file = $co->{content} || int( rand( 10000000000 ) ) . '.tpl';
			my $path = $self->guard->ini->template_dir . "/$prefix/" . $file;
			open( FILE, ">", $path ) or die $!;
			print FILE $co->{body};
			close FILE;
			$co->{content} = $file;

			my $query = 'insert into site_template_content(parent_id, alias, lang_id, content) values(?,?,?,?)';
			$self->{_dbh}->do( $query, undef, $self->get_id(), $co->{alias} || '', $_->{id}, $co->{content} );
		}

		return 1;
	}
	else {
		return 0;
	}
}

sub destroy {
	my $self   = shift;
	my $params = shift;

	my $access = $self->get_action( 'site_template_delete' ) || $self->guard->is_administrator();

	if( $self->get_id() && $access ) {
		$self->load();

		use HellFire::DataType;
		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();

		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		my $prefix = $C->get_top_parent_id( $self->get_parent_id() );
		$prefix .= '/t';

		foreach ( @$l ) {
			my $co = $self->get_content( $_->{id} );

			my $file = $co->{content};
			my $path = $self->guard->ini->template_dir . "/$prefix/" . $file;
			if( -f $path ) {
				unlink $path;
			}
		}

		my $query = 'delete from site_template_content where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );

		$query = 'update site_items set template_id = 0 where template_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );

		$query = 'delete from site_templates where id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );

		return 1;
	}
	else {
		warn( 'delete_item: item not found' );
	}
}

sub is_unique {
	my $self = shift;

	if( $self->get_name() ) {
		my $query = 'select id from site_templates where name = ? and parent_id = ?';
		my $id = $self->{_dbh}->selectrow_array( $query, undef, $self->get_name(), $self->get_parent_id() );

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

	my $sth = $self->{'_dbh'}->prepare( $query );
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

	my $query = 'select id from site_items where name = ? and parent_id = ?';
	my $id = $self->{_dbh}->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;

	return $id;
}

sub get_action {
	my $self = shift;
	my $val = shift || '';

	my $grp = join( ',', @{ $self->guard->get_groups() }, 0 );
	my $query = 'select count(*) from site_item_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	my $c = $self->{_dbh}->selectrow_array( $query, undef, $self->get_id(), $val );
	return $c || 0;
}

sub set_access {
	my $self = shift;
	my $id = shift || 0;

	if( $id ) {
		my $query = 'select group_id, action_id from site_category_access where parent_id = ?';
		my $sth   = $self->{_dbh}->prepare( $query );
		$sth->execute( $self->get_parent_id() );
		while ( my $h = $sth->fetchrow_hashref() ) {
			$query = 'insert into site_item_access( parent_id, group_id, action_id ) values(?,?,?)';
			$self->{_dbh}->do( $query, undef, $id, $h->{group_id}, $h->{action_id} );
		}
	}
}

sub save_content {
	my $self = shift;
	my $q    = shift;

	if( $self->get_id() ) {
		my $S = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$S->load( $self->get_parent_id() );
		my $prefix = $S->get_top_parent_id();
		$prefix .= '/t';

		if( !-e $self->guard->ini->template_dir . "/$prefix" ) {
			my $dir = $self->guard->ini->template_dir . "/$prefix";
			`mkdir -p $dir`;
		}

		my $query = 'select * from site_item_content where lang_id = 1 and parent_id = ?';
		my $C = $self->{_dbh}->selectrow_hashref( $query, undef, $self->get_id() );
		if( $C->{id} ) {
			my $file = $C->{content_url} || int( rand( 10000000000 ) ) . '.tpl';
			my $path = $self->guard->ini->template_dir . "/$prefix/" . $file;
			open( FILE, ">", $path ) or die $!;
			print FILE $q->param( 'content' );
			close FILE;

			$query = 'update site_item_content set content_url = ?, template_id = ?, lang_id = 1, parent_id = ? where id = ?';
			$self->{_dbh}->do( $query, undef, $file, $q->param( 'template_id' ) || 0, $self->get_id(), $C->{id} );

		}
		else {
			my $file = int( rand( 10000000000 ) ) . '.tpl';
			open( FILE, ">" . $self->guard->ini->template_dir . "/$prefix/" . $file ) or die $_;
			print FILE $q->param( 'content' );
			close FILE;

			$query = 'insert into site_item_content( content_url, template_id, lang_id, parent_id) values( ?, ?, 1, ?)';
			$self->{_dbh}->do( $query, undef, $file, $q->param( 'template_id' ) || 0, $self->get_id() );
		}
	}
}

sub get_templates {
	my $self = shift;

	my $query = 'select id, parent_id from site_categories where id = ?';
	my $sth   = $self->dbh->prepare( $query );

	my $pid = $self->get_parent_id();
	my $id  = $self->get_parent_id();
	while ( $pid ) {
		$sth->execute( $pid );
		my $h = $sth->fetchrow_hashref();
		$id  = $h->{id};
		$pid = $h->{parent_id};
	}

	$query = 'select id from site_templates where parent_id = ?';
	$sth   = $self->dbh->prepare( $query );
	$sth->execute( $id );
	my @arr;
	while ( my $h = $sth->fetchrow_hashref() ) {
		my $T = new HellFire::Site::TemplateDAO( $self->dbh, $self->guard );
		$T->load( $h->{id} );
		push @arr, $T;
	}

	return \@arr;
}

return 1;
