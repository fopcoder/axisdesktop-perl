#!/usr/bin/perl

use strict;
use CGI;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use JSON;
use HellFire::DataBase;
use HellFire::Site::TemplateDAO;
use HellFire::Guard;
use HellFire::Config;
use HellFire::User::CategoryDAO;
use HellFire::Configuration::CategoryDAO;

my $INI = new HellFire::Config();

warn $INI->template_dir();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $parent_id = $q->param( 'pid' )    || 0;
my $id        = $q->param( 'id' )     || 0;
my $action    = $q->param( 'action' ) || '';

if( $action eq 'site_template_list' ) {
	my $J = new JSON;
	my $C = new HellFire::Site::TemplateDAO( $dbh, $G );
	$C->set_parent_id( $parent_id );
	my $t = $C->get_templates();

	my @arr;
	foreach ( @$t ) {
		push @arr,
		  {
			name     => $_->get_name(),
			id       => $_->get_id(),
			alias    => $_->get_alias( $G->get_lang_id() ),
			inserted => $_->get_inserted()
		  };
	}

	#my $h;
	#$h->{metaData} = { totalProperty => 'results', root => 'rows', id => 'id', fields => [ { name => 'id' }, { name => 'name' }, { name => 'alias' } ] };
	#$h->{rows}     = \@arr;
	#$h->{results}  = scalar @arr;

	my $order_by  = $q->param( 'sort' )  || 'id';
	my $direction = $q->param( 'dir' )   || 'desc';
	my $start     = $q->param( 'start' ) || 0;
	my $limit     = $q->param( 'limit' ) || 50;
	my $rowsc     = 0;

	my $res;
	$res->{metaData} = {
		id              => "id",
		root            => "rows",
		totalProperty   => "totalCount",
		successProperty => "success",
		fields          => [ { name => "id" }, { name => "name" }, { name => "inserted" }, { name => "alias", mapping => "alias" } ],
		sortInfo        => {
			field     => $order_by,
			direction => $direction
		}
	};
	$res->{totalCount} = scalar @arr;
	$res->{rows}       = \@arr;
	$res->{columns}    = [
		{ dataIndex => "id",       header => "labelID",       sortable => 'true' },
		{ dataIndex => "name",     header => "labelName",     sortable => 'true' },
		{ dataIndex => "alias",    header => "labelAlias",    sortable => 'true' },
		{ dataIndex => "inserted", header => "labelInserted", sortable => 'true' },
		{ dataIndex => "user_id",  header => "labelOwner",    sortable => 'true' }
	];

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'site_template_item_list' ) {
	my $J = new JSON;
	my $C = new HellFire::Site::TemplateDAO( $dbh, $G );
	$C->set_parent_id( $parent_id );
	my $t = $C->get_templates();

	my @arr;
	push @arr, { id => 0, alias => '-' };
	foreach ( @$t ) {
		push @arr,
		  {
			id       => $_->get_id(),
			alias    => $_->get_alias( $G->get_lang_id() )||$_->get_name()
		  };
	}

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( \@arr ) );
	exit 0;
}


