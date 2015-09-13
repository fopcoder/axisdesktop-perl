#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI;
use HellFire::DataBase;
use HellFire::DataType;
use HellFire::Guard;
use HellFire::Settings::CategoryDAO;
use JSON;
use HellFire::Config;
use HellFire::Configuration::CategoryDAO;
use HellFire::User::CategoryDAO;

my $INI = new HellFire::Config();
my $B = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;
my $G = new HellFire::Guard( $dbh, $q, $INI ); 
$G->check_session();

my $action = $q->param('action')||'' ;
my $parent_id = $q->param('pid')||0;
my $id = $q->param('id') || 0;


if( $action eq 'settings_category_list' )    {
    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );

    my $id = $q->param('node')||0;
    my $lang_id = $G->get_lang_id();

    my $nodes = $C->get_all_siblings( $id );

    my @res;
    foreach( @$nodes )	{
	push @res, { 
	    id => $_->get_id(), 
	       text => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),
		qtip => 'id: '.$_->get_id(),
	       #leaf => ( $_->get_children() ) ? 0 : 1
	};	
	unless( $_->get_children() )    {
	    my @w;
	    $res[-1]->{children} = \@w;
	}
    }

    my $J = new JSON;
    $G->header( -type => 'text/x-json; charset=utf-8');
    print( $J->encode( \@res ) ); 

    exit 0;
}


if( $action eq 'settings_category_move' && $q->param('src') && $q->param('dst') )    {
    my $J = new JSON;
    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
    $C->load( $q->param('src') ); 
    $C->move( $q->param('dst') );
    
    my $o ;
    $o->{success} = 1;

    $G->header( -type => "text/x-json");
    print( $J->encode( $o ) );
    exit 0;
}	

if( $action eq 'settings_category_properties_view' )	{
    my $J = new JSON;

    my $R = new HellFire::Settings::CategoryDAO( $dbh, $G ); 
    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
    if( $q->param('add') )	{
	$R->set_parent_id( $id );
    }
    else	{
	$R->load( $id );
    }

    $C->load( $R->get_parent_id() );

    my $hash;
    $hash->{id} = $R->get_id();
    $hash->{parent_id} = $R->get_parent_id();
    $hash->{parent_name} = $C->get_alias( $G->get_lang_id() )||$C->get_name();
    $hash->{inserted} = $R->get_inserted();
    $hash->{name} = $R->get_name();
    $hash->{ordering} = $R->get_ordering();

    my @items_flags;

    my $ff = $B->get_set_values('settings_categories','flags');
    foreach ( @$ff )    {
	next if( $_ eq 'DELETED' );
	push @items_flags, {
	    xtype => 'checkbox',
		  fieldLabel => $_,
		  name => 'settings_flag',
		  autoHeight => 1,
		  checked => $R->get_flag($_),
		  inputValue => $_
	};
    };

    my @items_l10n;

    use HellFire::DataType;
    my $T = new HellFire::DataType( $dbh );

    my $l = $T->get_languages();
    foreach( @$l )	{
	push @items_l10n, {
	    xtype => 'textfield',
		  fieldLabel => $_->{alias},
		  name => 'alias_'.$_->{id},
		  autoHeight => 1,
		  value => $R->get_alias( $_->{id} ),
		  inputValue => $R->get_alias( $_->{id} )
	};
    }

    my $UC = new HellFire::Configuration::CategoryDAO( $dbh, $G );
    my $act = $UC->get_actions( $UC->find('settings_lib') );

    my @items_actions;
    foreach( @$act )     {
	push @items_actions, { name => $_->{name}, id => $_->{id} };
    }

    $hash->{items_flags} = \@items_flags;
    $hash->{items_l10n} = \@items_l10n;
    $hash->{items_actions} = \@items_actions;

    $G->header( -type => "text/x-json; charset=utf-8");
    print( $J->encode( $hash ) );
    exit 0;
}

