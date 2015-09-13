package HellFire::DataBase;

use strict;
use DBI;

sub new  {
    my $class = shift;
    my $self = {};
    $self->{_ini} = shift;
    $self->{_params} = shift;

    bless $self, $class;
    return $self;
}

sub connect { 
	my $self = shift;
	my $name = shift || 'default_connection';

	my $dsn = $self->params->{dsn} || $self->ini->obj->{$name}->{dsn};
	my $user = $self->params->{user} || $self->ini->obj->{$name}->{user};
	my $password = $self->params->{password} || $self->ini->obj->{$name}->{password};

	$self->{_dbh} = DBI->connect_cached( $dsn, $user, $password, {'PrintError' => 1, 'AutoCommit' => 1});
	$self->{_dbh}->{mysql_auto_reconnect} = 1;
	$self->{ 'error' } = $DBI::errstr;
	$self->dbh->do('SET names utf8');
	$self->dbh->do('SET SESSION group_concat_max_len = 10485760');
	return $self->dbh;
}

sub ini	{
    my $self = shift;
    return $self->{_ini};
}

sub dbh	{
    my $self = shift;
    return $self->{_dbh};
}

sub params	{
    my $self = shift;
    return $self->{_params}||{};
}

sub get_set_values  {
    my $self = shift;
    my $table = shift||'';
    my $field = shift||'';

    my $query = "show columns from $table  like ?";
    my @arr = $self->dbh->selectrow_array( $query, undef, $field );

    $arr[1] =~ s/set|\(|\)|\'//g;
    my @ret = sort split(/,/,$arr[1]);

    return \@ret;
}

return 1;
