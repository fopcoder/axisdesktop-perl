package HellFire::Response;

use strict;
use HellFire::Global;

our $CRLF = "\n";

my %content_type_ext = (
	html => 'text/html',
	htm => 'text/html',
	css => 'text/css',
	js => 'text/javascript',
	json => 'application/javascript',
	txt => 'text/plain',
	xhtml => 'application/xhtml+xml',
	xhtm => 'application/xhtml+xml',
	xml => 'text/xml',
	xsl => 'text/xml'
);

sub new {
	my $class = shift;

	my $self = { 
		header => {
			'SET-COOKIE' => undef,
			'LOCATION' => undef,
			'STATUS' => 200,
			'CONTENT-TYPE' => 'text/html; charset=utf-8',
			'CACHE-CONTROL' => 'max-age=0'
		},
		content => undef,
		cookie => [],
		crumbs => [],
		_global => new HellFire::Global
	};

	bless $self, $class;

	return $self;
}
=head
our $HTTPCode = {
    200 => 'OK',
    204 => 'No Content',
    206 => 'Partial Content',
    302 => 'Found',
    304 => 'Not Modified',
    400 => 'Bad request',
    403 => 'Forbidden',
    404 => 'Not Found',
    416 => 'Request range not satisfiable',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    503 => 'Service Unavailable',
};
=cut

sub header	{
	my $self = shift;
	my $out;
	
	if(@_)	{
		if( uc( $_[0] ) eq 'SET-COOKIE' )        {
			$self->cookie( $_[1] );
		}
		else	{
			$self->{header}->{ uc( $_[0] ) } = $_[1];
		}
	}
	else	{
		$self->{header}->{ 'LAST-MODIFIED' } = undef;
		foreach( keys %{$self->{header}} )	{
			if( $_ eq 'SET-COOKIE' )	{
				foreach my $c ( @{$self->{cookie}} )	{
					$out .= $_.':'.$c.$CRLF;
				}
			}
			elsif( $self->{header}->{$_} )	{
				$out .= $_.': '.$self->{header}->{ uc( $_ ) }.$CRLF;
			}
		}
	}
	
	return $out.$CRLF;
}

sub cookie	{
	my $self = shift;
	my $c = shift;
	
	if( $c )	{
		push @{$self->{cookie}}, $c;
	}
}

sub content	{
	my $self = shift;

	if( @_ )	{
		$self->{content} = $_[0];
	}

	return $self->{content};
}

sub global {
    my $self = shift;
    return $self->{'_global'};
}

sub crumbs {
    my $self = shift;
	push @{ $self->global->{'_crumbs'} }, shift if( @_ );
    #$self->global->{'_crumbs'} = shift if( @_ );
    return $self->global->{'_crumbs'};
}

#sub set_crumbs	{
#	my $self = shift;
#	my $val = shift;
#	push @{$self->{crumbs}}, $val;
#}
#
#sub get_crumbs	{
#	my $self = shift;
#	return	\@{$self->{crumbs}};
#}

sub set_content_type	{
	my $self = shift;
	my $ext = shift || 'html';
	
	my $a = $content_type_ext{ lc( $ext ) }||'text/html';
	$self->header( 'CONTENT-TYPE', $a.'; charset=utf-8' );
}

return 1;