if( $action eq 'settings_access_list' ) {
    my $J = new JSON;
    my $UC = new HellFire::User::CategoryDAO( $dbh, $G );
    my $grp = $UC->get_all_siblings();
    $UC->set_name('guest');
    $UC->set_id(0);
    push @$grp, $UC;

    my $UC = new HellFire::Configuration::CategoryDAO( $dbh, $G );
    my $act = $UC->get_actions( $UC->find('settings_lib') );
    my @f = ({name => 'id'},{name => 'name'});
    foreach my $a ( @$act )    {
	push @f, { name => "field_".$a->{id} };
    }

    my @arr; 
    foreach( @$grp )	{
	next if( $_->get_name() eq 'administrator' );
	my $h = { name => $_->get_name(), id => $_->get_id() };
	#push @f, {name => "field_".$_->get_id()};
	foreach my $a ( @$act )    {
	    $h->{ 'field_'.$a->{id} } = $dbh->selectrow_array('select 1 from settings_category_access where parent_id = ? and group_id = ? and action_id = ?', undef, $parent_id, $_->get_id(), $a->{id} )||0;
	}
	
	push @arr, $h;
    }

    my $h;
    $h->{metaData} = { totalProperty => 'results', root => 'rows', id => 'id',fields => \@f};
    $h->{rows} = \@arr;
    $h->{results} = scalar @arr;

    $G->header( -type => "text/x-json; charset=utf-8");
    print( $J->encode( $h ) );
    exit 0;
}

if( $action eq 'settings_category_update' )	{
    my $J = new JSON;

    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
    $C->load( $q->param('id')||0 );
    $C->set_parent_id( $q->param('parent_id') );
    $C->set_name( $q->param('name') );
    $C->set_ordering( $q->param('ordering') );
    $C->set_id( $q->param('id')||0 );
    $C->set_group_access( $J->decode( $q->param('access') ) ) if( $C->get_id() );

    foreach( $q->param() )	{
	if( $_ =~ /alias_(\d+)/ )	{
	    $C->set_alias( $1, $q->param("alias_$1") );
	}
    }

    foreach( $q->param('settings_flag') )	{
	next if( $_ eq 'DELETED' );
	$C->set_flag( $_ );
    }

    $C->save();

    if( $q->param('raccess_category') )     {
	    my $cc = $C->get_all_children();
		 push @$cc, $C;
	    foreach my $i ( reverse @$cc )  {
		    if( $C->get_id() != $i->get_id() )	{
			$i->clear_access();
			$i->set_access();
		    }
		    if( $q->param('raccess_field') )        {
			    require HellFire::Settings::FieldDAO;
			    my $F = new HellFire::Settings::FieldDAO( $dbh, $G );
			    $F->set_parent_id( $i->get_id() );
			    my $ff = $F->get_fields();
			    foreach my $j ( @$ff )  {
				    $j->clear_access();
				    $j->set_access();
			    }
		    }
		    if( $q->param('raccess_item') ) {
			    require HellFire::Settings::ItemDAO;
			    my $I = new HellFire::Settings::ItemDAO( $dbh, $G );
			    my $ii = $I->get_all_siblings( $i->get_id() );
			    foreach my $j ( @$ii )  {
				    $j->clear_access();
				    $j->set_access();
			    }
		    }
	    }
    }

    my $o ;
    $o->{success} = 'true';

    $G->header( -type => "text/x-json;charset=utf-8");
    print( $J->encode($o) );
    exit 0;
}

if( $action eq 'settings_category_delete' )	{
    my $J = new JSON;
    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
    $C->load( $q->param('id') );

    $C->destroy();

    my $o ;
    $o->{success} = 'true';

    $G->header( -type => "text/x-json;charset=utf-8");
    print( $J->encode($o) );
    exit 0;
}
 
if( $action eq 'settings_category_flat' )	{
    my $J = new JSON;
    my $C = new HellFire::Settings::CategoryDAO( $dbh, $G );
    my @arr;

    $C->get_flat_settings(0,'',\@arr);

    $G->header( -type => "text/x-json;charset=utf-8");
    print( $J->encode( \@arr ) );
    exit 0;
}

    
my $J = new JSON;
$G->header( $J->encode( { succes => 0 } ) );
exit 0;





