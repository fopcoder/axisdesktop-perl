package AxCrawler;
require 5.002;
use strict;

use HTTP::Request;
use HTTP::Status;
use HTML::TreeBuilder 3.03;
use URI::URL;
use LWP::RobotUA 1.171;
use IO::File;
use English;
use Encode qw( encode );

use HTML::LinkExtor;


use vars qw( $VERSION );
$VERSION = '0.026';

my %ATTRIBUTES = (
    'NAME'             => 'Name of the Robot',
    'VERSION'          => 'Version of the Robot, N.NNN',
    'EMAIL'            => 'Contact email address for Robot owner',
    'TRAVERSAL'        => 'traversal order - depth or breadth',
    'VERBOSE'          => 'boolean flag for verbose reporting',
    'IGNORE_TEXT'      => 'should we ignore text content of HTML?',
    'IGNORE_UNKNOWN'   => 'should we ignore unknown HTML elements?',
    'CHECK_MIME_TYPES' => 'should we check the MIME types of links?',
    'ACCEPT_LANGUAGE'  => 'array ref to list of languages to accept',
    'DELAY'            => 'delay between robot requests (minutes)',
    'ANY_URL'          => 'whether to omit default URL filtering',
    'ANY_LINK'         => 'whether to restrict to default link types',
    'ANY_CONTENT'      => 'whether to offer content of non-HTML documents',
    'WITH_TAG' => 'a|area|frame|iframe|form'
);

my %ATTRIBUTE_DEFAULT = (
    'TRAVERSAL'        => 'depth',
    'VERBOSE'          => 0,
    'IGNORE_TEXT'      => 1,
    'IGNORE_UNKNOWN'   => 1,
    'CHECK_MIME_TYPES' => 0,
    'ANY_URL'          => 0,
    'ANY_LINK'         => 0,
    'ANY_CONTENT'      => 0,
    'WITH_TAG'          => 'a|area'
);

my %SUPPORTED_HOOKS = (
    'restore-state'          => 'opportunity for client to restore state',
    'invoke-on-all-url'      => 'invoked on all URLs (even not visited)',
    'follow-url-test'        => 'return true if robot should visit the URL',
    'invoke-on-followed-url' => 'invoked on only URLs which are visited',
    'invoke-on-get-error'    => 'invoked when HTTP request results in error',
    'invoke-on-contents'     => 'invoked on contents of each visited URL',
    'invoke-on-link'         => 'invoked on all links seen on a page',
    'add-url-test'           => 'returns true if robot should add URL',
    'continue-test'          => 'return true if should continue iterating',
    'save-state'             => 'opportunity for client to save state',
    'generate-report'        => 'report for the run just finished',
    'modified-since'         => 'returns modified-since time for URL passed',
    'invoke-after-get'       => 'invoked right after every GET request',
);

sub new {
    my $class   = shift;
#    my %options = @ARG;
    my $options = shift;

    my $object = bless {}, $class;
    $object->{'__urls__'} = [];
    return $object->initialise( $options );
}

