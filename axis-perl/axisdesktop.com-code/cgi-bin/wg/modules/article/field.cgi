#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::DataType;
use HellFire::Article::FieldDAO;
use HellFire::Article::CategoryDAO;
use HellFire::Configuration::CategoryDAO;
use JSON;
use HellFire::Config;
use HellFire::User::CategoryDAO;

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;
my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $action    = $q->param( 'action' ) || '';
my $parent_id = $q->param( 'pid' )    || 0;
my $id        = $q->param( 'id' )     || 0;

#---------------------------------------------------
#	FIELDS GROUPS
#---------------------------------------------------

if( $action eq 'article_field_group_add' ) {
	my $J = new JSON;

	my $query = 'select max(ordering) from article_field_groups where parent_id = ?';
	my $ord = $dbh->selectrow_array( $query, undef, $parent_id );
	$ord += 10;
	$query = 'insert into article_field_groups(parent_id,ordering) values( ?, ? )';
	$dbh->do( $query, undef, $parent_id, $ord );
	my $id = $dbh->last_insert_id(undef,undef,undef,undef);
	$query = 'update article_field_groups set name = ? where id = ?';
	$dbh->do( $query, undef, "grp_$id", $id);

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_field_group_item_move' ) {
	my $J = new JSON;

	if( $q->param('src') && $q->param('dst') && $q->param('point') )	{
		my $o  = $dbh->selectrow_array('select ordering from article_field_group_items where id = ?', undef, $q->param('dst') );
		if( $q->param('point') eq 'above' )	{
			$o--;
			$dbh->do( 'update article_field_group_items set ordering = ? where id = ?', undef, $o, $q->param('src') );
		}
		elsif( $q->param('point') eq 'below' )	{
			$o++;
			$dbh->do( 'update article_field_group_items set ordering = ? where id = ?', undef, $o, $q->param('src') );
		}

		my $query = 'select id, ordering from article_field_group_items where parent_id in( select parent_id from article_field_group_items where id = ?) order by ordering';
		my $sth = $dbh->prepare( $query );
		$sth->execute( $q->param('src') );
		my $c = 0;
		while( my $h = $sth->fetchrow_hashref )	{
			$dbh->do( 'update article_field_group_items set ordering = ? where id = ?', undef, $c, $h->{id} );
			$c += 10;
		}

	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_field_group_view' ) {
	my $J = new JSON;
	my( $query, $res );
	
	my $T = new HellFire::DataType( $dbh );
	my $l = $T->get_languages();
	
	if( $q->param('grp') )	{
		$query = 'select * from article_field_groups where id = ?';
		$res = $dbh->selectrow_hashref( $query, undef, $id );
		$res->{ grp } = 1;
		
		$query = 'select alias from article_field_group_aliases where parent_id = ? and lang_id = ?';
		
		my @l10n;
		foreach( @$l )  {
			push @l10n, {
				xtype => 'textfield',
				fieldLabel => $_->{'alias'},
				name => 'alias_'.$_->{id},
				value => $dbh->selectrow_array( $query, undef, $res->{id}, $_->{id} )
			};
		}
		
		$res->{ l10n } = \@l10n;
	}
	else	{
		$query = 'select * from article_field_group_items where id = ?';
		$res = $dbh->selectrow_hashref( $query, undef, $id );
		$res->{ grp } = 0;
		
		$query = 'select alias from article_field_group_item_aliases where parent_id = ? and lang_id = ?';
		
		my @l10n;
		foreach( @$l )  {
			push @l10n, {
				xtype => 'textfield',
				fieldLabel => $_->{'alias'},
				name => 'alias_'.$_->{id},
				value => $dbh->selectrow_array( $query, undef, $res->{id}, $_->{id} )
			};
		}
		
		$res->{ l10n } = \@l10n;
	}

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_field_group_del' ) {
	my $J = new JSON;
	my $query;

	if( $q->param('id') )	{
		if( $q->param('leaf') == 1 )	{
			$query = 'delete from article_field_group_items where id = ?';
			$dbh->do( $query, undef, $q->param('id') );
			$query = 'delete from article_field_group_item_aliases where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );
		}
		else	{
			$query = 'delete from article_field_group_items where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );
			$query = 'delete from article_field_group_item_aliases where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );

			$query = 'delete from article_field_groups where id = ?';
			$dbh->do( $query, undef, $q->param('id') );
			$query = 'delete from article_field_group_aliases where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );
		}
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_field_group_item_add' )    {
	my $J = new JSON;

	if( $q->param('src') && $q->param('dst') )	{
		my $query = 'select * from article_fields where id in('.$q->param('src').') ';			
		my $sth = $dbh->prepare( $query );
		$sth->execute();
		while( my $h = $sth->fetchrow_hashref() )	{
			$query = 'select max(ordering) from article_field_group_items where parent_id = ?';
			my $ord = $dbh->selectrow_array( $query, undef, $q->param('dst') );
			$ord += 10;
	
			$query = 'insert into article_field_group_items( parent_id, field_id, name, ordering, user_id ) values(?,?,?,?,?)';
			$dbh->do( $query, undef, $q->param('dst'), $h->{id}, $h->{name}, $ord, $G->get_user_id() );
			my $id = $dbh->last_insert_id(undef,undef,undef,undef);
			if( $id )	{
				$query = ' insert into article_field_group_item_aliases(parent_id,lang_id,alias) select ?, lang_id, alias from article_field_aliases where parent_id = ?';
				$dbh->do( $query, undef, $id, $h->{id} );
			}
		}
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_field_group_update' )    {
	if( $q->param('id')  )	{
		if( $q->param('grp') )	{
			my $query = 'update article_field_groups set name = ? where id = ?';
			$dbh->do( $query, undef, $q->param('name'), $q->param('id') );
			
			$query = 'delete from article_field_group_aliases where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );

			$query = 'insert into article_field_group_aliases(parent_id, lang_id, alias) values(?,?,?)';
			
			foreach( $q->param() )	{
				if( $_ =~ /alias_(\d+)/ )	{
					$dbh->do( $query, undef, $q->param('id'), $1, $q->param($_) );		
				}
			}
		}
		else	{
			my $query = 'update article_field_group_items set name = ? where id = ?';
			$dbh->do( $query, undef, $q->param('name'), $q->param('id') );
			
			$query = 'delete from article_field_group_item_aliases where parent_id = ?';
			$dbh->do( $query, undef, $q->param('id') );

			$query = 'insert into article_field_group_item_aliases(parent_id, lang_id, alias) values(?,?,?)';
			
			foreach( $q->param() )	{
				if( $_ =~ /alias_(\d+)/ )	{
					$dbh->do( $query, undef, $q->param('id'), $1, $q->param($_) );		
				}
			}
		}
	}

    my $J = new JSON;
	my $o;
    $o->{success} = 'true';
    
    $G->header( -type => "text/x-json;charset=utf-8" );
    print( $J->encode( $o ) );
    exit 0;
}

if( $action eq 'article_field_group_list' )    {
	my $nid = $q->param('node')||0;

	my @arr;

	unless( $nid )	{
		my $query = 'select id, name, alias from article_field_groups g
			left join article_field_group_aliases a on a.parent_id = g.id and a.lang_id = ?
			where g.parent_id = ? order by g.ordering';
		my $sth = $dbh->prepare( $query );
		$sth->execute( $G->get_lang_id(), $parent_id );

		while( my $h = $sth->fetchrow_hashref() )	{
			$h->{text} = $h->{alias}. ' ( '.$h->{name}.' )';
			push @arr, $h;
		}
	}
	else	{
		my $query = 'select id, name, alias, 1 leaf, field_id  from article_field_group_items i 
			left join article_field_group_item_aliases a on a.parent_id = i.id and a.lang_id = ?  
			where i.parent_id = ? order by ordering';
		my $sth = $dbh->prepare( $query );
		$sth->execute( $G->get_lang_id(), $nid );

		while( my $h = $sth->fetchrow_hashref() )	{
			$h->{text} = $h->{alias}. ' ( '.$h->{field_id}.' / '.$h->{name}.' )';
			push @arr, $h;
		}
	}

    my $J = new JSON;
    $G->header( -type => 'text/x-json; charset=utf-8');
    print( $J->encode( \@arr ) );

    exit 0;
}

#-------------------------------------------------------
#		FIELDS
#-------------------------------------------------------

if( $action eq 'article_field_list' ) {
	my $F = new HellFire::Article::FieldDAO( $dbh, $G );
	$F->set_parent_id( $parent_id );
	my $fields = $F->get_fields( {
		ordering => $q->param( 'sort' )||'name',
		direction => $q->param( 'dir' )||'asc'
	} );

	my @arr;
	foreach ( @$fields ) {
		my $T = new HellFire::DataType( $dbh, $G );
		push @arr,
		  {
			name    => $_->get_name(),
			id      => $_->get_id(),
			alias   => $_->get_alias( $G->get_lang_id ),
			type_alias => $T->get_type_alias( $_->get_type_id() ) || $_->get_type(),
			inherit => ( $parent_id == $_->get_parent_id() ) ? 0 : 1
		  };
	}

	my $h;

	$h->{rows}    = \@arr;
	$h->{results} = scalar @arr;

	my $J = new JSON();
	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $h ) );
	exit 0;
}

if( $action eq 'article_field_view' ) {
	my $J = new JSON;
	my $T = new HellFire::DataType( $dbh, $G );

	my $F = new HellFire::Article::FieldDAO( $dbh, $G );
	$F->load( $id );

	unless( $id ) {
		$F->set_parent_id( $parent_id );
	}

	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	$C->load( $F->get_parent_id() );

	my @items_flags;

	my $ff = $B->get_set_values( 'article_fields', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags, {
			xtype      => 'checkbox',
			fieldLabel => 'FLAG_'.$_,
			name       => 'article_flag',
			autoHeight => 1,
			checked    => $F->get_flag( $_ ),
			value      => $_,
			inputValue => $_

		};
	}

	my @items_l10n;

	my $l = $T->get_languages();
	foreach ( @$l ) {
		push @items_l10n,
		  {
			xtype      => 'textfield',
			fieldLabel => $_->{alias},
			name       => 'alias_' . $_->{id},
			autoHeight => 1,
			value      => $F->get_alias( $_->{id} ),
			inputValue => $F->get_alias( $_->{id} )
		  };
	}

	my $grp_name = $dbh->selectrow_array( 'select name from configuration where id = ?', undef, $F->get_source_group_id() || 0 );
	my $grp_alias = $dbh->selectrow_array( 'select if(length(a.alias)>0,a.alias,c.name) from configuration c, configuration_aliases a where a.parent_id = c.id and c.id = ?', undef, $F->get_source_group_id() || 0 );

	my $src_cat_name;
	if( $grp_name ) {
		$src_cat_name = $dbh->selectrow_array( "select if(length(a.alias)>0,a.alias,c.name) from $grp_name\_categories c, $grp_name\_category_aliases a where a.parent_id = c.id and c.id = ?", undef, $F->get_source_id() );
	}

	my $UC = new HellFire::Configuration::CategoryDAO( $dbh, $G );
	my $act = $UC->get_actions( $UC->find( 'article_lib' ) );

	my @items_actions;
	foreach ( @$act ) {
		push @items_actions, { name => $_->{name}, id => $_->{id} } if( $_->{name} =~ /field/ );
	}

	my $hash = {
		flags   => \@items_flags,
		items_l10n    => \@items_l10n,
		items_actions => \@items_actions,
		id            => $F->get_id(),
		parent_id     => $F->get_parent_id(),
		parent_alias  => $C->get_alias( $G->get_lang_id ),
		inserted      => $F->get_inserted(),
		name          => $F->get_name(),
		ordering      => $F->get_ordering(),
		type_name     => $T->get_type_name( $F->get_type_id() ),
		type_alias    => $T->get_type_alias( $F->get_type_id() ),
		group_name    => $grp_name,
		group_alias   => $grp_alias,
		category_name => $src_cat_name
	};

	my $js = $J->encode( $hash );
	$G->header( -type => "text/x-json;charset=utf8" );
	print( $js );

	exit 0;
}

if( $action eq 'article_field_update' || $action eq 'article_field_add' ) {
	my $J = new JSON;
	my $C = new HellFire::Article::FieldDAO( $dbh, $G );
	$C->load( $id );

	$C->set_name( $q->param( 'name' ) );
	$C->set_user_id( $G->get_user_id() );
	$C->set_ordering( $q->param( 'ordering' ) );
	$C->set_group_access( $J->decode( $q->param( 'access' ) ) ) if( $C->get_id() );

	unless( $id ) {
		$C->set_type_id( $q->param( 'type_id' ) );
		$C->set_parent_id( $q->param( 'parent_id' ) );
		$C->set_source_group_id( $q->param( 'source_group_id' ) );
		$C->set_source_id( $q->param( 'source_category_id' ) );
	}

	foreach ( $q->param() ) {
		if( $_ =~ /alias_(\d+)/ ) {
			$C->set_alias( $1, $q->param( "alias_$1" ) );
		}
	}

	foreach ( $q->param( 'article_flag' ) ) {
		next if( $_ eq 'DELETED' );
		$C->set_flag( $_ );
	}

	$C->save();

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_datatypes' ) {
	my $J = new JSON;
	my $D = new HellFire::DataType( $dbh, $G );
	my $d = $D->get_data_types();

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $d ) );
	exit 0;
}

