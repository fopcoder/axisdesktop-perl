#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use JSON;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::Config;
use HellFire::Update;
use HellFire::Configuration::ItemDAO;
use CGI::Minimal;
use HellFire::Response;

my $INI = new HellFire::Config();

my $B = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI::Minimal;
my $G = new HellFire::Guard( $dbh, $q, $INI ); 
$G->check_session();

my $R = new HellFire::Response;

my $pid = $q->param('pid')||0;
my $id = $q->param('id')||0;
my $ids = $q->param('ids')||'';
my $action = $q->param('action')||'' ;

if( $action eq 'configuration_item_list' )	{
    my $order_by = $q->param('sort') || 'ordering';
    my $direction = $q->param('dir') || 'desc';
    my $start = $q->param('start') || 0;
    my $limit = $q->param('limit') || 50;
    my $rowsc = 0;
    
    my $I = new HellFire::Configuration::ItemDAO( $dbh, $G );

    my $eee = $I->get_grid(  {
		type => $pid||'', 
	    order_id => $order_by, 
	    order_direction => $direction,
	    offset => $start, 
	    limit => $limit,
        with_inserted =>1,
        with_ordering => 1,
        with_version => 1,
	    count_all => \$rowsc
	} );

    my $res;
	$res->{metaData} = {
		id => "id",
        root => "rows",
        totalProperty => "totalCount",
        successProperty => "success",
        fields => [
            { name => "id"},
			{ name => "name"},
			{ name => "inserted"},
            { name => "alias", mapping => "alias"},
            { name => "ordering" },
            { name => "version" }
        ],
        sortInfo => {
           field => $order_by,
           direction => $direction
        }
	};
    $res->{totalCount} = $rowsc;
    $res->{rows} = $eee;
	$res->{columns} = [
		{ dataIndex => "id", header => "labelID", sortable => 'true' },
		{ dataIndex => "name", header => "labelName", sortable => 'true' },
		{ dataIndex => "alias", header => "labelAlias", sortable => 'true' },
		{ dataIndex => "inserted", header => "labelInserted", sortable => 'true' },
        { dataIndex => "version", header => "labelVersion", sortable => 'false' },
        { dataIndex => "ordering", header => "#", sortable => 'true' }
	];
		
    my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'configuration_item_view')   {
    my $I = new HellFire::Configuration::ItemDAO( $dbh, $G );
    $I->load( $id, { with_action_list => 1, no_clean => 1 } );
    
    my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
    print( $J->encode( $I->to_template() ) );	
	exit 0;
}

if( $action eq 'configuration_access_list' ) {
	my $I = new HellFire::Configuration::ItemDAO( $dbh, $G );
    $I->load( $id );
    my $rows = $I->get_access_list();
    
    my $res;
	$res->{metaData} = {
		id => "id",
        root => "rows",
        totalProperty => "totalCount",
        successProperty => "success",
        fields => [
            { name => "group"},
			{ name => "group_id"},
			{ name => "action"},
            { name => "action_id"},
            { name => "value" }
        ],
        sortInfo => {
           field => 'action',
           direction => 'desc'
        }
	};
    $res->{totalCount} = scalar @$rows;
    $res->{rows} = $rows;

	my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'configuration_item_update' )    {
    my $J = new JSON;
    my $I = new HellFire::Configuration::ItemDAO( $dbh, $G );
    $I->load( $id, { no_clean => 1 } );
    
    foreach ( $q->param() ) {
        next if( $_ eq 'id' );
        next if( $_ eq 'action' );
        if( $_ eq 'json_access' )  {
            $I->set_json_access( $J->decode( $q->param( 'json_access' ) ) );
            next;
        }
        if( $_ =~ /alias_(\d+)/ ) {
			$I->set_alias( $1, $q->param( $_ ) );
            next;
		}
        if( $_ =~ /description_(\d+)/ ) {
			$I->set_description( $1, $q->param( $_ ) );
            next;
		}
        my $f = "set_$_";
        $I->$f( $q->param( $_) );        
    }

    $I->save();    
	
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( { succes => 1 } ) );
	exit 0;

}


if( $action eq 'configuration_all_packages' )	{
	my $U = new HellFire::Update( $dbh, $G );
	my $rnd = int rand 1000000;
	`mkdir /tmp/$rnd`;
	`wget http://javahosting.com.ua/repo/packages2.ini -O /tmp/$rnd/packages2.ini`;
	my @arr;
        my $Config = Config::Tiny->read( "/tmp/$rnd/packages2.ini" );

	foreach ( keys %$Config )	{
		my $allow = 0;
		if( $INI->obj->{modules} )	{
		    $allow = $INI->obj->{modules}->{$_};
		}
		else	{
		    $allow = 1;
		}
		if( $allow )	{
		    my $v = $dbh->selectrow_array('select version from configuration where name = ?', undef, $_);
		    my $h;
		    $h->{name} = $_;
		    $h->{version} = $Config->{$_}->{version};
		    $h->{file} = $Config->{$_}->{file};
		    $h->{update} = 1 if( $U->get_int_version( $v ) != $U->get_int_version( $h->{version} ) );
		    push @arr, $h;
		}
	}

	@arr = sort { $a->{name} cmp $b->{name} } @arr;	

	my @f = ({name => 'id'},{name => 'name'},{name=>'version'},{name=>'file'},{name=>'update'});
	my $h;
	$h->{metaData} = { totalProperty => 'results', root => 'rows', id => 'id',fields => \@f};
	$h->{rows} = \@arr;
	$h->{results} = scalar @arr;

	`rm -rf /tmp/$rnd` if( $rnd );

	my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( $h ) );
	exit 0;
}

if( $action eq 'configuration_modules_update' )	{
	my $file = $q->param('file')||'-';
	my $name = $q->param('name')||'-';
	my $version = $q->param('version')||'-';

	my $U = new HellFire::Update( $dbh, $G );
	if( $G->is_administrator() && $q->param('file') && $q->param('name') && $q->param('version') )	{
	    $U->setup_module( $name, $file, $version );
	}

	my $h;
	$h->{success} = 1;

	my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( $h ) );
	exit 0;
}

if( $action eq 'configuration_handlers_list' ) {
	require HellFire::Configuration::CategoryDAO;
	my $C = new HellFire::Configuration::CategoryDAO( $dbh, $G );
	my $h = $C->get_handlers();

	my @a;
	push @a, { id => 0, alias => '-' };
	foreach ( @$h ) {
		push @a, { id => $_->get_id(), alias => $_->get_alias( $G->get_lang_id() ) || $_->get_name() };
	}

	my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( \@a ) );
	exit 0;
}


#
#
#if( $action eq 'configuration_list' )	{
#	my $query = 'select c.id, name, if(isnull(a.alias),name,a.alias) alias from configuration c left join configuration_aliases a
#			on a.parent_id = c.id and a.lang_id = ?
#			where find_in_set("DELETED",flags) = 0 and type = "STORE" order by name';
#	my $sth = $dbh->prepare( $query );
#	$sth->execute( $G->get_lang_id() );
#	my @arr;
#	while( my $h = $sth->fetchrow_hashref() )   {
#		push @arr, $h;
#	}
#
#	my $J = new JSON;
#	$G->header( -type => "text/x-json;charset=utf-8");
#	print( $J->encode( \@arr ) );	
#	exit 0;
#}
#

#

#





my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
print( $J->encode( { succes => 0, failure => 1 } ) );
exit 0;