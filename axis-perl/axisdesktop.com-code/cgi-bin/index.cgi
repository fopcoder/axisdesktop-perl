#!/usr/bin/perl  

use Time::HiRes qw{time};
my $start = time();

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI::Minimal;
use HellFire::Guard;
use HellFire::Config;
use HellFire::DataBase;
use HellFire::Request;
	
use HellFire::Global;
#new HellFire::Global;

my $INI = new HellFire::Config();
my $q = new CGI::Minimal;
my $B = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
my $G = new HellFire::Guard( $dbh, $q, $INI ); 
my $R = new HellFire::Request( $dbh, $G ,$q );
    
#   warn $ENV{REQUEST_URI}; 
if( $q->param('set_var') )  {
	my @arr;
	foreach( $q->param() )   {
		next if( $_ =~ /set_var/i );
		push @arr, { name => $_, value => $q->param($_)||'' };
	}
	;
	$R->response->header('Set-Cookie', set_vars( $G, \@arr ) );
	$R->response->header('Location', $ENV{HTTP_REFERER}||'/' );
	$R->response->header('Status', 302 );
	print $R->response->header();
	exit;
}

get_vars( $G );
    

print $R->request()->header();

if( $R->response->header() =~ /404/ ){
    my $R = new HellFire::Request( $dbh, $G ,$q );
    print $R->request('/404.html')->content();
}
else    { 
    my $c = $R->response->content();
    $c =~ s/^(\s+)?\n//gm;
    print $c;
}
    
#print $R->request()->header();
#my $c = $R->response->content();
#$c =~ s/^(\s+)?\n//gm;
#print $c;

#print '<-- '.(time() - $start). ' -->';f
#warn '<!-- '.(time() - $start). ' -->';

sub set_vars    {
    my $G = shift;
    my $val = shift;
    
    $G->create_session()->expire('+1d');
    foreach ( @$val )   {
        if( $_->{name} ) {
            $_->{name} = lc( $_->{name}  );
            $_->{name} = 'var_'.$_->{name} unless( $_->{name} =~ /^var/ );
            $G->session->param( $_->{name}, $_->{value}||'' );
            $G->session->expire( $_->{name}, $_->{expire}||'+1d' );
        }
    }
    
    return $G->session->get_cookie;
}

sub get_vars    {
    my $G = shift;
    
    if( $G->session )   {
        foreach( $G->session->param() ) {
            if( $_ =~ /^var/ )  {
                $ENV{ uc($_) } = $G->session->param( $_ );
            }
        }
    }
}

