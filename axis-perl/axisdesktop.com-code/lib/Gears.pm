## @file
# Implementation of Gears

## @class
# Base output class
package Gears;

use strict;

sub new {
    my $class = shift;
    my $self = {};
    
    bless $self, $class;
    return $self;
} 

sub config {
	my $self = shift;
	return $self->{ '_config' };
}

sub dbh {
	my $self = shift;
	return $self->{ '_dbh' };
}

sub guard {
	my $self = shift;
	return $self->{ '_guard' };
}

sub request {
	my $self = shift;
	return $self->{ '_request' };
}

sub run {
	my $self = shift;

	if( $self->request->get_action() ) {
		my $f = $self->request->get_action() . '_action';
		if( $self->can( $f ) ) {
			$self->$f;
		}
		else {
			warn '== gears -> run : no ' . $self->request->get_action() . '_action';
		}
	}
	elsif( ref $self->request->url->site_object eq 'HellFire::Site::ItemDAO' ) {
		$self->item_action();
	}
	elsif( $self->request->url->extension() && ref $self->request->url->site_object eq 'HellFire::Site::CategoryDAO' ) {
		$self->item_action();
	}
	else {
		$self->index_action();
	}
}

sub item_action	{
	my $self = shift;	
}

sub index_action	{
	my $self = shift;	
}

sub set_metadata {
	my $self = shift;
	my @obj  = @_;

	foreach ( @obj )	{
		next unless( defined $_ );
		unless( $ENV{DOCUMENT_TITLE} )  {
			$ENV{DOCUMENT_TITLE} = $_->get_title( $self->guard->get_lang_id() );
			if( $self->request->page() )    {
			    $ENV{DOCUMENT_TITLE} .= ' ['.$self->request->page().']';
			}
		}

		#$ENV{DOCUMENT_TITLE}       = $_->get_title( $self->guard->get_lang_id() )       unless( $ENV{DOCUMENT_TITLE} );
		$ENV{DOCUMENT_ALIAS}       = $_->get_alias( $self->guard->get_lang_id() )       unless( $ENV{DOCUMENT_ALIAS} );
		$ENV{DOCUMENT_KEYWORDS}    = $_->get_keywords( $self->guard->get_lang_id() )    unless( $ENV{DOCUMENT_KEYWORDS} );
		$ENV{DOCUMENT_DESCRIPTION} = $_->get_description( $self->guard->get_lang_id() ) unless( $ENV{DOCUMENT_DESCRIPTION} );
	}
}

sub paging	{
	my $self = shift;
	my $params = shift;
	
	#my $paging = {
	#	paging => [],
	#	paging_first => undef,
	#	paging_last => undef,
	#	paging_prev => undef,
	#	paging_next => undef
	#};
	my @res;
	if( $params->{count_all} > $params->{limit} && $params->{limit} > 0  )	{
		
		my $p = int($params->{count_all} / $params->{limit} + 0.9999999 );
		$params->{href} =~ s/\/$//;
		
		for( my $i = 0; $i < $p; $i++ )	{
			push @res, {
				alias => $i+1,
				href =>  $i ? $params->{href}.'/:p='.$i : $params->{href},
				active => ( $params->{page} == $i ) ? 1 : 0,
				page => 1
			};
		}
	}
	
	return \@res;
}

sub eval_params	{
	my $self = shift;
	my $params;

    eval '$params = ' . $self->request->url->site_object->get_config();
	if( $@ )	{
		warn 'eval params error: '.$@;
	}
    $params ||= {};
	return $params;
}

return 1;
