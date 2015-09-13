package CGI::AppJSON;

use strict;
use JSON;
use CGI::Minimal;
use HellFire::Config;
use HellFire::DataBase;
use HellFire::Response;
use HellFire::Guard;

sub new {
    my $class = shift;
    my $self = {
        _q => new CGI::Minimal,
        _json => new JSON,
        _ini => new HellFire::Config,
        _response => new HellFire::Response,
        _errors => []
    };
    
    bless $self, $class;
    $self->init();
	return $self;
}

sub init    {
    my $self = shift;
    $self->{_db} = new HellFire::DataBase( $self->ini );
    $self->{_dbh} = $self->db->connect();
    
    $self->{_guard} = new HellFire::Guard( $self->dbh, $self->q, $self->ini );
    $self->guard->check_session();
    
	$self->response->header( 'Content-Type', 'text/x-json;charset=utf-8' );
	
    $self->{_action} = $self->q->param('action')||'';
}

sub q   {
    my $self = shift;
    return $self->{_q};
}

sub db   {
    my $self = shift;
    return $self->{_db};
}

sub response   {
    my $self = shift;
    return $self->{_response};
}

sub json   {
    my $self = shift;
    return $self->{_json};
}

sub ini   {
    my $self = shift;
    return $self->{_ini};
}

sub action   {
    my $self = shift;
    return $self->{_action};
}

sub dbh   {
    my $self = shift;
    return $self->{_dbh};
}

sub guard   {
    my $self = shift;
    return $self->{_guard};
}

sub run {
    my $self = shift;
    
	unless( scalar @{$self->{_errors}} )	{
		my $method = $self->action().'_action';
		
		if( $self->can( $method ) ) {
			eval { $self->$method };
			if( $@ )    {
				$self->error_500();
				$self->error( $@ );
			}
		}
		else    {
			$self->error( "No such action: ".$self->action() );
		}
	}
	
    if( scalar @{$self->{_errors}} )    {
        $self->{_msg} =  join "<br>", @{$self->{_errors}};
        warn join "\n", @{$self->{_errors}};
        return undef
    }
    
    return 1;
}

sub error   {
    my $self = shift;
    push @{$self->{_errors}}, @_;
}

sub error_500 {
    my $self = shift;
    $self->error( '500 Internal Server Error' );
    $self->response('Status', '500 Internal Server Error');
}

sub obj	{
	my $self = shift;
	$self->{_obj} = shift;
}

sub finish	{
	my $self = shift;
	
	print $self->response->header();
	
	if( scalar @{$self->{_errors}} )	{
		$self->obj( {
			failure => 1,
			success => 0,
			msg => $self->{_msg}
		} );
	}
	
	print $self->json->encode( $self->{_obj} );
}

1;