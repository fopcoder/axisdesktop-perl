package HellFire::Guard;

use strict;
use CGI::Session_M;

#use HTTP::Session;

sub new {
	my $class  = shift;
	my $dbh    = shift;
	my $q      = shift;
	my $ini    = shift;
	my $params = shift;

	my $self = {};
	$self->{_dbh} = $dbh;
	$self->{_q}   = $q;
	$self->{_ini} = $ini;
	$self->{_cgi} = 0;

	#$self->{_session} = CGI::Session_M->load( undef, undef, { Directory => $ini->session_tmp_dir } );
	$self->{_session} = CGI::Session_M->load( undef, $q, { Directory => $ini->session_tmp_dir } );
	bless $self, $class;
	return $self;
}

sub ini {
	my $self = shift;
	return $self->{_ini};
}

sub dbh {
	my $self = shift;
	return $self->{_dbh};
}

sub q {
	my $self = shift;
	return $self->{_q};
}

sub create_session {
	my $self   = shift;
	my $params = shift;
	$self->{_session} = $self->session->new( undef, $self->q, { Directory => $self->ini->session_tmp_dir } );
	return $self->{_session};
}

sub login {
	require HellFire::User::ItemDAO;

	my $self   = shift;
	my $login  = shift;
	my $passwd = shift;
	my $email  = shift;

	if( $self->q ) {
		$login  ||= $self->q->param( 'login' );
		$passwd ||= $self->q->param( 'password' );
		$email  ||= $self->q->param( 'email' );
	}

	if( ( $login || $email ) && $passwd ) {
		my $U = new HellFire::User::ItemDAO( $self->dbh, $self );
		my $l = $U->login( $login, $email, $passwd );
		if( $l ) {
			$self->{_session} = $self->session->new( undef, $self->q, { Directory => $self->ini->session_tmp_dir } );
			if( $U->check_administrator( $l ) ) {
				$self->session->param( 'administrator', 1 );
			}

			$U->load( $l );

			$self->session->param( 'signed_in', 1 );
			if( $self->is_cgi() )	{
				$self->session->param( 'admin_lang_id',  $self->get_lang_id()  );
				$self->session->param( 'admin_lang_name', $self->get_lang_name() );
			}
			else	{
				$self->session->param( 'lang_id',   $self->get_lang_id() );
				$self->session->param( 'lang_name', $self->get_lang_name() );
			}
			$self->session->param( 'user_id',   $l );
			$self->session->param( 'user_name', $U->get_name() );
			$self->session->expire( '1h' );

			return 1;

		}
	}
	else {

	}

	return undef;
}

sub logout {
	my $self = shift;
	$self->session->delete();
}

sub session {
	my $self = shift;

	if( @_ ) {
		$self->{_session} = @_;
	}
	return $self->{_session};
}

sub header {
	my $self = shift;
	print $self->session->header( -type => 'text/html; charset=utf-8', @_ );
}

sub check_session {
	my $self = shift;

	if( index( $ENV{'REQUEST_URI'}, 'cgi-bin' ) >= 0 ) {
		$self->{_cgi} = 1;
	}

	if( $self->{_q}->param( 'action' ) eq 'logout' ) {
		$self->logout();
		my $url = $ENV{'REQUEST_URI'};
		#$url =~ s/\?.+$//;
		$url =~ s/action=logout//;
		$url =~ s/\?.+$//;
		my $l =  $ENV{'HTTP_REFERER'};
		$l =~ s/action=logout//;
		
		$self->header( 'location' => $l || $url );
		exit 0;
	}

	#if( ( $self->{_q}->param('login') || $self->{_q}->param('email') ) && $self->{_q}->param('password') )  {
	if( $self->{_q}->param( 'action' ) eq 'login' ) {
		if( $self->login() ) {
			#$self->header( -type => 'text/x-json; charset=utf-8' );

			#$self->header( 'location' => $ENV{'HTTP_REFERER'} );
			#print '{success:true}';
		}
		else {
			#$self->header( -type => 'text/x-json; charset=utf-8' );
			#print "{ success: false, errors: { reason: 'Login failed. Try again.' }}";
		}
		
		my $l =  $ENV{'HTTP_REFERER'};
		$l =~ s/action=logout//;
		$l =~ s/\?.+$//;
		
		$self->header( 'location' => $l );
		exit 0;
	}
	if( $self->session->param( 'signed_in' ) ) {
		if( $self->check_path() ) {
			print('Set-Cookie: '. $self->session->cookie()."\n" );
			return $self->session->cookie();
		}
		
		
	}
	
	return;
	#require HTML::Template::Pro;
	#my $t = HTML::Template::Pro->new(
	#	'die_on_bad_params' => 0,
	#	filename            => $self->ini->home_dir() . $self->ini->modules_dir() . "/base/template/login.html"
	#);
	#$t->param( 'modules_dir' => $self->ini->modules_dir() );
	#$t->param( 'script_dir'  => $self->ini->script_dir() );
	#$t->param( 'version'     => $self->ini->version() );
	#$t->param( 'title'       => $self->ini->obj->{project}->{title} );
	#$t->param( 'script'      => $ENV{SCRIPT_NAME} );
	#
	#$self->header();
	#print $t->output();
	#exit 0;

}

