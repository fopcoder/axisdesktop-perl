package Gears::ToolsPage;

use strict;
use base qw(Gears);
use CGI::SSI_M;
use CGI::Util_M qw{expires};
use HTML::Template::Pro;

my $WHOIS = '/usr/bin/whois';

sub new {
    my $class = shift;
    my $self;

    $self->{_request} = shift;
    $self->{_dbh}     = $self->{_request}->dbh;
    $self->{_guard}   = $self->{_request}->guard;

    bless $self, $class;

    return $self;
}

sub sitemap_action {
    require CGI::Cookie_M;
    
    my $self = shift;
    
    my $cookie = CGI::Cookie_M->fetch();
    my $restrict;
    if( defined $cookie->{'sitemap_restrict'} ) {
        $restrict = $cookie->{'sitemap_restrict'}->value;
    }
    else    {
        $restrict = 'order|basket|cart|admin';        
    }
    $restrict =~ s/\|/\n/g;
    my $start_url;
    if( defined $cookie->{'sitemap_start_url'} )    {
        $start_url = $cookie->{'sitemap_start_url'}->value;
    }
    else    {
        $start_url = 'http://';        
    }
    
    $self->set_crumbs( { item => $self->request->url->site_object() } );

    $self->output( {
        action => 'sitemap',
        item => ${ $self->request->url->param() }[0],
        restrict => $restrict,
        start_url => $start_url
    } );
}

sub sitemap_checkout_action {
    my $self = shift;
    my( $count, $date, $queue, $name, $clock, $sitemap_src, $sitemap_xml, $sitemap_txt, $sitemap_xml_gz, $fn, $fq, $run );
    my @str = ();
    
    my $cookie = CGI::Cookie_M->fetch();
    if( defined $cookie->{'sitemap_filename'} )    {
        $name = $cookie->{'sitemap_filename'}->value;
    }
    
    $fq = $self->request->q->param('name')||$name;
    $run = 0;
    if( $fq )   {
        $run = 1;

        $fn = $ENV{DOCUMENT_ROOT}.'/getsitemaps/'.$fq.'.info';
        if( -f $fn && open FILE, $fn )    {
            @str = <FILE>;
            close FILE;
        }
        
        $count = shift @str;
        $count =~ s/files:\s+//;
        
        $clock = shift @str;
        $clock =~ s/time:\s+//;
              
        $queue = join('<br />',@str);
        
        unless( -f $ENV{DOCUMENT_ROOT}.'/getsitemaps/'.$fq.'.lock' )    {
            $run = 0;
            $fn = $ENV{DOCUMENT_ROOT}.'/getsitemaps/'.$fq.'.xml';
            if( -f $fn && open FILE, $fn )    {
                $sitemap_src = join( "\n", <FILE> );
                close FILE;
                $sitemap_xml = 'http://'.$ENV{HTTP_HOST}.'/getsitemaps/'.$fq.'.xml',
            }
            
            if( -f $ENV{DOCUMENT_ROOT}.'/getsitemaps/'.$fq.'.txt' )    {
                $sitemap_txt = 'http://'.$ENV{HTTP_HOST}.'/getsitemaps/'.$fq.'.txt',
            }
            
            if( -f $ENV{DOCUMENT_ROOT}.'/getsitemaps/'.$fq.'.xml.gz' )    {
                $sitemap_xml_gz = 'http://'.$ENV{HTTP_HOST}.'/getsitemaps/'.$fq.'.xml.gz',
            }
        }
    }
    
    $self->output( {
        action => 'sitemap_checkout',
        count => $count||0,
        queue => $queue,
        time => $clock||0,
        run => $run,
        sitemap_src => $sitemap_src,
        sitemap_xml => $sitemap_xml,
        sitemap_txt => $sitemap_txt,
        sitemap_xml_gz => $sitemap_xml_gz,
        item => ${ $self->request->url->param() }[0]
    } );
}

