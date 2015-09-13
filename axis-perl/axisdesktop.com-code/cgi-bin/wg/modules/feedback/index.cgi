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

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
my $q   = new CGI::Minimal;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;
my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );

my $id     = $q->param( 'id' )     || 0;
my $action = $q->param( 'action' ) || '';

#---------------------------------------------------------------

if( $action eq 'feedback_load' ) {
	if( $G->get_user_id() ) {
		my $U = new HellFire::User::ItemDAO( $dbh, $G );
		$U->load( $G->get_user_id() );

		my $res = {
			email => $U->get_email(),
			login => $U->get_name()
		};

		print( $J->encode( $res ) );
	}
	else {
		print( { success => 0 } );
	}

	exit 0;
}

if( $action eq 'feedback_send' ) {
	require MIMEMAIL_M;

	if( $G->get_user_id() ) {
		my $U = new HellFire::User::ItemDAO( $dbh, $G );
		$U->load( $G->get_user_id() );

		my $mail = MIMEMAIL_M->new();
		$mail->{charSet}    = 'utf-8';
		$mail->{senderName} = $U->get_alias( $G->get_lang_id() ) || $U->get_name();
		$mail->{senderMail} = $U->get_email();
		$mail->{subject}    = 'CMS ['.$ENV{HTTP_HOST}.'] '.$q->param( 'subject' );
		$mail->{body}       = $q->param( 'message' );
		$mail->create();
		if( !$mail->send( 'cms@axisdesktop.com' ) ) { warn $mail->error; print( { success => 0 } ); }
	}
}

