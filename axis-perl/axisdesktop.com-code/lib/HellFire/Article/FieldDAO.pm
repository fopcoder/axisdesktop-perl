## @file
# Implementation of HellFire::Article::FieldDAO

## @addtogroup Article 
# @{
## @class 
# Manage of aricles fields

package HellFire::Article::FieldDAO;

## }@

use strict;
use base qw(HellFire::Article);
use HellFire::DataBase;
use HellFire::DataType;
use HellFire::Article::CategoryDAO;

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

sub get_default_value {
	my $self = shift;
	return $self->{'_default_value'};
}

sub get_group_access {
	my $self = shift;
	return $self->{'_gaccess'};
}

sub get_source_field_id {
	my $self = shift;
	return $self->{'_source_field_id'} || 0;
}

sub get_source_group_id {
	my $self = shift;
	return $self->{'_source_group_id'} || 0;
}

sub get_source_id {
	my $self = shift;
	return $self->{'_source_id'} || 0;
}

sub get_type {
	my $self = shift;
	return $self->{'_type'} || '';
}

sub get_type_id {
	my $self = shift;
	return $self->{'_type_id'} || 0;
}

sub set_default_value {
	my $self = shift;
	$self->{'_default_value'} = shift;
	return $self->{'_default_value'};
}

sub set_group_access {
	my $self = shift;
	$self->{'_gaccess'} = shift;
	return $self->{'_gaccess'};
}

sub set_source_field_id {
	my $self = shift;
	$self->{'_source_field_id'} = shift;
	return $self->{'_source_field_id'};
}

sub set_source_group_id {
	my $self = shift;
	$self->{'_source_group_id'} = shift;
	return $self->{'_source_group_id'};
}

sub set_source_id {
	my $self = shift;
	$self->{'_source_id'} = shift;
	return $self->{'_source_id'};
}

sub set_type {
	my $self = shift;
	$self->{'_type'} = shift;
	return $self->{'_type'};
}

sub set_type_id {
	my $self = shift;
	$self->{'_type_id'} = shift;
	return $self->{'_type_id'};
}

sub validate_name {
	my $self = shift;

	unless( $self->is_unique( $self->get_name() ) ) {
		$self->set_name( $self->get_name() . '_' . int( rand( 100000000 ) ) );
	}

	return $self->get_name();
}

sub add {
	my $self = shift;

	require HellFire::Article::CategoryDAO;
	my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $self->get_parent_id() );

	unless( $self->get_ordering() ) {
		my $ord = $self->dbh->selectrow_array( 'select max(ordering) from article_fields where parent_id = ?', undef, $self->get_parent_id() );
		$ord += 10;
		$self->set_ordering( $ord );
	}

	my $access = $C->get_action( 'article_field_add' ) || $self->guard->is_administrator();

	if( $self->get_parent_id() && $access && $self->get_type_id() ) {
		my $query = 'insert into article_fields( parent_id, name, ordering, flags, inserted, source_group_id, source_id, source_field_id, type_id, user_id )
		values(?,?,?,?, now(), ?, ?, ?, ?, ?)';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_source_group_id(), $self->get_source_id(), $self->get_source_field_id(), $self->get_type_id(), $self->guard->get_user_id() );

		my $id = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$self->set_access( $id );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		foreach ( @$l ) {
			my $query = 'insert into article_field_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$self->dbh->do( $query, undef, $id, $_->{id}, $self->get_alias( $_->{id} ) ) if( $self->get_alias( $_->{id} ) );
		}

		return $id;
	}

	return undef;
}

## @method HellFire::Article::FieldDAO copy( hashref params )
# @brief Make a copy of current field to current or other category
# @param params hashref 
#				- parent_id : int : id of other category { parent_id => 34 }
# @return New field HellFire::Article::FieldDAO or undef if no id or permission denied
sub copy {
	my $self   = shift;
	my $params = shift;

	if( ( $self->get_action( 'article_field_update' ) || $self->guard->is_administrator() ) &&
	   $self->get_id() ) {
		my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
		$F->load( $self->get_id() );
		$F->set_id( 0 );
		$F->set_parent_id( $params->{parent_id} ) if( $params->{parent_id} );
		$F->save();

		return $F;
	}
	else	{
		warn 'copy of HellFire::Article::FieldDAO failed';
	}

	return undef;
}

sub destroy {
	my $self = shift;

	my $access = $self->get_action( 'article_item_delete' ) || $self->guard->is_administrator();
	if( $self->get_id() && $access && !$self->is_system() && !$self->is_locked() && !$self->is_linked() ) {
		$self->dbh->selectrow_array( 'call article_field_destroy(?,@c,@m)', undef, $self->get_id() );
		return 1;
	}
	else {
		warn( 'cant delete field: parent SYSTEM or item SYSTEM or item LINKED' );
	}
	return undef;
}