sub sitemap_create_action {
    my $self = shift;
    my $url  = $self->request->q->param( 'url' );

    $self->set_crumbs( { item => $self->request->url->site_object() } );

    if( $url ) {
        $url = 'http://'.$url unless( $url =~ /^http:\/\// );
        $url .= '/' unless( $url =~ /\/$/ );
     
        $self->request->response->header('Set-Cookie', "sitemap_start_url=$url; path=/; expires=".CGI::Util_M::expires('+2y','cookie'));
     
        my $storedir = $ENV{DOCUMENT_ROOT} . '/getsitemaps';
        `mkdir -p $storedir`;
        
        my $mapfile_name = $url;
        $mapfile_name =~ s/^http:\/\///;
        $mapfile_name =~ s/[\/]+/\//g;
        $mapfile_name =~ s/\//\./g;
        $mapfile_name =~ s/\\/\./g;
        $mapfile_name =~ s/\.$//;
        $mapfile_name =~ s/[\.]+/\./g;

        $self->request->response->header('Set-Cookie',"sitemap_filename = $mapfile_name; path = /; expires=".CGI::Util_M::expires('+2h','cookie') );
        
        unlink( $storedir.'/'.$mapfile_name.'.txt' );
        unlink( $storedir.'/'.$mapfile_name.'.xml' );
        unlink( $storedir.'/'.$mapfile_name.'.xml.gz' );
        unlink( $storedir.'/'.$mapfile_name.'.info' );
        
        my $restrict = $self->request->q->param( 'restrict' )||'';
        $restrict =~ s/\n/\|/gm;
        $restrict =~ s/\s+//g;
	$restrict =~ s/[\|]+/\|/;
	$restrict =~ s/\|$//;
        $self->request->response->header('Set-Cookie',"sitemap_restrict = $restrict; path = /; expires=".CGI::Util_M::expires('+2y','cookie') );
        
        unless( -f $storedir.'/'.$mapfile_name.'.lock' )   {
            my $pid = fork();
        
            if( $pid )    {
                if( open FILE, '>'.$storedir.'/'.$mapfile_name.'.lock') {
                    print FILE $$;
                    close FILE;
                }
                
                $self->output( {
                    action => 'sitemap_create',
                    item => ${ $self->request->url->param() }[0],
                    sitemap_filename => $mapfile_name
                } );
            }
            elsif( $pid == 0 )  {
                require Date::Format;
                require Date::Parse;
                require AxCrawler;
                
                close STDOUT;
                close STDIN;
                close STDERR;
                
                if( open FILE, '>'.$storedir.'/'.$mapfile_name.'.lock') {
                    print FILE $$;
                    close FILE;
                }
    
                my $config = {
                    'NAME'             => 'AxisDesktop Sitemaps Generator ( http://axisdesktop.com )',
                    'VERSION'          => '1.0',
                    'EMAIL'            => 'cms@axisdesktop.com',
                    'START_URL'        => $url,
                    'START_TIME'       => time(),
                    'SITEMAP_FILE'     => $storedir.'/'.$mapfile_name,
                    'DELAY'            => 0.017,
                    'RESTRICT' => $restrict ? qr{$restrict} : undef,
                    'WITH_DATE'        => $self->request->q->param( 'lastmod' )||0,
                    'WITH_FREQUENCY'   => $self->request->q->param( 'frequency' )||0,
                    'WITH_PRIORITY'    => $self->request->q->param( 'priority' )||0,
                    'CHECK_MIME_TYPES' => 0,
                    'ANY_CONTENT'      => 1,
                    'LIMIT' => 50000
                };
    
                my $robot = new AxCrawler( $config );
                #while( my($key,$value) = each %$config ) {
                #     $robot->{ $key } = $value;
                #}
                $robot->{'__urls__'} = [];
                $robot->{'__count__'} = 0;
                
                $robot->{'AGENT'}->{ROBOT} = $robot;
                $robot->{'AGENT'}->add_handler( response_done => \&response_done );
                $robot->addHook( 'follow-url-test',    \&follow_url_test );
                $robot->addHook( 'invoke-on-contents', \&invoke_on_contents );
                $robot->addHook( 'continue-test', \&continue_test );
                $robot->addHook( 'generate-report',    \&generate_report );
                $robot->run( $robot->{'START_URL'} );
                
                exit;
            }
            else    {
                warn 'FORK ERROR';
            }
        }
        
        $self->output( {
            action => 'sitemap_create',
            item => ${ $self->request->url->param() }[0],
            sitemap_filename => $mapfile_name
        } );
    }
    else    {
        $self->output( {
            action => 'sitemap_create',
            item => ${ $self->request->url->param() }[0]
        } );
    }
}

sub follow_url_test {
    my( $robot, $hook, $url ) = @_;

    return 0 if( $robot->{RESTRICT} && $url =~ /$robot->{RESTRICT}/ );
    return 0 unless $url->scheme eq 'http';
    return $url =~ /^$robot->{'START_URL'}/;
}

sub invoke_on_contents {
    my( $robot, $hook, $url, $response, $structure ) = @_;

    my $h;
    $h->{loc} = $url;
    $h->{loc} =~ s/&/&amp;/g;

    if( $robot->{'WITH_FREQUENCY'} ) {
        $h->{changefreq} = $robot->{'WITH_FREQUENCY'};
    }

    if( $robot->{'WITH_PRIORITY'} ) {
        if( $robot->{'__count__'} ) {
            $h->{priority} = '0.8';
        }
        else {
            $h->{priority} = '1.0';
        }
    }

    if( $robot->{'WITH_DATE'} ) {
        $h->{lastmod} = $response->header( 'last-modified' ) || $response->header( 'date' );
        $h->{lastmod} = Date::Format::time2str( "%Y-%m-%dT%T+00:00", Date::Parse::str2time( $h->{lastmod} ) );
    }

    push @{ $robot->{'__urls__'} }, $h;
    $robot->{'__count__'}++;
    return 1;
}

sub continue_test   {
    my($robot) = @_;
    
    if( $robot->{__count__} >= $robot->{LIMIT} )   {
        return 0;
    }
    
    if( open FILE, '>'.$robot->{'SITEMAP_FILE'}.'.info' )   {
        print FILE 'files: '.( $robot->{__count__} )."\n";
        print FILE 'time: '.( time() - $robot->{'START_TIME'} )."\n";
        foreach( $robot->listUrls() )   {
            print FILE "$_\n";            
        }
        close FILE;
    }
    
    return 1;
}

sub generate_report {
    my( $robot ) = @_;

    if( open FILE, '>' . $robot->{'SITEMAP_FILE'}.'.txt' ) {
        foreach ( @{ $robot->{__urls__} } ) {
            print FILE $_->{loc} . "\n";
        }
        close FILE;
    }
    else {
        warn "Can't open file " . $robot->{'SITEMAP_FILE'} . ".txt => " . $!;
    }
    
    if( open FILE, '>' . $robot->{'SITEMAP_FILE'}.'.xml' ) {
        print FILE '<?xml version="1.0" encoding="UTF-8"?>
<urlset
  xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
        http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
<!-- Created with AxisDesktop Sitemaps Generator / http://axisdesktop.com -->' . "\n";
        foreach ( @{ $robot->{__urls__} } ) {
            print FILE "<url>\n";
            if( $_->{loc} ) {
                print FILE '<loc>' . $_->{loc} . "</loc>\n";
            }
            if( $_->{lastmod} ) {
                print FILE '<lastmod>' . $_->{lastmod} . "</lastmod>\n";
            }
            if( $_->{changefreq} ) {
                print FILE '<changefreq>' . $_->{changefreq} . "</changefreq>\n";
            }
            if( $_->{priority} ) {
                print FILE '<priority>' . $_->{priority} . "</priority>\n";
            }
            print FILE "</url>\n";
        }
        print FILE '</urlset>';
        close FILE;
    }
    else {
        warn "Can't open file " . $robot->{'SITEMAP_FILE'} . ".xml => " . $!;
    }
    
    if( -f $robot->{'SITEMAP_FILE'}.'.xml' && -f '/usr/bin/gzip' )    {
        my $xml = $robot->{'SITEMAP_FILE'}.'.xml';
        my $gz = $xml.'.gz';
        `/usr/bin/gzip -9 -c $xml > $gz`;
    }
    
    unlink( $robot->{'SITEMAP_FILE'}.'.lock' );
}

sub response_done {
    my( $response, $ua, $h ) = @_;

    my $robot = $ua->{ROBOT};
    if( $response->code() == 302 && !( $response->header( 'location' ) =~ /^$robot->{START_URL}/ ) ) {
        $response->code( 404 );
    }
}

sub dns_action {
    my $self = shift;
    $self->set_crumbs( { item => $self->request->url->site_object() } );
    $self->output( { action => 'dns', item => ${ $self->request->url->param() }[0] } );
}

sub dns_request_action {
    my $self = shift;

    if( $ENV{"REQUEST_METHOD"} eq 'POST' ) {
        require File::Basename;
        require Net::DNS;

        my $res = Net::DNS::Resolver->new;
        my $dns = $self->request->q->param( 'dns_host' );
        my $type  ||= "ANY";
        my $class ||= "IN";

        my $answer = $res->send( $dns, $type, $class );

        my $out;
        if( $answer ) {
            $out = $answer->string;
        }

        $out =~ s/\n/<br \/>/g;

        $self->output( { action => 'dns_request', response => $out } );
    }
    else {
        $self->output( { action => 'dns_request', response => undef } );
    }
}

sub whois_action {
    my $self = shift;

    $self->set_crumbs( { item => $self->request->url->site_object() } );

    $self->output( { 
	action => 'whois', 
	item => $self->request->url->site_object()
    } );
}

sub whois_request_action {
    my $self = shift;

    if( $ENV{"REQUEST_METHOD"} eq 'POST' ) {
        require Net::Whois::Raw;
        $Net::Whois::Raw::OMIT_MSG   = 1;
        $Net::Whois::Raw::CHECK_FAIL = 1;

        my $host = $self->request->q->param( 'whois_host' );
        my $res;
        eval { $res = Net::Whois::Raw::whois( $host ) };
        $res =~ s/\n/<br \/>/g;

        $self->output( { action => 'whois_request', response => $res } );
    }
    else {
        $self->output( { action => 'whois_request', response => undef } );
    }
}

sub index_action {
    my $self = shift;
    my $params;

    $self->output( { action => 'index', item => 'index.ax' } );
}

sub item_action {
    my $self = shift;
    my $params;

    eval '$params = ' . $self->request->url->site_object->get_config();
    my $AI = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );

    my $url = $self->param_to_category( $params->{parent_id} );

    if( $url ) {

        if( defined $$url[-1] ) {
            $params->{category_id} = $$url[-1]->get_id();
        }
        $AI->set_parent_id( $params->{category_id} || $params->{parent_id} );
        if( $AI->load( $AI->find( $self->request->url->item_name() ), { no_clean => 1, lang_id => $self->guard->get_lang_id() } ) ) {
            $params = $AI->to_template();

            #warn $AI->get_last_modified();
            #warn $AI->get_updated();
            #require HTTP::Date;
            #my $lm = HTTP::Date::time2str(HTTP::Date::str2time(HTTP::Date::parse_date( $AI->get_updated )));
            #warn $lm;
            #$self->request->response->header('Last-Modified', $AI->get_last_modified() );
            #$self->request->response->header('Last-Modified', $lm );
        }

        $self->set_crumbs( { url => $url, item => $AI } );

        $self->output(
            {
                action => 'item',
                obj    => $AI,
                %$params
            }
        );
    }
    else {
        $self->output();
    }
}

