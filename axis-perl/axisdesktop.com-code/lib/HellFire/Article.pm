package HellFire::Article;

use strict;
use base qw(HellFire);

sub new {
    my $class = shift;
    my $self;# = $class->SUPER::new();

    $self->{ '_ordering' } = undef;
    $self->{ '_inserted' } = undef;
    $self->{ '_flags' } = {};

    bless $self, $class;
    return $self;
}

sub set_ordering    {
    my $self = shift;
    $self->{ '_ordering' } = shift;
    return $self->{ '_ordering' };
}

sub get_ordering    {
    my $self = shift;
    return $self->{ '_ordering' }||0;
}

sub set_updated    {
    my $self = shift;
    $self->{ '_updated' } = shift;
    return $self->{ '_updated' };
}

sub get_updated    {
    my $self = shift;
    return $self->{ '_updated' }||'';
}

sub set_inserted    {
    my $self = shift;
    $self->{ '_inserted' } = shift;
    return $self->{ '_inserted' };
}

sub get_inserted    {
    my $self = shift;
    return $self->{ '_inserted' }||'';
}


sub get_alias    {
    my $self = shift;
    my $val = shift;

    return $self->{ '_aliases' }->{ $val }||'';
}

sub set_alias    {
    my $self = shift;
    my $id = shift;
    my $val = shift;

    $self->{ '_aliases' }->{ $id } = $val;
    return $self->{ '_aliases' }->{ $id };
}

sub set_user_id    {
    my $self = shift;
    $self->{ '_user_id' } = shift;
    return $self->{ '_user_id' };
}

sub get_user_id    {
    my $self = shift;
    return $self->{ '_user_id' }||0;
}

sub is_system	{
    my $self = shift;
    return $self->get_flag('SYSTEM');
}

sub is_locked	{
    my $self = shift;
    return $self->get_flag('LOCKED');
}

sub is_inherit	{
    my $self = shift;
    return $self->get_flag('INHERIT');
}

sub parse_mysql_date	{
    my $self = shift;
    my $val = shift;
    my $pref = shift||'';
    my $ret;

    $val =~ /(\d+)\-(\d+)\-(\d+) (\d+):(\d+):(\d+)/;

    $ret->{$pref.'year'} = $1;
    $ret->{$pref.'month'} = $2;
    $ret->{$pref.'day'} = $3;
    $ret->{$pref.'hour'} = $4;
    $ret->{$pref.'minute'} = $5;
    $ret->{$pref.'second'} = $6;

    return $ret;
}

sub get_description {
	my $self = shift;
	my $val  = shift;

	return $self->{'_descriptions'}->{$val} || '';
}

sub set_description {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_descriptions'}->{$id} = $val;
	return $self->{'_descriptions'}->{$id};
}

sub get_title {
	my $self = shift;
	my $val  = shift;
	return $self->{'_titles'}->{$val} || '';
}

sub set_title {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_titles'}->{$id} = $val;
	return $self->{'_titles'}->{$id};
}

sub get_keywords {
	my $self = shift;
	my $val  = shift;
	return $self->{'_keywords'}->{$val} || '';
}

sub set_keywords {
	my $self = shift;
	my $id   = shift;
	my $val  = shift;

	$self->{'_keywords'}->{$id} = $val;
	return $self->{'_keywords'}->{$id};
}

return 1;
