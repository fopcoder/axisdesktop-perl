package HellFire::Request;

use strict;
use HellFire::Site::CategoryDAO;
use HellFire::Site::ItemDAO;
use HellFire::Configuration::CategoryDAO;
use HellFire::DataType;
use HellFire::Response;

sub new {
    my $class = shift;

    my $self = {};
    $self->{_dbh}    = shift;
    $self->{_guard}  = shift;
    $self->{_q}      = shift;
    $self->{_global} = new HellFire::Global;

    bless $self, $class;

    $self->{_url}      = new HellFire::Request::URL( $self );
    $self->{_response} = new HellFire::Response();
    $self->{_values}   = {};

    return $self;
}

sub dbh {
    my $self = shift;
    return $self->{'_dbh'};
}

sub guard {
    my $self = shift;
    return $self->{'_guard'};
}

sub global {
    my $self = shift;
    return $self->{'_global'};
}

sub domain {
    my $self = shift;
    $self->global->{'_domain'} = shift if( @_ );
    return $self->global->{'_domain'};
}

sub url {
    my $self = shift;
    return $self->{'_url'};
}

sub response {
    my $self = shift;
    return $self->{'_response'};
}

sub q {
    my $self = shift;
    return $self->{'_q'};
}

sub get_value {
    my $self = shift;
    my $k    = shift;
    return $self->{_values}->{$k};
}

sub page    {
    my $self = shift;
    return $self->get_value('p')||0;
}

sub level {
    my $self = shift;
    $self->{'_level'} = shift if( @_ );
    return $self->{'_level'};
}

sub get_action {
    my $self = shift;
    my $k    = shift;

    my $a;
    if( $self->get_value( 'action' ) || $self->q->param( 'action' ) )   {
        $a = $self->get_value( 'action' ) || $self->q->param( 'action' );
    }
    elsif( $self->url->path() =~ /(\w+)\.ax$/ || $self->url->location() =~ /(\w+)\.ax$/ )    {
        $a = $1
    }
    
    if( $k ) {
        if( $k eq $a ) {
            return 1;
        }
        return undef;
    }
    else {
        return $a;
    }
}

sub request {
    my $self = shift;
    my $url = shift;
    my $params = shift;

    $self->level(1) if( $url );
    $self->level( $params->{level} + 1 ) if( $params->{level} );
    $url ||= $ENV{REQUEST_URI};
    
    unless( $self->domain ) {
        $self->domain( new HellFire::Site::CategoryDAO( $self->dbh, $self->guard )->get_domain() );
    }

    $self->url->parse( $url );
    $self->guard->set_path( $self->url->path() );

    $ENV{SIGNED_IN} = $self->guard->get_user_id();

    if( $self->url->site_object ) {
        my $H = new HellFire::Configuration::CategoryDAO( $self->dbh, $self->guard );
        $H->load( $self->url->site_object->get_handler_id() );
        my $hn = $H->get_module();
        if( length $hn > 0 ) {
            if( eval( "require $hn;" ) ) {
                my $c;
                if( eval '$c = new ' . $hn . '( $self )' ) {
                    $c->run();
                }
                else {
                    warn $@;
                }
            }
            else {
                warn $@;
            }
        }
        else {
            warn '== HellFire::Request -> request : no handler defined';
            $self->response->header( 'Status', '404 Not Found' );
        }
    }
    else {
        warn '== HellFire::Request -> request : no site object found';
        $self->response->header( 'Status', '404 Not Found' );
    }

    undef $self->{_url};
    return $self->response;
}

package HellFire::Request::URL;

sub new {
    my $class = shift;
    my $self  = {};
    $self->{_request} = shift;

    bless $self, $class;
    return $self;
}

sub request {
    my $self = shift;
    return $self->{_request};
}