sub get_groups {
	require HellFire::User::ItemDAO;
	my $self = shift;

	my $U = new HellFire::User::ItemDAO( $self->dbh, $self );
	$U->load( $self->session->param( 'user_id' ) );

	return $U->get_groups();
}

sub is_administrator {
	my $self = shift;
	return $self->session->param( 'administrator' );
}

sub check_path {
	require HellFire::Site::ItemDAO;
	require HellFire::Site::CategoryDAO;
	my $self = shift;

	my $C = new HellFire::Site::CategoryDAO( $self->{_dbh}, $self );
	$C = $C->get_domain();

	my $pid = $C->get_id();

	my $ru = $ENV{REQUEST_URI};
	$ru =~ s/\?.*$//;
	my @params = split( /\//, $ru );

	my $PL;
	my $IL;
	my @url;

	#   my @path;
	for( my $i = 0 ; $i < scalar @params ; $i++ ) {
		next unless $params[$i];
		my $P = new HellFire::Site::CategoryDAO( $self->dbh, $self );
		$P->set_parent_id( $pid );

		my $cid = $P->find( $params[$i] );

		if( $cid ) {
			$P->load( $cid );
			$pid = $cid;
			$PL  = $P;
			@url = @params;
			@url = splice( @url, $i + 1 );

			#	    push @path, $params[$i];
		}
		else {
			$IL = new HellFire::Site::ItemDAO( $self->dbh, $self );
			$IL->set_parent_id( $pid );
			$IL->load( $IL->find( $params[$i] ) );
			@url = @params;
			@url = splice( @url, $i + 1 );

			#	    push @path, $params[$i];
			last;
		}
	}

	#warn('/'.join('/',@path));
	#$self->set_path( '/'.join('/',@path) );
	my $ret = undef;

	#return 1;
	if( $self->is_administrator() ) {
		$ret = 1;
	}
	elsif( $IL && $IL->get_name() ) {
		$ret = $IL->get_action( 'site_item_view' );
	}
	elsif( $PL && $PL->get_name() ) {
		$ret = $PL->get_action( 'site_category_view' );
	}

	return $ret;
}

sub set_lang_id {
	my $self = shift;
	my $id = shift || 1;

	if( $self->is_cgi )	{
		$self->session->param( 'admin_lang_id', $id );
		$self->{_admin_lang_id} = $id;
		return $self->{_admin_lang_id};
	}
	else	{
		$self->session->param( 'lang_id', $id );
		$self->{_lang_id} = $id;
		return $self->{_lang_id};
	}
}

sub get_lang_id {
	my $self = shift;

	if( $self->is_cgi() )	{
		return $self->{_admin_lang_id} || $self->session->param( 'admin_lang_id' ) || 1;
	}
	else	{
		return $self->{_lang_id} || $self->session->param( 'lang_id' ) || 1;
	}
}

sub set_lang_name {
	my $self = shift;
	my $id = shift || '';

	if( $self->is_cgi() )	{
		$self->session->param( 'admin_lang_name', $id );
		$self->{_admin_lang_name} = $id;
		return $self->{_admin_lang_name};
	}
	else	{
		$self->session->param( 'lang_name', $id );
		$self->{_lang_name} = $id;
		return $self->{_lang_name};
	}
}

sub get_lang_name {
	my $self = shift;

	if( $self->is_cgi() )	{
		return $self->{_admin_lang_name} || $self->session->param( 'admin_lang_name' ) || 'ru';
	}
	else	{
		return $self->{_lang_name} || $self->session->param( 'lang_name' ) || 'ru';
	}
}

sub get_user_id {
	my $self = shift;

	my $id = $self->session->param( 'user_id' );
	return $id || 0;
}

sub get_user_name {
	my $self = shift;

	my $id = $self->session->param( 'user_name' );
	return $id || 0;
}

sub set_path {
	my $self = shift;
	$self->{'_path'} = shift;
	return $self->{'_path'};
}

sub get_path {
	my $self = shift;
	return $self->{'_path'};
}

sub generate_key {
	my $self = shift;
	my $length = shift || 10;

	rand( time() ^ ( $$ + ( $$ << 15 ) ) );
	my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );

	return join( "", @chars[ map { rand @chars } ( 1 .. $length ) ] );
}

sub set_secure_string {
	my $self = shift;

	my $key  = $self->generate_key( 100 );
	my $code = $self->generate_key( 6 );

	my @sarr = ( 78, 2, 26, 41, 98, 51 );

	for( my $i = 0 ; $i < length( $code ) ; $i++ ) {
		substr( $key, $sarr[$i], 1, substr( $code, $i, 1 ) );
	}

	return $key;
}

sub get_secure_string {
	my $self = shift;
	my $key  = shift;
	my $code;

	my @sarr = ( 78, 2, 26, 41, 98, 51 );

	for( my $i = 0 ; $i < scalar @sarr ; $i++ ) {
		$code .= substr( $key, $sarr[$i], 1 );
	}

	return $code;
}

sub is_cgi {
	my $self = shift;
	return $self->{_cgi};
}

sub is_signed_in {
	my $self = shift;
	return 0 unless $self->session();
	return $self->session->param( 'signed_in' )||0;
}


return 1;
