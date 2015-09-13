package Gears::StaticPage;

use strict;
use base qw(Gears);
use HTML::Template::Pro;
use CGI::SSI_M;

sub new {
	my $class = shift;
	my $self;

	$self->{_request} = shift;
	$self->{_dbh}     = $self->{_request}->dbh;
	$self->{_guard}   = $self->{_request}->guard;

	bless $self, $class;
	return $self;
}

sub go_action	{
	my $self = shift;
warn 444;	
	$self->request->response->header( 'Status', 302 );
	$self->request->response->header( 'Location', $ENV{QUERY_STRING} );
	print $self->request->response->header();
	exit;
}

sub index_action {
	my $self = shift;

	$self->output( { action => 'index', item => ${$self->request->url->param()}[0] } );
}

sub item_action {
	my $self = shift;

	if( defined ${$self->request->url->param()}[0] )	{
		
		$self->output( { action => 'index', item => ${$self->request->url->param()}[0] } );
	}
	else	{
		$self->output( { action => 'item' } );
	}
}

sub crumbs_action	{
	my $self = shift;
	
	$self->output( {
		action => 'crumbs',
		crumbs => $self->request->response->crumbs(),
		with_html_template => 1
	} );
	
}

sub output {
	my $self   = shift;
	my $params = shift;

	if( $params->{action} ) {
		my $out;
		my $ff;
		my $I;
		
		if( $params->{action} eq 'index' )	{
			$I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
			$I->set_parent_id( $self->request->url->site_object->get_id() );
			$I->load( $I->find( $params->{item} || 'index.html' ) );
		}
		else	{
			$I = $self->request->url->site_object();
		}

		unless( $self->request->level() )	{
			$self->request->response->header('Last-Modified', $I->get_last_modified() );
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
				if( $params->{with_html_template} )	{
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
			$self->request->response->header('status','404 Not Found');
			warn '== static_page -> '.$params->{action}.'_action : ' . $I->get_name() . ' not found';
		}
	}
	else {
		$self->request->response->header('status','404, not found');
		warn '== static_page -> output : no action defined';
	}
}

return 1;
