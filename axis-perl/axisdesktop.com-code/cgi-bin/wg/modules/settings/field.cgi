#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::DataType;
use HellFire::Settings::FieldDAO;
use HellFire::Settings::CategoryDAO;
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

if( $action eq 'settings_field_list' ) {
	my $F = new HellFire::Settings::FieldDAO( $dbh, $G );
	$F->set_parent_id( $parent_id );
	my $fields = $F->get_fields();

	my @arr;
	foreach ( @$fields ) {
		my $T = new HellFire::DataType( $dbh, $G );
		push @arr,
		  {
			name    => $_->get_name(),
			id      => $_->get_id(),
			alias   => $_->get_alias( $G->get_lang_id ) || $_->get_name(),
			type_alias => $T->get_type_alias( $_->get_type_id() ) || $_->get_type(),
			inherit => ( $parent_id == $_->get_parent_id() ) ? 0 : 1
		  };
	}

	my $h;

	#$h->{metaData} = { totalProperty => 'results', root => 'rows', id => 'id', fields => \@ff };
	$h->{rows}    = \@arr;
	$h->{results} = scalar @arr;

	my $J = new JSON();
	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $h ) );
	exit 0;
}

if( $action eq 'settings_field_view' ) {
	my $J = new JSON;
	my $T = new HellFire::DataType( $dbh, $G );

	my $F = new HellFire::Settings::FieldDAO( $dbh, $G );
	$F->load( $id );

	unless( $id ) {
		$F->set_parent_id( $parent_id );
	}

	my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
	$C->load( $F->get_parent_id() );

	my @items_flags;

	my $ff = $B->get_set_values( 'settings_fields', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags, {
			xtype      => 'checkbox',
			fieldLabel => $_,
			name       => 'settings_flag',
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
	my $act = $UC->get_actions( $UC->find( 'settings_lib' ) );

	my @items_actions;
	foreach ( @$act ) {
		push @items_actions, { name => $_->{name}, id => $_->{id} } if( $_->{name} =~ /field/ );
	}

	my $hash = {
		items_flags   => \@items_flags,
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

if( $action eq 'settings_field_update' || $action eq 'settings_field_add' ) {
	my $J = new JSON;
	my $C = new HellFire::Settings::FieldDAO( $dbh, $G );
	$C->load( $id );

	$C->set_name( $q->param( 'name' ) );
	$C->set_user_id( $G->get_user_id() );
	$C->set_ordering( $q->param( 'ordering' ) );
	$C->set_group_access( $J->decode( $q->param( 'access' ) ) ) if( $C->get_id() );

	unless( $id ) {
		$C->set_type_id( $q->param( 'type_id' ) );
		$C->set_parent_id( $q->param( 'parent_id' ) );
		$C->set_source_group_id( $q->param( 'source_group_id' ) );
		$C->set_source_id( $q->param( 'source_id' ) );
	}

	foreach ( $q->param() ) {
		if( $_ =~ /alias_(\d+)/ ) {
			$C->set_alias( $1, $q->param( "alias_$1" ) );
		}
	}

	foreach ( $q->param( 'settings_flag' ) ) {
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

if( $action eq 'settings_datatypes' ) {
	my $J = new JSON;
	my $D = new HellFire::DataType( $dbh, $G );
	my $d = $D->get_data_types();

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $d ) );
	exit 0;
}

if( $action eq 'settings_field_delete' ) {
	my $J = new JSON;
	my $C = new HellFire::Settings::FieldDAO( $dbh, $G );

	foreach ( $q->param( 'id' ) ) {
		$C->load( $q->param( 'id' ) );
		$C->destroy();
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'settings_access_list' ) {
	my $J   = new JSON;
	my $UC  = new HellFire::User::CategoryDAO( $dbh, $G );
	my $grp = $UC->get_all_siblings();
	$UC->set_name( 'guest' );
	$UC->set_id( 0 );
	push @$grp, $UC;

	my $UC  = new HellFire::Configuration::CategoryDAO( $dbh, $G );
	my $act = $UC->get_actions( $UC->find( 'settings_lib' ) );
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
			$h->{ 'field_' . $a->{id} } = $dbh->selectrow_array( 'select 1 from settings_field_access where parent_id = ? and group_id = ? and action_id = ?', undef, $parent_id, $_->get_id(), $a->{id} ) || 0;
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

