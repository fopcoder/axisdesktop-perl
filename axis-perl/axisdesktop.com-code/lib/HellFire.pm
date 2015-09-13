## @file
# Implementation of HellFire

## @addtogroup HellFire
# @{
## @class
# Base class of admin modules

package HellFire;

## }@

use strict;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub set_id {
    my $self = shift;
    $self->{'_id'} = shift;
    return $self->{'_id'};
}

sub get_id {
    my $self = shift;
    return $self->{'_id'} || 0;
}

sub set_parent_id {
    my $self = shift;
    $self->{'_parent_id'} = shift;
    return $self->{'_parent_id'};
}

sub get_parent_id {
    my $self = shift;
    return $self->{'_parent_id'} || 0;
}

## @method string set_name( string name, hashref params )
# @brief Set object name 
# @param name : string : object name
# @param params hashref
#           - no_clean : boolean : do not clean name
# @return name : string : name of object
#
# @code
# $I->set_name( 'user_66' );
# $I->set_name( 'run', { no_clean => 1 } );
# @endcode
sub set_name {
    my $self = shift;
    my $val  = shift;
    my $params = shift;
    
	if( $params->{ tr_name } ) {
		$val = lc( $self->tr_name( $val ) );
	}
	
    if( $params->{ no_clean } ) {
        $self->{'_name'} = $val;
    }
    else    {
        $self->{'_name'} = $self->clean_name( $val );
    }
    
    return $self->{'_name'};
}

sub get_name {
    my $self = shift;
    return $self->{'_name'} || '';
}

sub clean_name {
    my $self = shift;
    my $val  = shift;

	$val =~ s/^\s+|\s+$//;
	$val =~ s/\s+/_/g;
    $val =~ s/[^A-Za-z0-9_\.\:\-]//g;
    return $val;
}

sub raise_error	{
    my $self = shift;
    if( @_ ){ $self->{'_error'} = shift };
    return  $self->{ '_error' };
}

sub get_error {
    my $self = shift;
    return  $self->{ '_error' };
}

sub set_error {
    my $self = shift;
    $self->{ '_error' } = shift;
    return  $self->{ '_error' };
}

sub flags_to_hash {
    my $self = shift;
    my $hash = shift;

    my @arr = sort split( /,/, $hash->{flags} );

    #$hash->{FLAGS_ARRAY} = \@arr;
    foreach ( @arr ) {
        $hash->{"FLAG_$_"} = 1;
    }
    delete $hash->{flags};
}

sub flags_to_string	{
	my $self = shift;
	
	my @arr;
	foreach( keys %{$self->{'_flags'}} )	{
		push @arr, $_ if( $self->get_flag($_) ); 
	}

	return join(',', @arr);
}

sub get_flag    {
	my $self = shift;
	my $val = shift;
	return $self->{ '_flags' }->{ uc $val }||'';
}

sub set_flag    {
	my $self = shift;
	my $val = shift;
	$self->{ '_flags' }->{ uc $val } = 1;
	return $self->{ '_flags' }->{ uc $val };
}

sub guard       {
    my $self = shift;
    return $self->{ '_guard' };
}

sub dbh	{
	my $self = shift;
    return $self->{ '_dbh' };
}

sub tr_name	{
    my $self = shift;
    my $val = shift;
	
	require Encode;
	Encode::from_to( $val, 'UTF-8', 'KOI8-U');
	$val =~ tr/\x80-\xFF/\x00-\x7F/;

    #$val =~ tr/АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯІЇЄ/ABVGDEEZZIIKLMNOPRSTUFHCCSS\-I\-EUAIIE/;
    #$val =~ tr/абвгдеёжзийклмнопрстуфхцчшщъыьэюяіїє/abvgdeezziiklmnoprstufhccss\-i\-euaiie/;

    return $val;
}

sub strip_html	{
	my $self = shift;
	my $v = shift;
	$v =~ s/<[a-zA-Z\/][^>]*>//g;
	return $v;
}

return 1;