if( $action eq 'article_field_order' ) {
	my $J = new JSON;
	my $C = new HellFire::Article::FieldDAO( $dbh, $G );

	my $ord = 10;
	foreach ( split( /,/, $q->param( 'ord' ) ) ) {
		$C->load( $_ );
		$C->set_ordering( $ord );
		$C->save();
		$ord += 10;
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_field_delete' ) {
	my $J = new JSON;
	my $C = new HellFire::Article::FieldDAO( $dbh, $G );

	foreach ( split( /,/, $q->param( 'id' ) ) ) {
		$C->load( $_ );
		$C->destroy();
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_access_list' ) {
	my $J   = new JSON;
	my $UC  = new HellFire::User::CategoryDAO( $dbh, $G );
	my $grp = $UC->get_all_siblings();
	$UC->set_name( 'guest' );
	$UC->set_id( 0 );
	push @$grp, $UC;

	my $UC  = new HellFire::Configuration::CategoryDAO( $dbh, $G );
	my $act = $UC->get_actions( $UC->find( 'article_lib' ) );
	my @f   = ( { name => 'id' }, { name => 'name' } );
	foreach my $a ( @$act ) {
		push @f, { name => "field_" . $a->{id} };
	}

	my @arr;
	foreach ( @$grp ) {
		next if( $_->get_name() eq 'administrator' );
		my $h = { name => $_->get_name(), id => $_->get_id() };

		#push @f, {name => "field_".$_->get_id()};
		foreach my $a ( @$act ) {
			$h->{ 'field_' . $a->{id} } = $dbh->selectrow_array( 'select 1 from article_field_access where parent_id = ? and group_id = ? and action_id = ?', undef, $parent_id, $_->get_id(), $a->{id} ) || 0;
		}

		push @arr, $h;
	}

	my $h;
	$h->{metaData} = { totalProperty => 'results', root => 'rows', id => 'id', fields => \@f };
	$h->{rows}     = \@arr;
	$h->{results}  = scalar @arr;

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( $h ) );
	exit 0;
}

$G->header();
exit 0;