## @method int load( int id, hashref params )
# @brief Load field by id
# @param $id int, a field id to load, default $self->id or 0
# @param $params hashref
#		- lang_id : boolean : fetch only current language { lang_id => 1 }
# @return id : int : id of field if found or undef if not
#
# @code 
# use HellFire::Article::FieldDAO;
# my $F = new HellFire::Article::FieldDAO( DBI $dbh, HellFire::Guard $G );
# $F->load( 12, { lang_id => 1 } ); # only current language
# if( $F->load( 12 ) ) { warn "loaded" }; # all languages
# @endcode
sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift || {};

	$self->set_id( $id );

	if( $id && ( $self->guard->is_administrator() || $self->get_action( 'article_field_view' ) ) ) {
		my $query = 'select * from article_fields where id = ?';
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

		my $T = new HellFire::DataType( $self->dbh );
		$self->set_type( $T->get_type_name( $self->get_type_id() ) );

		my $sth;
		if( $params->{lang_id} ) {
			$query = 'select lang_id, alias from article_field_aliases where parent_id = ? and lang_id = ?';
			$sth   = $self->dbh->prepare( $query );
			$sth->execute( $id, $self->guard->get_lang_id() );
		}
		else {
			$query = 'select lang_id, alias from article_field_aliases where parent_id = ? ';
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

sub update {
	my $self = shift;

	if( ( $self->get_action( 'article_field_update' ) || $self->guard->is_administrator() ) && $self->get_id() ) {
		my $flags = $self->flags_to_string();
		my $query = 'update article_fields set parent_id = ?, name = ?, ordering = ?, flags = ? where id = ? and find_in_set("SYSTEM",flags) = 0';
		$self->dbh->do( $query, undef, $self->get_parent_id(), $self->validate_name(), $self->get_ordering(), $self->flags_to_string(), $self->get_id() );

		my $T = new HellFire::DataType( $self->dbh );
		my $l = $T->get_languages();
		$query = 'delete from article_field_aliases where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
		foreach ( @$l ) {
			my $query = 'insert into article_field_aliases(parent_id,lang_id,alias) values(?,?,?)';
			$self->dbh->do( $query, undef, $self->get_id(), $_->{id}, $self->get_alias( $_->{id} ) ) if( $self->get_alias( $_->{id} ) );
		}

		my $code = $self->get_group_access();
		foreach my $j ( @$code ) {
			foreach ( keys %$j ) {
				if( $_ =~ /field_(\d+)/ ) {
					if( $j->{$_} eq 'false' || $j->{$_} == 0 ) {
						$self->dbh->do( 'delete from article_field_access where parent_id = ? and group_id = ? and action_id = ?', undef, $self->get_id(), $j->{id}, $1 );
					}
					if( $j->{$_} eq 'true' || $j->{$_} > 0 ) {
						$self->dbh->do( 'insert ignore into article_field_access(parent_id,group_id,action_id) values(?,?,?)', undef, $self->get_id(), $j->{id}, $1 );
					}
				}
			}
		}

		return 1;
	}

	return undef;
}

sub is_linked {
	my $self   = shift;
	my $params = shift;

	my $query = 'select count(*) from article_fields where source_field_id = ?';
	my $c = $self->dbh->selectrow_array( $query, undef, $self->get_id() ) || 0;

	return $c;
}

sub is_unique {
	my $self = shift;
	my $name = shift || '';

	if( length $name > 0 ) {
		my $query = 'select id from article_fields where name = ? and parent_id = ?';
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

	my $query = 'select count(*) from article_field_access a inner join configuration_actions c on c.id = a.action_id 
					where a.parent_id = ? and a.group_id in(' . $grp . ') and c.name = ?';
	return $self->dbh->selectrow_array( $query, undef, $self->get_id(), $val ) || 0 ;
}

sub get_combo {
	my $self     = shift;
	my $selected = shift;

	my $query = 'call article_field_combo(?,?,?,?,@c,@m) ';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_id, $self->get_type_id, $self->guard->get_lang_id(), undef ) or die $self->dbh->errstr;
	my @arr;
	while ( my $h = $sth->fetchrow_hashref() ) {
		$h->{selected} = ' selected ' if( $selected->{ $h->{id} } );
		push @arr, $h;
	}

	return \@arr;
}

## @method arrayref get_fields( hashref params )
# @brief Loads fields from category
# @param params hashref input params
#			- show_this : boolean : shows only current category fields
#			- show_inherit : boolean : shows only inherit fields
#			- with_type : list : shows only fields of selected data type
#			- without_type : list : shows fields except of selected data type
#			- with_fields : list : shows only selected fields
#			- without_fields : list : shows except selected fields
#			- without_hidden : boolean : shows except hidden fields
# @return arrayref of fields
#
# @code
# use HellFire::Article::FieldDAO;
# my $F = new HellFire::Article::FieldDAO( DBI $dbh, HellFire::Guard $G );
# $F->set_parent_id( 54 );
# my $a = $F->get_fields( {
#		show_this => 1,
#		without_fields => 'brand,12,34,weight',
#		with_type => 'int,8,string'
#	} );
# @endcode
sub get_fields {
	my $self   = shift;
	my $params = shift;

	my @src;

	if( $params->{show_this} ) {
		push @src, $self->get_parent_id();
	}
	elsif( $params->{show_inherit} ) {
		require HellFire::Article::CategoryDAO;
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		my $cp = $C->get_parent_inherit_list( $self->get_parent_id() );
		push @src, reverse @$cp;
	}
	else {
		push @src, $self->get_parent_id();
		require HellFire::Article::CategoryDAO;
		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		my $cp = $C->get_parent_inherit_list( $self->get_parent_id() );
		push @src, reverse @$cp;
	}

	my $T = new HellFire::DataType( $self->dbh );
	
	my @type_id;
	$params->{with_type} =~ s/\s+//g;
	
	foreach ( split( /,/, $params->{with_type} ) ) {
		my $id;
		
		if( $_ =~ /[A-Za-z]/ ) {
			$id = $T->find( $_ );
		}
		else {
			$id = $_;
		}
		
		push @type_id, $id if( $id );
	}

	my @no_type_id;
	$params->{without_type} =~ s/\s+//g;
	
	foreach ( split( /,/, $params->{without_type} ) ) {
		my $id;
		
		if( $_ =~ /[A-Za-z]/ ) {
			$id = $T->find( $_ );
		}
		else {
			$id = $_;
		}
		
		push @no_type_id, $id if( $id );
	}
	
	my @with_fields;
	$params->{with_fields} =~ s/\s+//g;
	
	foreach ( split( /,/, $params->{with_fields} ) ) {
		my $id;
		
		if( $_ =~ /[A-Za-z]/ ) {
			$id = $self->find( $_ );
		}
		else {
			$id = $_;
		}
		
		push @with_fields, $id if( $id );
	}
	
	my @without_fields;
	$params->{without_fields} =~ s/\s+//g;
	
	foreach ( split( /,/, $params->{without_fields} ) ) {
		my $id;
		
		if( $_ =~ /[A-Za-z]/ ) {
			$id = $self->find( $_ );
		}
		else {
			$id = $_;
		}
		
		push @without_fields, $id if( $id );
	}
	
	my @arr;
	my $counter = 0;
	foreach ( @src ) {
		my $inh;
		$inh = ' and find_in_set("INHERIT", flags) > 0 ' if( $_ != $self->get_parent_id() );

		if( scalar @type_id ) {
			$inh .= ' and type_id in(' . join( ',', @type_id ) . ') ';
		}

		if( scalar @no_type_id ) {
			$inh .= ' and type_id not in(' . join( ',', @no_type_id ) . ') ';
		}

		if( scalar @with_fields ) {
			$inh .= ' and id in(' . join( ',', @with_fields ) . ') ';
		}

		if( scalar @without_fields ) {
			$inh .= ' and id not in(' . join( ',', @without_fields ) . ') ';
		}
		
		if( $params->{without_hidden} ) {
			$inh .= ' and find_in_set( "HIDDEN", flags) = 0 ';
		}
		
		my $ord = 'ordering';
		if( $params->{ordering} )	{
			$ord = $params->{ordering};
		}
		my $dir = 'asc';
		if( $params->{direction} )	{
			$dir = $params->{direction};
		}
		
		my $query = "select id from article_fields f left join article_field_aliases a on a.parent_id = f.id and a.lang_id = ?
			where f.parent_id = ? and find_in_set('DELETED', f.flags) = 0 $inh   
			order by $ord $dir";
		my $sth = $self->dbh->prepare( $query );
		$sth->execute( $self->guard->get_lang_id(), $_ );

		while ( my $hash = $sth->fetchrow_hashref() ) {
			my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
			push @arr, $F if( $F->load( $hash->{'id'}, { lang_id => $params->{lang_id} } ) );
		}
	}

	return \@arr;
}

sub clear_access {
	my $self = shift;

	if( $self->get_id() ) {
		my $query = 'delete from article_field_access where parent_id = ?';
		$self->dbh->do( $query, undef, $self->get_id() );
	}
}

sub set_access {
	my $self = shift;
	my $id = shift || $self->get_id() || 0;

	if( $id ) {
		my $query = 'insert into article_field_access( parent_id, group_id, action_id ) 
						select ?, group_id, action_id from article_category_access where parent_id = ?';
		$self->dbh->do( $query, undef, $id, $self->get_parent_id() );
	}
}

sub find {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from article_fields where name = ? and parent_id = ? and find_in_set("DELETED",flags) = 0';
	return $self->dbh->selectrow_array( $query, undef, $val, $self->get_parent_id() ) || 0;
}

sub get_suffix	{
	my $self = shift;
	return $self->{_suffix}||'';
}

sub set_suffix	{
	my $self = shift;
	$self->{_suffix} = shift;
	return $self->{_suffix};
}

sub get_comment	{
	my $self = shift;
	return $self->{_comment}||'';
}

sub set_comment	{
	my $self = shift;
	$self->{_coment} = shift;
	return $self->{_comment};
}

return 1;
