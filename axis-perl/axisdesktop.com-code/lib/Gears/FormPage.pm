package Gears::FormPage;

use strict;
use base qw{Gears};
use CGI::SSI_M;
use HTML::Template::Pro;
use MIMEMAIL_M;

sub new {
	my $class = shift;
	my $self;

	$self->{_request} = shift;
    $self->{_dbh}     = $self->{_request}->dbh;
    $self->{_guard}   = $self->{_request}->guard;

	bless $self, $class;
	return $self;
}

sub send_form_action	{
	require HellFire::File::ItemDAO;
	
	my $self = shift;

	my $params = $self->eval_params();
	my @arr;
	foreach ( $self->request->q->param() )	{
		unless( $_ eq 'fileupload' )	{
			push @arr, { name => $_, value => $self->request->q->param($_) };
		}
	}

	my @files;	
	foreach( $self->request->q->param('fileupload') )	{
		my $File = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		my $f2;
		$f2 = $self->request->q->param_filename('fileupload') if( $self->request->q->can('param_filename') );
		$File->upload( $_, $f2 );
		push @files, $File;
	}
	
	my $mail_to   = $params->{mail_to} || $self->guard->ini->obj->{_}->{email_admin};
	my $mail_from = $params->{mail_from} || $self->guard->ini->obj->{_}->{email_admin};
	my $subj      = $params->{subject} . ' ' . $self->request->q->param( 'subject' ) || 'subj';
	
	my $out = $self->request->url->site_object->get_content_data( $self->guard->get_lang_id );
	
	my $tpl = HTML::Template::Pro->new(
		'die_on_bad_params' => 0,
		'loop_context_vars' => 1,
		'scalarref'         => \$out,
	);
	$tpl->param( message => \@arr );
	$out = $tpl->output();

	if( $mail_to && $mail_from ) {
		my $mail = MIMEMAIL_M->new('HTML');
		$mail->{senderMail} = $mail_from;
		$mail->{subject} = $subj;
		$mail->{charSet} = 'utf-8';
		$mail->{body} = $out;
		foreach( @files )	{
			push @{$mail->{attachments}}, $_->get_tmp();
		}

		$mail->create();
		if( !$mail->send( $mail_to ) ) { warn "form_page ==> send mail error: ". $mail->{error}; }
	}
	
	foreach( @files )	{
		unlink $_->get_tmp();
	}

	$self->request->response->header( 'Location', $ENV{HTTP_REFERER}.'/success.ax' );
	$self->request->response->header( 'Status', 302 );
	print $self->request->response->header();
	exit;
}

sub success_action	{
	my $self = shift;
	$self->output( {
		action => 'item',
		item => ${$self->request->url->param()}[0]
	} );
}

