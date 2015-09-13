package HellFire::Site::DomainDAO;

use strict;
use base qw(HellFire::Site);

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}      = $dbh;
	$self->{'_guard'}    = $G;
	$self->{'_children'} = undef;

	bless $self, $class;
	return $self;
}

sub save_site_alias {
	my $self   = shift;
	my $params = shift;
	my $id     = 0;

	if( $params->{id} ) {
		$id = $self->update_site_alias( $params );
	}
	else {
		$id = $self->insert_site_alias( $params );
	}

	return $id;
}

sub update_site_alias {
	my $self   = shift;
	my $params = shift;

	my $access = $self->get_action( 'site_category_update' ) || $self->guard->is_administrator();

	if( $params->{'name'} && $params->{'id'} && $access ) {
		my $query = 'update site_aliases set name = ? where id = ?';
		$self->dbh->do( $query, undef, $params->{'name'}, $params->{'id'} );
		return $params->{'id'};
	}

	return undef;
}

sub insert_site_alias {
	my $self   = shift;
	my $params = shift;

	my $access = $self->get_action( 'site_category_add' ) || $self->guard->is_administrator();

	if( $params->{'name'} && $self->get_id && $access ) {
		my $query = 'insert into site_aliases(name, parent_id) values(?,?)';
		$self->dbh->do( $query, undef, $params->{'name'}, $self->get_id );
		return $self->dbh->last_insert_id( undef, undef, undef, undef );
	}

	return undef;
}

1;