sub run {
    my $self     = shift;
    my @url_list = @ARG;    # optional list of URLs

    return undef unless $self->required_attributes_set();
    return undef unless $self->required_hooks_set();

    $self->addUrl( @url_list );
    $self->invoke_hook_procedures( 'restore-state' );

    my $url;

    while ( $url = $self->next_url() ) {
        $self->verbose( $url, "\n" );

        $self->invoke_hook_procedures( 'invoke-on-all-url', $url );
        next unless $self->invoke_hook_functions( 'follow-url-test', $url );
        $self->invoke_hook_procedures( 'invoke-on-followed-url', $url );

        my $response = $self->get_url( $url );

        # This hook function is for people who want to see the result
        # of every GET, so they can deal with odd cases, or whatever

        $self->invoke_hook_procedures( 'invoke-after-get', $url, $response );

        if( $response->is_error ) {
            $self->invoke_hook_procedures( 'invoke-on-get-error', $url, $response );
            next;
        }

        # If the request got a 304 (not modified), then we
        # can stop at this point.

        next if $response->code == RC_NOT_MODIFIED;

        # The response says we should use something else as the BASE
        # from which to resolve any relative URLs. This might be from
        # a BASE element in the HEAD, or just "foo" which should be "foo/"

        my $base = $response->base;

        if( $base ne $url ) {
            $url = new URI::URL( $base );
        }

        if( $response->content_type ne 'text/html' ) {
            if( $self->{'ANY_CONTENT'} ) {
                $self->invoke_hook_procedures(
                    'invoke-on-contents',
                    $url,
                    $response,
                    undef    # no $structure
                );
            }
        }
        else {

            my $contents = $response->content;
            utf8::decode( $contents );
            #$self->verbose( "Parse $url into HTML::TreeBuilder ..." );
            #my $structure = new HTML::TreeBuilder;
            #$structure->ignore_text if $self->getAttribute( 'IGNORE_TEXT' );
            #$structure->ignore_unknown
            #  if $self->getAttribute( 'IGNORE_UNKNOWN' );
            #$structure->parse( $contents );
            #$self->verbose( "\n" );

            my @page_urls;

            # Check page for page specific robot exclusion commands

            my( $noindex, $nofollow ) = (0,0);#$self->check_protocol( $structure, $url );
            if( $nofollow == 0 ) {
                $self->verbose( "Extract links from $url\n" );
                @page_urls = $self->extract_links( $url, $base, $contents );
            }
            if( $noindex == 0 ) {
                #$self->invoke_hook_procedures( 'invoke-on-contents', $url, $response, $structure );
                $self->invoke_hook_procedures( 'invoke-on-contents', $url, $response, $contents );

                # delete required, because of potential circular links

            }
            foreach my $link_url ( @page_urls ) {
                $self->invoke_hook_procedures( 'invoke-on-link', $url, $link_url );
                $self->addUrl( $link_url );
            }
            #$structure->delete() if defined $structure;
        }
    }
    continue {

        # If there is no continue-test hook, then we will continue until
        # there are no more URLs.

        last if( exists $self->{'HOOKS'}->{'continue-test'}
            and not $self->invoke_hook_functions( 'continue-test' ) );
    }

    $self->invoke_hook_procedures( 'save-state' );
    $self->invoke_hook_procedures( 'generate-report' );

    return 1;
}

sub setAttribute {
    my $self  = shift;
    my %attrs = @ARG;

    while ( my( $attribute, $value ) = each( %attrs ) ) {
        #unless( exists $ATTRIBUTES{$attribute} ) {
        #    $self->warn( "unknown attribute $attribute - ignoring it." );
        #    next;
        #}
        $self->{$attribute} = $value;
    }
}

sub getAttribute {
    my $self      = shift;
    my $attribute = shift;

    unless( exists $ATTRIBUTES{$attribute} ) {
        $self->warn( "unknown attribute $attribute" );
        return undef;
    }

    return $self->{$attribute};
}

sub getAgent {
    my $self = shift;

    return $self->{'AGENT'};
}

sub addUrl {
    my $self = shift;
    my @list = @ARG;

    my $status = 1;

    foreach my $url ( @list ) {
        next if exists $self->{'SEEN_URL'}->{$url};

        # create a URI::URL object for the url, if needed

        my $urlObject;

        if( ref $url ) {
            $urlObject = $url;
        }
        else {
            $urlObject = eval { new URI::URL( $url ) };
            if( $EVAL_ERROR ) {
                $self->warn( <<WARNING );
Unable to create URI::URL object for $url: $EVAL_ERROR
WARNING
                $status = 0;
                next;
            }
        }

        # Mark the URL as having been seen by the robot, then add it
        # to the list of URLs for the robot to visit. Doing it this way
        # means we won't get duplicate URLs on the list.

        $self->{'SEEN_URL'}->{$url} = 1;

        # $self->{ 'URL_LIST' } = [] if not exists $self->{ 'URL_LIST' };
        push( @{ $self->{'URL_LIST'} }, $urlObject );
    }

    return $status;
}

