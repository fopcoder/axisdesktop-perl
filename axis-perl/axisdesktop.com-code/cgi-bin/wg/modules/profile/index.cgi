#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use CGI::Minimal;
use JSON;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::Config;
use HellFire::Response;
use HellFire::User::ItemDAO;
use HellFire::DataType;

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
my $q   = new CGI::Minimal;
#my $q   = new CGI;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;
my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );


my $parent_id = $q->param( 'parent_id' ) || $q->param( 'pid' ) || 0;
my $id        = $q->param( 'id' )        || 0;
my $action    = $q->param( 'action' )    || '';

#---------------------------------------------------------------

if( $action eq 'profile_load' ) {
    if( $G->get_user_id() )   {
        my $U = new HellFire::User::ItemDAO( $dbh, $G );
        $U->load( $G->get_user_id() );
        
        my $T = new HellFire::DataType( $dbh );
        my $l = $T->get_languages();
        
        my @l10n;
        foreach( @$l )  {
            push @l10n, {
            	xtype => 'textfield',
            	fieldLabel => $_->{'alias'},
            	name => 'alias_'.$_->{id},
            	value => $U->get_alias( $_->{id} )
            };
        }
        
        my $res = {
            email => $U->get_email(),
            login => $U->get_name(),
            l10n => \@l10n
        };
        
        print( $J->encode( $res ) );
    }
    else    {
        print( $J->encode( { success => 0 } ) );
    }
    
	exit 0;
}

if( $action eq 'profile_validate_email' ) {
    my $U = new HellFire::User::ItemDAO( $dbh, $G );
	unless( length $q->param('email') )	{
		print( $J->encode( { valid => 0 } ) );
        exit 0;
	}
    if( $U->load( $U->find_by_email( $q->param('email') ) ) )   {
        unless( $U->get_id() == $G->get_user_id )   {
            print( $J->encode( { valid => 0 } ) );
            exit 0;
        }
    }
    print( $J->encode( { valid => 1 } ) );
    exit 0;
}

if( $action eq 'profile_validate_login' ) {
    my $U = new HellFire::User::ItemDAO( $dbh, $G );
	unless( length $q->param('login') )	{
		print( $J->encode( { valid => 0 } ) );
        exit 0;
	}
    if( $U->load( $U->find( $q->param('login') ) ) )   {
        unless( $U->get_id() == $G->get_user_id )   {
            print( $J->encode( { valid => 0 } ) );
            exit 0;
        }
    }
    print( $J->encode( { valid => 1 } ) );
    exit 0;
}

if( $action eq 'profile_update' ) {
	my $U = new HellFire::User::ItemDAO( $dbh, $G );
	$U->load( $G->get_user_id() );
	
    foreach my $i ( $q->param() )      {
	    if( $i =~ /alias_(\d+)/ )	{
			$U->set_alias( $1, $q->param( $i ) );
	    }
        else        {
			my $fn = 'set_'.$i;
			$U->$fn( $q->param($i) ) if( $U->can($fn) );
        }
    }   
    
    $U->save();
	
	print( $J->encode( { success => 1 } ) );
    exit 0;
}