sub output {
    my $self   = shift;
    my $params = shift;

    if( $params->{action} ) {
        my $out;
        my $ff;
        my $I;

        if( $params->{action} eq 'index' ) {
            $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
            $I->set_parent_id( $self->request->url->site_object->get_id() );
            $I->load( $I->find( $params->{action} . '.ax' ) );
        }

        #warn $self->request->url->site_object->get_id();

        #elsif( $params->{action} eq 'item' )	{
        else {
            $I = $self->request->url->site_object();
        }

        if( defined $I && $I->get_id() ) {
            my $SSI = new CGI::SSI_M( request => $self->request );

            my $prefix = $self->request->domain->get_id();
            $prefix .= '/t';

            my $prefixc = $self->request->domain->get_id();
            $prefixc .= '/c/' . $I->get_parent_id();

            if( $I->get_content( $self->guard->get_lang_id() ) ) {
                my $file = $self->guard->ini->template_dir . "/$prefixc/" . $I->get_content( $self->guard->get_lang_id() );
                if( -s $file && open( FILE, $file ) ) {
                    $ff = join( '', <FILE> );
                    close FILE;
                }
                if( 1 || $params->{with_html_template} ) {
                    my $tpl = HTML::Template::Pro->new(
                        'die_on_bad_params' => 0,
                        'loop_context_vars' => 1,
                        'scalarref'         => \$ff,
                    );
                    $tpl->param( $params );
                    $ff = $tpl->output();
                }
            }

            my $query = 'select * from site_templates t, site_template_content c where c.parent_id = t.id and lang_id = ? and t.id = ?';
            my $TT = $self->dbh->selectrow_hashref( $query, undef, $self->guard->get_lang_id(), $I->get_template_id() );

            if( $TT->{content} ) {
                my $file = $self->guard->ini->template_dir . "/$prefix/" . $TT->{content};
                if( -s $file && open( FILE, $file ) ) {
                    $out = join( '', <FILE> );
                    close FILE;

                    my $tpl = HTML::Template::Pro->new(
                        'die_on_bad_params' => 0,
                        'loop_context_vars' => 1,
                        'scalarref'         => \$out,
                    );
                    $tpl->param( __content__ => $ff );
                    $out = $tpl->output();
                }
                else {
                    $out = $ff;
                }
            }
            else {
                $out = $ff;
            }

            $self->set_metadata( $I );
            $self->request->response->content( $SSI->process( $out ) );
        }
        else {
            $self->request->response->header( 'status', '404 Not Found' );
            warn '== tools_page -> ' . $params->{action} . '_action : ' . $I->get_name() . ' not found';
        }
    }
    else {
        $self->request->response->header( 'status', '404, not found' );
        warn '== tools_page -> output : no action defined';
    }
}

sub set_crumbs {
    my $self   = shift;
    my $params = shift;

    unless( $self->request->level() ) {
        my $ppp = $self->request->url->path();
        $ppp =~ s/\/$//;
        foreach ( @{ $params->{url} } ) {
            $ppp .= '/' . $_->get_name();
            $self->request->response->crumbs(
                {
                    name  => $_->get_name(),
                    alias => $_->get_alias( $self->guard->get_lang_id ) || $_->get_name(),
                    href  => $ppp
                }
            );
        }

        if( $params->{item} ) {
            $self->request->response->crumbs(
                {
                    name  => $params->{item}->get_name(),
                    alias => $params->{item}->get_alias( $self->guard->get_lang_id ) || $params->{item}->get_name(),
                    href  => $ppp . '/' . $params->{item}->get_name() . '.' . $self->request->url->extension()
                }
            );
        }
    }
}




return 1;