sub unshiftUrl {
    my $self = shift;
    my @list = @ARG;

    my $status = 1;

    foreach my $url ( @list ) {
        next if exists $self->{'SEEN_URL'}->{$url};

        # create a URI::URL object for the url, if needed

        my $urlObject;

        if( ref $url ) {
            $urlObject = $url;
        }
        else {
            $urlObject = eval { new URI::URL( $url ) };
            if( $EVAL_ERROR ) {
                $self->warn( <<WARNING );
Unable to create URI::URL object for $url: $EVAL_ERROR
WARNING
                $status = 0;
                next;
            }
        }

        # Mark the URL as having been seen by the robot, then add it
        # to the list of URLs for the robot to visit. Doing it this way
        # means we won't get duplicate URLs on the list.

        $self->{'SEEN_URL'}->{$url} = 1;

        # $self->{ 'URL_LIST' } = [] if not exists $self->{ 'URL_LIST' };
        unshift( @{ $self->{'URL_LIST'} }, $urlObject );
    }

    return $status;
}

sub listUrls {
    my $self = shift;
    return @{ $self->{'URL_LIST'} };
}

sub addHook {
    my $self      = shift;
    my $hook_name = shift;
    my $hook_fn   = shift;

    if( not exists $SUPPORTED_HOOKS{$hook_name} ) {
        $self->warn( <<WARNING );
Unknown hook name $hook_name; Ignoring it!
WARNING
        return undef;
    }

    if( ref( $hook_fn ) ne 'CODE' ) {
        $self->warn( <<WARNING );
$hook_fn is not a function reference; Ignoring it
WARNING
        return undef;
    }

    if( exists $self->{'HOOKS'}->{$hook_name} ) {
        push( @{ $self->{'HOOKS'}->{$hook_name} }, $hook_fn );
    }
    else {
        $self->{'HOOKS'}->{$hook_name} = [$hook_fn];
    }

    return 1;
}

sub proxy {
    my $self = shift;
    my @argv = @ARG;

    return $self->{'AGENT'}->proxy( @argv );
}

sub no_proxy {
    my $self = shift;
    my @argv = @ARG;

    return $self->{'AGENT'}->no_proxy( @argv );
}

sub env_proxy {
    my $self = shift;

    return $self->{'AGENT'}->env_proxy();
}

sub required_attributes_set {
    my $self = shift;

    $self->verbose( "Check that the required attributes are set ...\n" );
    my $status = 1;

    for( qw( NAME VERSION EMAIL ) ) {
        if( not defined $self->{$_} ) {
            $self->warn( "You haven't set the $_ attribute" );
            $status = 0;
        }
    }

    $self->{'AGENT'}->from( $self->{'EMAIL'} );
    $self->{'AGENT'}->agent( $self->{'NAME'} . '/' . $self->{'VERSION'} );
    $self->{'AGENT'}->delay( $self->{'DELAY'} )
      if defined( $self->{'DELAY'} );

    if( defined( $self->{'TRAVERSAL'} ) ) {

        # check that TRAVERSAL is set to a legal value

        unless($self->{'TRAVERSAL'} eq 'depth'
            or $self->{'TRAVERSAL'} eq 'breadth' )
        {
            $self->warn( <<WARNING );
Ignoring unknown traversal method $self->{ TRAVERSAL }; using depth
WARNING
            $self->{'TRAVERSAL'} = 'depth';
        }
    }
    else {
        $self->{'TRAVERSAL'} = 'depth';
    }

    $self->verbose( "Traversal type set to $self->{ 'TRAVERSAL' }\n" );

    return $status;
}

sub required_hooks_set {
    my $self = shift;

    $self->verbose( "Check that the required hooks are set ...\n" );

    if( not exists $self->{'HOOKS'}->{'follow-url-test'} ) {
        $self->warn( "You must provide a `follow-url-test' hook." );
        return 0;
    }

    my $status = 0;

    for(
        qw(
        invoke-on-all-url
        invoke-on-followed-url
        invoke-on-contents
        invoke-on-link
        )
      )
    {
        $status = 1 if exists $self->{'HOOKS'}->{$_};
    }

    $self->warn( "You must provide at least one invoke-on-* hook." )
      unless $status;
    return $status;
}