sub parse {
    my $self = shift;
    my $url  = shift;

    ( my $a, my $b ) = split( /\?/, $url, 2 );
    $self->{_query_string} = $b;

    ( my $c, my $d ) = split( /\/:/, $a, 2 );
    if( $d ) {
        my @pairs = split( /:/, $d );
        foreach ( @pairs ) {
            my( $k, my $v ) = split( /=/, $_ );
            $self->request->{_values}->{$k} = $v if( $k && defined $v );
        }
    }

    my @params;
    foreach ( split( /\//, $c ) ) {
        push @params, $_ if( $_ );
    }

    #$self->{_url} = '/' . join( '/', @params );
    #$self->{_uri} = $self->{_url} . '?' . $b;

    #if( $params[-2] eq '_p' ) {
    #    $self->{_page} = $params[-1];
    #    pop @params;
    #    pop @params;
    #}

    #if( $params[-2] eq 'filter' ) {
    #    $self->{_filter} = $params[-1];
    #    pop @params;
    #    pop @params;
    #}

    $self->{_location} = '/' . join( '/', @params );
    #my $shiftname;
    if( defined $params[-1] && $params[-1] =~ /(\w+)([\.]+)(\w+)$/ )    {
        $self->{_item_name} = substr( $params[-1], 0, rindex( $params[-1], '.' ) );
        $self->{_extension} = substr( $params[-1], rindex( $params[-1], '.' ) + 1 );
        $self->request->response->set_content_type( $self->{_extension} );
     #   $shiftname = pop @params;
    }

    my $D       = new HellFire::DataType( $self->request->dbh );
    my $lang_id = $D->find_lang( $params[0] );

    if( $lang_id ) {
        $self->request->guard->set_lang_id( $lang_id );
        my $n = shift @params;
        $self->request->guard->set_lang_name( $n );
    }

    unless( scalar @params ) {
        push @params, 'index.html';
    }

    my @url;
    my @path;

    $self->{_site_object} = $self->request->domain();
    my $pid = $self->request->domain->get_id();

    for( my $i = 0 ; $i < scalar @params ; $i++ ) {
        my $P = new HellFire::Site::CategoryDAO( $self->request->dbh, $self->request->guard );
        $P->set_parent_id( $pid );

        if( $P->load( $P->find( $params[$i] ) ) ) {
            $pid = $P->get_id();
            my $hn = $P->get_handler_id();
            if( $hn ) {
                $self->{_site_object} = $P;
                @url = @params;
                @url = splice( @url, $i + 1 );
                $self->set_crumbs( $P );
            }
            push @path, $params[$i];
        }
        else {
            my $IL = new HellFire::Site::ItemDAO( $self->request->dbh, $self->request->guard );
            $IL->set_parent_id( $pid );
            if( $IL->load( $IL->find( $params[$i] ) ) ) {
                $self->{_site_object} = $IL if( $IL->get_id() );

                @url = @params;
                @url = splice( @url, $i + 1 );
                push @path, $params[$i];
            }
            else    {
                @url = @params;
                @url = splice( @url, $i  );
            }
            last;
        }
    }

    $self->{_path} = '/' . join( '/', @path );
    $self->{_param} = \@url;

    return \@url;
}

#sub get_uri {
#    my $self = shift;
#    return $self->{_uri};
#}

#sub get_url {
#    my $self = shift;
#    return $self->{_url};
#}

# path without params and values, with lang
sub location {
    my $self = shift;
    return $self->{_location};
}

# path to point with handler in site categories
sub path {
    my $self = shift;
    return $self->{_path};
}

# path to point without actions
sub path_href {
    my $self = shift;
    my $params = shift;
    
    my $href = $params->{href} || $self->path();
    $href =~ s/[\w_]+\.ax$//;

	$href .= '/' unless( $href =~ /\/$/);
	$href .= join('/',@{$self->param()});
    $href =~ s/[\w_]+\.ax$//;
    $href =~ s/\/$//;
    return $href;
}

# arrayref to url params lower then path
sub param {
    my $self = shift;
    return $self->{_param};
}

# get url file extension
sub extension   {
    my $self = shift;
    return $self->{_extension};
}

# get url item name
sub item_name   {
    my $self = shift;
    return $self->{_item_name};
}

#sub get_param {
#    my $self = shift;
#    return $self->{_param};
#}

# object in path node with handler
sub site_object {
    my $self = shift;
    return $self->{_site_object};
}

#sub get_page {
#    my $self = shift;
#    return $self->{_page};
#}

#sub get_filter {
#    my $self = shift;
#    return $self->{_filter};
#}

#  query string after ? in url
sub query_string {
    my $self = shift;
    return $self->{_query_string};
}

sub set_crumbs {
    my $self = shift;
    my $obj  = shift;

    unless( $self->request->level() ) {
        $self->request->response->crumbs(
            {
                name  => $obj->get_name(),
                alias => $obj->get_alias( $self->request->guard->get_lang_id ) || $obj->get_name(),
                href  => $obj->get_path()
            }
        );
    }
}


return 1;
