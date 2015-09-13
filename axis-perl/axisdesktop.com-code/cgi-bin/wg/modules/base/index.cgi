#!/usr/bin/perl 

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use CGI::Minimal;
use HellFire::Site::CategoryDAO;
use HellFire::DataBase;
use HellFire::Guard;
use JSON;
use HellFire::Config;
use HellFire::Response;

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
my $q   = new CGI::Minimal;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;
my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );

my $action = $q->param( 'action' ) || '';

if( $action eq 'base_category_list' ) {
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );

	my $id = $q->param( 'node' ) || 0;
	my $lang_id = $G->get_lang_id();

	my $nodes = $C->get_all_siblings( $id );

	my @res;
	foreach ( @$nodes ) {
		push @res, {
			id   => $_->get_id(),
			text => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),

			#       leaf => ( $_->get_children() ) ? 0 : 1
		};
	}

	print( $J->encode( \@res ) );
	exit 0;
}

if( $action eq 'base_category_list_tree' ) {
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );

	my $id = $q->param( 'node' ) || 0;
	my $lang_id = $G->get_lang_id();

	my $nodes = $C->get_all_siblings( $id );

	my @res;
	foreach ( @$nodes ) {
		push @res, {
			id    => $_->get_id(),
			alias => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),

			#       leaf => ( $_->get_children() ) ? 0 : 1
		};
	}

	print( $J->encode( \@res ) );
	exit 0;
}

if( $action eq 'base_item_list' ) {
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );

	my $parent_id = $q->param( 'pid' )   || 0;
	my $order_by  = $q->param( 'sort' )  || 'id';
	my $direction = $q->param( 'dir' )   || 'desc';
	my $start     = $q->param( 'start' ) || 0;
	my $limit     = $q->param( 'limit' ) || 50;
	my $rowsc     = 0;

	my $eee = $C->get_grid(
		{
			parent_id       => $parent_id,
			order_id        => $order_by,
			order_direction => $direction,
			offset          => $start,
			limit           => $limit,
			count_all       => \$rowsc
		}
	);

	my $res;
	$res->{totalCount} = $rowsc;
	$res->{rows}       = $eee;

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'save_session_state' ) {
	if( $q->param( 'user' ) ) {
		my $query = "replace into user_session_state ( user_id, name, value ) values( ?, ?, ?)";
		foreach ( @{ $J->decode( $q->param( 'data' ) ) } ) {
			$dbh->do( $query, undef, $q->param( 'user' ), $_->{'name'}, $_->{'value'} );
		}
	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

print( $J->encode( { success => 0 } ) );
exit 0;