sub extract_links {
    my $self     = shift;
    my $url      = shift;
    my $base     = shift;
    my $contents = shift;

    my %url_seen;

    $self->verbose( "Extract links from $url (base = $base) ...\n" );

    utf8::decode( $contents );
    #my( $link_extor ) = new HTML::TreeBuilder->new->parse( $contents );
    #
    #my( @default_link_types ) = ( 'a', 'area', 'frame' );
    #
    ## () means 'all types'
    #
    #my @abslinks = ();
    #
    #my @eltlinks = map { $_->[0] } @{
    #      $self->{'ANY_LINK'}
    #    ? $link_extor->extract_links()
    #    : $link_extor->extract_links( @default_link_types )
    #  };
    #
    #$link_extor->delete() if defined $link_extor;
    my @abslinks = ();
    my @eltlinks = $self->fuck_links( $contents );

    foreach my $link ( @eltlinks ) {
        $self->verbose( "Process link: '$link'\n" );

        # ignore page internal links

        next if $link =~ m!^#!;

        # strip hashes (i.e. ignore / don't distinguish page internal links)

        $link =~ s!#.*!!;

        my $link_url = eval { new URI::URL( $link, $url ) };

        if( $EVAL_ERROR ) {
            $self->warn( "unable to create URL object for link.", "LINK:  $link", "Error: $EVAL_ERROR\n" );
            next;
        }

        $URI::URL::ABS_REMOTE_LEADING_DOTS = 1;

        my $link_url_abs = $link_url->abs();

        unless(
            $self->{'ANY_URL'}
            ||

            # only follow html links (.html or .htm or no extension)
            $link =~ /\.s?html?/ || $link =~ m{/$}
          )

          # lets assume .s?html  or "/" type links really are text/html
        {

            # put in some obvious ones here ...
            next if $link =~ /(?:ftp|gopher|mailto|news|telnet|javascript):/;
            next if $link =~ /\.(?:gif|jpe?g|png)/;
            if( $self->{'CHECK_MIME_TYPES'} ) {

                # grab anchor / area / frame links
                $self->verbose( " check mime type ..." );
                next
                  unless $self->check_mime_type( $link_url_abs, ['text/html'] );
            }
        }

        # only follow links we haven't seen yet ...

        next if $url_seen{$link};
        $url_seen{$link}++;

        next if( exists $self->{'HOOKS'}->{'add-url-test'}
            and not $self->invoke_hook_functions( 'add-url-test', $link_url_abs ) );
        push( @abslinks, $link_url_abs );
        $self->verbose( "Adding  link: '$link_url_abs'\n" );

    }

    $self->verbose( "\n" );
    return ( @abslinks );
}

sub fuck_links  {
    my $self = shift;
    my $contents = shift;
    
    my @links;
    my $p = HTML::LinkExtor->new( sub {
        my( $tag, %links ) = @_;
        if( $tag =~ /$self->{WITH_TAG}/ )   {
            push @links, values %links;
        }
    } );
    $p->parse( $contents );
    return @links;
}

sub check_mime_type {
    my $self       = shift;
    my $url        = shift;
    my $mime_types = shift;

    my $request = new HTTP::Request( 'HEAD', $url );
    return 0 unless $request;
    if( ref( $self->{'ACCEPT_LANGUAGE'} ) eq 'ARRAY' ) {
        $request->push_header( 'Accept-Language' => join( ',', @{ $self->{'ACCEPT_LANGUAGE'} } ) );
    }
    $self->verbose( " HEAD $url ...\n" );
    my $response = $self->{'AGENT'}->request( $request );
    return 0 unless defined $response;
    return 0 unless $response->is_success;
    my $content_type = $response->content_type();
    return 0 unless defined $content_type;
    for( @$mime_types ) {
        return 1 if $_ eq $content_type;
    }
    return 0;
}

sub check_protocol {
    my $self      = shift;
    my $structure = shift;
    my $url       = shift;

    my $noindex  = 0;
    my $nofollow = 0;

    $self->verbose( "Check META NAME=ROBOTS ...\n" );

    # recursively traverse the page elements, looking for META with
    # NAME=ROBOTS, then look for directives in the CONTENTS.

    $structure->traverse(
        sub {
            my $node       = shift;
            my $start_flag = shift;
            my $depth      = shift;

            return 1 unless $start_flag;
            return 1 if $node->tag() ne 'meta';
            my $name = $node->attr( 'name' );
            return 1 unless defined $name;
            return 1 unless lc( $name ) eq 'robots';
            my $content = lc( $node->attr( 'content' ) );
            foreach my $directive ( split( /,/, $content ) ) {
                if( $directive eq 'nofollow' or $directive eq 'none' ) {
                    $nofollow = 1;
                }
                if( $directive eq 'noindex' or $directive eq 'none' ) {
                    $noindex = 1;
                }
            }
            return 0;
        },
        1
    );

    $self->verbose( "ROBOT EXCLUSION -- IGNORING LINKS\n" )   if $nofollow;
    $self->verbose( "ROBOT EXCLUSION -- IGNORING CONTENT\n" ) if $noindex;

    return ( $noindex, $nofollow );
}

