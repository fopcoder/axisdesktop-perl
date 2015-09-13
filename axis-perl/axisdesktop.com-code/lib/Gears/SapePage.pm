package Gears::SapePage;

use strict;
use base qw(Gears);

sub new {
	my $class = shift;
	my $self;

	$self->{_request} = shift;
	$self->{_dbh}     = $self->{_request}->dbh;
	$self->{_guard}   = $self->{_request}->guard;

	bless $self, $class;
	return $self;
}

sub index_action {
	my $self = shift;
    $self->output();
}

sub item_action {
	my $self = shift;
    $self->output();
}

sub output {
	my $self   = shift;
	my $params = shift;

    #"$ENV{DOCUMENT_ROOT}/9e3509a7c89b0b43b18c0b1f59c842b3/SAPE.pm" =~ /^(.+)$/;
    #warn $1;
    #require '/var/www/virtual/axisdesktop.com/htdocs/9e3509a7c89b0b43b18c0b1f59c842b3/SAPE.pm';
    #require $1;
    
    use lib "$ENV{DOCUMENT_ROOT}/9e3509a7c89b0b43b18c0b1f59c842b3";
    use SAPE;
    
    
    my $sape = new SAPE::Client(
    	user    => '9e3509a7c89b0b43b18c0b1f59c842b3',
#    	host    => '<ИМЯ_ХОСТА>',  # необязательно, по умолчанию: $ENV{HTTP_HOST}
    	charset => 'utf-8', # необязательно, по умолчанию: windows-1251
    );
    
    my $out = $sape->get_links;
$out ||= ' ';
	
	use Encode;
        $out = encode('UTF-8',$out);

    $self->request->response->content( $out );
}

return 1;
