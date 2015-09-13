#!/usr/bin/perl

use strict;
use CGI; 
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use JSON;
use HellFire::DataBase;
use HellFire::DataType;
use HellFire::Site::CategoryDAO;
use HellFire::Site::TemplateDAO;
use HellFire::Guard;
use HellFire::Config;
use HellFire::User::CategoryDAO;
use HellFire::Configuration::CategoryDAO;

my $INI = new HellFire::Config();

my $B = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
	
my $q = new CGI;

my $G = new HellFire::Guard( $dbh, $q, $INI ); 
$G->check_session();

my $parent_id = $q->param('pid')||0;
my $id = $q->param('id') || 0;
my $action = $q->param('action') || '';

if( $action eq 'site_domain_list' )   {
    my $J = new JSON;

    my @arr; 
    my $query = 'select * from site_aliases where parent_id = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute( $parent_id );
    while( my $h = $sth->fetchrow_hashref )	{
	    push @arr, $h;
    }

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
		fields          => [ { name => "id" }, { name => "name" } ],
		sortInfo        => {
			field     => $order_by,
			direction => $direction
		}
	};
	$res->{totalCount} = scalar @arr;
	$res->{rows}       = \@arr;
	$res->{columns}    = [
		{ dataIndex => "id", header => "labelID", sortable => 'true', width => 10 },
		{ dataIndex => "name",     header => "labelName",     sortable => 'true' }
	];


    $G->header( -type => "text/x-json; charset=utf-8");
    print( $J->encode( $res ) );
    exit 0;
}

if( $action eq 'site_domain_update' )   {
    my $J = new JSON;

	my $query = 'insert into site_aliases(name, parent_id) values(?,?)';
	$dbh->do( $query, undef, $q->param('name'), $q->param('parent_id') );

    my $o ;
    $o->{success} = 1;

    $G->header( -type => "text/x-json");
    print( $J->encode( $o ) );
    exit 0;
}

if( $action eq 'site_domain_view' )   {
    my $J = new JSON;
    my $S = new HellFire::Site::CategoryDAO( $dbh, $G ); 
    $S->load( $parent_id );

    my $query = 'select * from site_aliases where id = ?';
    my $h = $dbh->selectrow_hashref( $query, undef, $id); 	

    my $o;
    $o->{id} = $h->{id};
    $o->{parent_id} = $S->get_id();
    $o->{parent_alias} = $S->get_name();
    $o->{name} = $h->{name};


    $G->header( -type => "text/x-json; charset=utf-8");
    print( $J->encode( $o ) );
    exit 0;
}



my $o ;
$o->{failure} = 'true';
my $J = new JSON;
$G->header( -type => "text/x-json;charset=utf-8");
print( $J->encode($o) );

exit 0;