sub get_url {
    my $self = shift;
    my $url  = shift;

    my $request = new HTTP::Request( 'GET', $url );
    if( ref( $self->{'ACCEPT_LANGUAGE'} ) eq 'ARRAY' ) {
        my @lang = @{ $self->{'ACCEPT_LANGUAGE'} };
        $request->push_header( 'Accept-Language' => join( ',', @lang ) );
    }

    # Is there a modified-since hook?

    if( exists $self->{'HOOKS'}->{'modified-since'} ) {
        my $time = $self->invoke_hook_functions( 'modified-since', $url );
        if( defined $time && $time > 0 ) {
            $request->if_modified_since( int( $time ) );
        }
    }

    # make the request

    $self->verbose( "$self->{ AGENT } GET $url ..." );
    my $response = $self->{'AGENT'}->request( $request );
    $self->verbose( "\n" );

    return $response;
}

sub initialise {
    my $self    = shift;
    my $options = shift;

    my $attribute;

    $self->create_agent( $options ) || return undef;

    # set attributes which are passed as arguments

    foreach $attribute ( keys %$options ) {
        $self->setAttribute( $attribute, $options->{$attribute} );
    }

    # set those attributes which have a default value,
    # and which weren't set on creation.

    foreach $attribute ( keys %ATTRIBUTE_DEFAULT ) {
        if( not exists $self->{$attribute} ) {
            $self->{$attribute} = $ATTRIBUTE_DEFAULT{$attribute};
        }
    }

    return $self;
}

sub create_agent {
    my $self    = shift;
    my $options = shift;

    my $ua = delete $options->{'USERAGENT'};
    if( defined $ua ) {
        $self->{'AGENT'} = $ua;
    }
    else {
        eval { $self->{'AGENT'} = new LWP::RobotUA( 'NAME', 'FROM@DUMMY' ) };
        if( not $self->{'AGENT'} ) {
            $self->warn( "failed to create User Agent object: $EVAL_ERROR\n" );
            return undef;
        }
    }

    return 1;
}

sub next_url {
    my $self = shift;

    # We return 'undef' to signify no URLs on the list

    if( not exists $self->{'URL_LIST'} or @{ $self->{'URL_LIST'} } == 0 ) {
        return undef;
    }

    if( $self->{'TRAVERSAL'} eq 'depth' ) {
        return pop @{ $self->{'URL_LIST'} };
    }

    return shift @{ $self->{'URL_LIST'} };
}

sub invoke_hook_procedures {
    my $self      = shift;
    my $hook_name = shift;
    my @argv      = @ARG;

    return unless exists $self->{'HOOKS'}->{$hook_name};
    foreach my $hookfn ( @{ $self->{'HOOKS'}->{$hook_name} } ) {
        &$hookfn( $self, $hook_name, @argv );
    }
    return;
}

sub invoke_hook_functions {
    my $self      = shift;
    my $hook_name = shift;
    my @argv      = @ARG;

    my $result = 0;

    return $result unless exists $self->{'HOOKS'}->{$hook_name};

    foreach my $hookfn ( @{ $self->{'HOOKS'}->{$hook_name} } ) {
        $result ||= &$hookfn( $self, $hook_name, @argv );
    }
    return $result;
}

sub verbose {
    my $self = shift;

    print STDERR @ARG if $self->{'VERBOSE'};
}

sub warn {
    my $self  = shift;
    my @lines = shift;

    my $me = ref $self;

    print STDERR "$me: ", shift @lines, "\n";
    foreach my $line ( @lines ) {
        print STDERR ' ' x ( length( $me ) + 2 ), $line, "\n";
    }
}

1;