if( $action eq 'site_template_view' ) {
	my $J = new JSON;
	my $C = new HellFire::Site::TemplateDAO( $dbh, $G );
	$C->load( $id );
	my $S = new HellFire::Site::CategoryDAO( $dbh, $G );
	$S->load( $C->get_parent_id() || $parent_id );

	my $res;
	$res->{id}           = $C->get_id();
	$res->{parent_id}    = $S->get_id();
	$res->{parent_alias} = $S->get_name();
	$res->{inserted}     = $C->get_inserted();
	$res->{name}         = $C->get_name();

	my $T = new HellFire::DataType( $dbh );
	my $l = $T->get_languages();
	
	my $tpl = [];
	
	foreach ( @$l ) {
		my $tlang = {
			title => $_->{alias},
			itemId => $_->{name},
			autoHeight => 1,
			bodyStyle => 'padding:5px;',
			layout => 'form',
			defaults => {
				width => '100%',
			},
			items => []
		};
		
		push @{ $tlang->{items} }, {
			xtype => 'textfield',
			fieldLabel => 'labelAlias',
			name => 'alias_'.$_->{id},
			itemId => 'alias',
			value => $C->get_alias( $_->{id} )
		};
		
		push @{ $tlang->{items} }, {
			xtype => 'textfield',
			hidden => 1,
			itemId => 'content',
			name => 'content_'.$_->{id},
			value => ( $C->get_content( $_->{id} ) ) ? $C->get_content( $_->{id} )->{content} : ''
		};
		
		push @{ $tlang->{items} }, {
			xtype => 'uxCodeMirrorPanel',
			#xtype => 'ux-codemirror',
			height => '90%',
			#autoHeight => 1,
			width => '100%',
			codeMirrorPath => "/res/codemirror",
			language => 'tpl',
			lineNumbers => 0,
			parser => 'tpl',
			hideLabel => 1,
			itemId => 'body',
			name => 'body_'.$_->{id},
			id => 'body_'.$C->get_id().'_'.$_->{id},
			value => ( $C->get_content( $_->{id} ) ) ? $C->get_content( $_->{id} )->{body} : ''
		};
		
		push @$tpl, $tlang;
	}

	$res->{tpl} = $tpl;

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'site_template_update' ) {
	my $J = new JSON;
	my $T = new HellFire::Site::TemplateDAO( $dbh, $G );

	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );

	$T->set_parent_id( $C->get_top_parent_id( $q->param( 'parent_id' ) ) );

	#$T->set_parent_id( $q->param('parent_id') );
	$T->set_id( $id );
	$T->set_name( $q->param( 'name' ) || '' );

	my $D = new HellFire::DataType( $dbh );
	my @items_l10n;
	my $l = $D->get_languages();
	foreach ( @$l ) {
		$T->{_content}->{ $_->{id} }->{parent_id} = $id;
		$T->{_content}->{ $_->{id} }->{alias}     = $q->param( 'alias_' . $_->{id} ) || '';
		$T->{_content}->{ $_->{id} }->{lang_id}   = $_->{id};
		$T->{_content}->{ $_->{id} }->{content}   = $q->param( 'content_' . $_->{id} ) || '';
		$T->{_content}->{ $_->{id} }->{body}      = $q->param( 'body_' . $_->{id} ) || '';
	}

	$T->save();

	my $o;
	$o->{success} = 1;

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'site_template_copy' ) {
	my $J = new JSON;
	my $ids = $q->param( 'ids' ) || '';
	my $D = new HellFire::DataType( $dbh );
	my $l = $D->get_languages();
	
	foreach( split(/,/, $ids) )	{
		my $T = new HellFire::Site::TemplateDAO( $dbh, $G );
		if( $T->load( $_ ) )	{
		
			#my $C = new HellFire::Site::CategoryDAO( $dbh, $G );
			foreach my $l ( @$l ) {
				$T->{_content}->{ $l->{id} }->{content} = '';
			}
		
			$T->set_id( 0 );
			$T->set_name( $T->get_name() . '_copy' );
			$T->save();
		}
	}
	my $o;
	$o->{success} = 1;

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'site_template_delete' ) {
	my $J = new JSON;
	my $T = new HellFire::Site::TemplateDAO( $dbh, $G );

	my $ids = $q->param( 'ids' ) || '';
	foreach ( split( /,/, $ids ) ) {
		my $T = new HellFire::Site::TemplateDAO( $dbh, $G );
		$T->set_id( $_ );
		$T->destroy();
	}

	my $o;
	$o->{success} = 1;

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;
}

my $o;
$o->{failure} = 'true';
my $J = new JSON;
$G->header( -type => "text/x-json;charset=utf-8" );
print( $J->encode( $o ) );

exit 0;

