#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI;
use JSON;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::Config;


my $INI = new HellFire::Config();
my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;
my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $action    = $q->param( 'action' ) || '';
my $parent_id = $q->param( 'pid' )    || 0;
my $id        = $q->param( 'id' )     || 0;

unless( $G->is_administrator() )    {
    my $J = new JSON;
    $G->header( $J->encode( { succes => 0, failure => 1 } ) );
    exit 0;
}

if( $action eq 'configuration_category_list' )  {    
    my @res;
    my $node = $q->param( 'node' );
    if( $q->param( 'node' ) eq '0' )   {
        my @arr = ('HANDLER','STORE','STANDALONE','LIB','RESOURCE','PROXY','TOOL','PLUGIN','');
        foreach ( @arr ) {
            push @res, {
                id   => $_,
                text => $_||'NO_TYPE',
               # qtip => 'id: ' . $_,
                leaf => 1,
                cls => 'x-tree-node-collapsed'
            };
        }
    }

	my $J = new JSON;
	$G->header( -type => 'text/x-json; charset=utf-8' );
	print( $J->encode( \@res ) );

	exit 0;
}

if( $action eq 'configuration_store_list' )   {
        my $query = 'select c.id, name, if(isnull(a.alias),name,a.alias) alias from configuration c left join configuration_aliases a
                        on a.parent_id = c.id and a.lang_id = ?
                        where find_in_set("DELETED",flags) = 0 and type = "STORE" order by name';
        my $sth = $dbh->prepare( $query );
        $sth->execute( $G->get_lang_id() );
        my @arr;
        while( my $h = $sth->fetchrow_hashref() )   {
                push @arr, $h;
        }

        my $J = new JSON;
        $G->header( -type => "text/x-json;charset=utf-8");
        print( $J->encode( \@arr ) );
        exit 0;
}


my $J = new JSON;
$G->header( $J->encode( { succes => 0, failure => 1 } ) );
exit 0;