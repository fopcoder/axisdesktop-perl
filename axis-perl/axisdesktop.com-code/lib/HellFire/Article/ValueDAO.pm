package HellFire::Article::ValueDAO;

use strict;
use base qw(HellFire);

sub new {
    my $class = shift;
    my $dbh = shift;
    my $G = shift;

    my $self = $class->SUPER::new();

    $self->{ '_dbh' } = $dbh;
    $self->{ '_guard' } = $G;
    $self->{ '_type' } = undef;
    $self->{ '_values' } = {};

    bless $self, $class;
    return $self;
}

sub get_item_id	{
    my $self = shift;
    return $self->{ '_item_id' }||0;
}

sub set_item_id	{
    my $self = shift;
    $self->{ '_item_id' } = shift;
    return $self->{ '_item_id' };
}

sub get_type	{
    my $self = shift;
    return $self->{ '_type' }||'';
}

sub set_type	{
    my $self = shift;
    $self->{ '_type' } = shift;
    return $self->{ '_type' };
}

sub get_type_id	{
    my $self = shift;
    return $self->{ '_type_id' }||0;
}

sub set_type_id	{
    my $self = shift;
    $self->{ '_type_id' } = shift;
    return $self->{ '_type_id' };
}

sub get_value    {
    my $self = shift;
    my @a = values %{$self->{ '_values' }};
    return \@a;
}

sub get_value_id    {
    my $self = shift;
    my @a = keys %{$self->{ '_values' }};
    return \@a;
}

sub set_value    {
    my $self = shift;
    my $val = shift;
    my $i = shift||0;

    unless( $i )    {
	my @a = sort keys %{$self->{ '_values' }};
	$i = pop @a;
	$i++;	
    }

    $self->{ '_values' }->{ $i } = $val;

    my @a =  values %{$self->{ '_values' }} ;
    return \@a;
}

sub load    {
    my $self = shift;
	my @obj = @_;

    if( ref $obj[0] eq 'HellFire::Article::FieldDAO' && ref $obj[1] eq 'HellFire::Article::ItemDAO'  )	{
	if( $obj[0]->get_type_id() && $obj[1]->get_id() && $obj[0]->get_id() )	{
	    my $sth = $self->dbh->prepare( 'call article_value_load(?,?,?,?,@c,@w);');
	    $sth->execute( $obj[0]->get_id(), $obj[1]->get_id(), $obj[0]->get_type_id(), $self->guard->get_lang_id()) ;
	    while( my $h = $sth->fetchrow_hashref() )	{
		    $self->set_value( $h->{ 'value' }, $h->{ 'id' } );
	    }

	    $self->set_type( $obj[0]->get_type() );
	    $self->set_type_id( $obj[0]->get_type_id() );
	    $self->set_item_id( $obj[1]->get_id() );
	    $self->set_parent_id( $obj[0]->get_id() );

	    return 1;
	}
    }
    elsif( $self->get_type_id() && $self->get_item_id() && $self->get_parent_id() )	{	
	my $sth = $self->dbh->prepare( 'call article_value_load(?,?,?,?,@c,@w);');
	$sth->execute( $self->get_parent_id(), $self->get_item_id(), $self->get_type_id(), $self->guard->get_lang_id()) ;
	while( my $h = $sth->fetchrow_hashref() )	{
	    $self->set_value( $h->{ 'value' }, $h->{ 'id' } );
	}

	return 1;
    }

    return undef;
}

sub save	{
    my $self = shift;
    $self->add();
}

sub add	{
    my $self = shift;
    my $type = $self->get_type();

    if( $self->get_parent_id() && $self->get_item_id() && $type )	{
	$self->destroy();		

	my $query = "insert into article_values_$type( parent_id, item_id, value ) values(?,?,?)";
	foreach( @{$self->get_value()} )	{
	    $self->dbh->do( $query, undef, $self->get_parent_id(), $self->get_item_id(), $_ );	
	}
	return 1;	
    } 
}

sub destroy	{
    my $self = shift;
    my $type = $self->get_type();

    if( $self->get_parent_id() && $self->get_item_id() && $type )	{
	my $query = "delete from article_values_$type where item_id = ? and parent_id = ? ";
	$self->dbh->do( $query, undef, $self->get_item_id(), $self->get_parent_id() ) ;	

	return 1;	
    } 

    return undef;
}

sub undef_value	{
    my $self = shift;
    $self->{ '_values' } = undef;
}

sub to_string     {
    my $self = shift;

    my @arr = values %{$self->{'_values'}};
    return join(',', @arr);
}

return 1;