sub index_action {
	my $self = shift;
	$self->output( {
		action => 'index',
		item => ${$self->request->url->param()}[0]
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
			$I->load( $I->find( $params->{item} || 'index.tpl' ) );
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
				$ff = $I->get_content_data( $self->guard->get_lang_id() );
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
			warn '== form_page -> '.$params->{action}.'_action : ' . $I->get_name() . ' not found';
		}
	}
	else {
		$self->request->response->header('status','404, not found');
		warn '== form_page -> output : no action defined';
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

#
#sub run	{
#	my $self = shift;
#	my $G = $self->request->guard;
#	my $O = $self->request->url->site_object;
#	my $url = $self->request->url->param;
#	my $q = $self->request->q;
#
#	my $ref = ref $O;
#	my $SSI = new CGI::SSI_M( dbh => $self->dbh, q => $q, guard => $G, request => $self->request  );
#
#	my $out;
#	my $CO = undef;
#	my $CM;
#
#	if( $ref eq 'HellFire::Site::CategoryDAO' )	{
#		my $I = new HellFire::Site::ItemDAO( $self->dbh, $G ); 
#		$I->set_parent_id( $O->get_id() );
#
#		if( $$url[-1] eq 'mail'  ) {
#			$I->load( $I->find('mail.html') );
#		}
#		elsif( $$url[-1] eq 'thanks' )  {
#			$I->load( $I->find('thanks.html') );
#		}
#		else	{
#			$I->load( $I->find('index.html') );
#		}
#
#		$CO = $I;
#		$CM = new HellFire::Site::ItemDAO( $self->dbh, $G );
#		$CM->set_parent_id( $CO->get_id() );
#		$CM->load( $I->find('.context_menu.html') );
#	}
#	elsif( $ref eq 'HellFire::Site::ItemDAO' )	{
#		$CO = $O;
#		$CM = new HellFire::Site::ItemDAO( $self->dbh, $G );
#		$CM->set_parent_id( $CO->get_parent_id() );
#		$CM->load( $CM->find('.context_menu.html') );
#	}
#
#	$ENV{DOCUMENT_TITLE} = $CO->get_title( $G->get_lang_id() ) unless( $ENV{DOCUMENT_TITLE} );
#	$ENV{DOCUMENT_ALIAS} = $CO->get_alias( $G->get_lang_id() ) unless( $ENV{DOCUMENT_ALIAS} );
#	$ENV{DOCUMENT_KEYWORDS} = $CO->get_keywords( $G->get_lang_id() ) unless( $ENV{DOCUMENT_KEYWORDS} );
#	$ENV{DOCUMENT_DESCRIPTION} = $CO->get_description( $G->get_lang_id() ) unless( $ENV{DOCUMENT_DESCRIPTION} );
#
#
#	unless( $ENV{DOCUMENT_CRUMBS} )	{
#		$ENV{DOCUMENT_CRUMBS} = 1;
#		my $N = new HellFire::Request( $self->dbh, $G, $q );
#		$N->request('/include/crumbs.html');
#		my $tpl1 = HTML::Template::Pro->new(
#				'die_on_bad_params' => 0,
#				'loop_context_vars' => 1,
#				'scalarref' => \$N->response->content,
#				);
#		$tpl1->param( crumbs => $self->request->response->get_crumbs() );
#
#		$ENV{DOCUMENT_CRUMBS} = $tpl1->output();
#	}
#
#	my $S = new HellFire::Site::CategoryDAO( $self->{_dbh}, $G );
#	$S = $S->get_domain();
#	my $prefix = $S->get_id();
#	$prefix .= '/t';
#
#	my $prefixc = $S->get_id();
#	$prefixc .= '/c/'.$CO->get_parent_id();
#
#	if( $CM )    {
#	my $cm_body;
#	if( ( stat( $G->ini->template_dir."/$prefixc/".$CM->get_content( $G->get_lang_id() ) ))[7]  > 0 && 
#		open( FILE, $G->ini->template_dir."/$prefixc/".$CM->get_content( $G->get_lang_id() ) ) ) {
#		$cm_body = join('',<FILE>) ;
#		close FILE;
#	}
#unless( $ENV{CONTEXT_MENU} )    {
#        $ENV{CONTEXT_MENU} = $cm_body;
#        $ENV{IS_CONTEXT_MENU} = 1;
#    }
#
#	}
#
#	my $query = 'select * from site_templates t, site_template_content c where c.parent_id = t.id and lang_id = ? and t.id = ?';
#	my $TT = $self->{_dbh}->selectrow_hashref( $query, undef, $G->get_lang_id(), $CO->get_template_id() );	
#
#	if( $TT->{top} )	{
#		my $file = $G->ini->template_dir."/$prefix/".$TT->{top};
#		if( -s $file && open( FILE, $file ) ) {
#			$out .= $SSI->process( join('',<FILE>) );
#			close FILE;
#		}
#	}
#
#	if( $CO->get_content( $G->get_lang_id() ) )	{
#		my $file = $G->ini->template_dir."/$prefixc/".$CO->get_content( $G->get_lang_id() );
#		my $ff;
#		if( -s $file && open( FILE, $file ) ) {
#			$ff = $SSI->process( join('',<FILE>) );
#			close FILE;
#		}
#
#		my $tpl = HTML::Template::Pro->new(
#				'die_on_bad_params' => 0,
#				'loop_context_vars' => 1,
#				'scalarref' => \$ff,
#				associate => $q
#				);
#
#		$out .= $tpl->output();
#	}
#
#	if( $TT->{bottom} )	{
#		my $file = $G->ini->template_dir."/$prefix/".$TT->{bottom};
#		if( -s $file && open( FILE, $file ) ) {
#			$out .= $SSI->process( join('',<FILE>) );
#			close FILE;
#		}
#	}
#
#
#	if( $$url[-1] eq 'mail' ) {
#	    my $mail_to = $self->config->{ $self->guard->get_path() }->{email_to} || $G->ini->obj->{_}->{email_admin};
#	    my $mail_from = $self->config->{ $self->guard->get_path() }->{email_from} || $G->ini->obj->{_}->{email_from} ;
#	    my $subj = $self->config->{ $self->guard->get_path() }->{subject} || 'subj';
#
#	    if( $mail_to && $mail_from && open(MAIL, "|/usr/sbin/sendmail -t") )    {
#		my $entity = MIME::Entity->build(
#		    From        => $mail_from,
#		    To          => $mail_to,
#		    Type        => "text/html",
#		    Subject     => $subj,
#		    Charset     => "utf-8",
#		    Data        => \$out 
#		);
#
#		$entity->print(\*MAIL);
#		close(MAIL);
#
#	    }
#	    else    {
#		warn " FUCK EMAIL !!!!";
#	    }


return 1;
