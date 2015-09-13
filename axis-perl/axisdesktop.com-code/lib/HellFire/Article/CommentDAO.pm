package HellFire::Article::CommentDAO;

use strict;
use base qw(HellFire::Object);

sub new {
    my $class = shift;
    my $dbh = shift;
    my $G = shift;

    my $self = $class->SUPER::new();
    $self->{ '_dbh' } = $dbh;
    $self->{ '_guard' } = $G;

    bless $self, $class;
    return $self;
}

sub dbh	{
    my $self = shift;
    return $self->{ '_dbh' }; 
}

sub guard	{
    my $self = shift;
    return $self->{ '_guard' };
}	

sub get_subject	{
    my $self = shift;
    return $self->{ '_subject' }||'';
}

sub set_subject	{
    my $self = shift;
    $self->{ '_subject' } = shift;

    return $self->{ '_subject' };
}

sub get_comment	{
    my $self = shift;
    return $self->{ '_comment' }||'';
}

sub set_comment	{
    my $self = shift;
    $self->{ '_comment' } = shift;

    return $self->{ '_comment' };
}

sub get_user_id	{
    my $self = shift;
    return $self->{ '_user_id' }||'';
}

sub set_user_id	{
    my $self = shift;
    $self->{ '_user_id' } = shift;

    return $self->{ '_user_id' };
}

sub get_ip	{
    my $self = shift;
    return $self->{ '_ip' }||'';
}

sub set_ip	{
    my $self = shift;
    $self->{ '_ip' } = shift;

    return $self->{ '_ip' };
}

sub load    {
    my $self = shift;
    my $id = shift || $self->get_id() || 0;

    $self->set_id( $id );

    my $query = 'select c.*, t.name, t.subject, t.comment 
	from article_item_comments c left join article_item_comment_text t on t.parent_id = c.id
	where id = ?';
    my $h = $self->{ '_dbh' }->selectrow_hashref( $query, undef, $id );
    foreach my $i ( keys %$h )	{
	my $e = '$self->set_'.$i.'("'.$h->{$i}.'")';
	eval($e);
    } 

    return 1;
}

sub save	{
    my $self = shift;

    if( $self->get_id() )   {
	$self->update();
    }
    else    {
	$self->set_id( $self->add() );
    }
}


sub add	{
    my $self = shift;

    my $query = 'insert into article_item_comments( parent_id, user_id, inserted, ip )
	values(?,?,now(),?)';
    $self->dbh->do( $query, undef, $self->get_parent_id(), $self->get_user_id(), $self->get_ip );	
    my $id = $self->dbh->last_insert_id(undef,undef,undef,undef);

    $query = 'insert into article_item_comment_text( parent_id, name, subject, comment)
	values(?,?,?,?)';
    $self->dbh->do( $query, undef, $id, $self->get_name(), $self->get_subject(), $self->get_comment() );

    return $id;	
}

sub update	{
    my $self = shift;

    require HellFire::DataType;

    my $C = new HellFire::Article::CategoryDAO( $self->dbh );
    $C->load( $self->get_parent_id() );

    $self->validate_name();
    my $sys = $C->is_system();

    if(  $self->get_name() && !$sys )	{
	return 1;	
    } 

    return undef;
}

sub destroy      {
    my $self = shift;
    my $params = shift;

    require HellFire::Article::ItemDAO;
    if( $self->get_id() && !$self->is_system()  )    {
	my $ac = $self->get_all_children();
	push @$ac, $self;


    }
    else    {
	warn('delete_item: item not found');
    }
}


sub get_comments	{
    my $self = shift;
    my $params = shift;

    my $per_page = $params->{per_page}||25;
    my $page = $params->{page}||0;
    my $offset = $page*$per_page;
    my $pid = $params->{parent_id}||0;

    my $query;
    if( $pid )	{
	$query = 'select c.id from article_item_comments c inner join article_item_comment_text t 
	    on t.parent_id = c.id and c.parent_id = ? order by c.id desc limit ?,?';
    }
    else    {
	$query = 'select c.id from article_item_comments c inner join article_item_comment_text t 
	    on t.parent_id = c.id and c.parent_id > ? order by c.id desc limit ?,?';
    }

    my @ret;
    my $sth = $self->dbh->prepare( $query );
    $sth->execute( $pid, $page*$per_page, $per_page );

    while( my $h = $sth->fetchrow_array ) {
	my $C = new HellFire::Article::CommentDAO( $self->dbh, $self->guard );
	$C->load( $h );
	push @ret, $C;
    }

    return \@ret;
}

sub get_inserted    {
    my $self = shift;
    return $self->{_inserted};
}

sub set_inserted    {
    my $self = shift;
    $self->{_inserted} = shift;
    return $self->{_inserted};
}

return 1;
