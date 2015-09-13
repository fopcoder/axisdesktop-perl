#!/usr/bin/perl

use strict;
use JSON;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use HellFire::Site::CategoryDAO;

my $A = new MyAction();
$A->run();
$A->finish();

exit 0;


package MyAction;
use base qw(CGI::AppJSON);

sub site_categories_list_action {
	require HellFire::Configuration::CategoryDAO;
	my $self = shift;
	
	my $dbh = $self->dbh;
	my $G = $self->guard;
	my $q = $self->q;
	
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );

	my $id = $q->param( 'node' ) || 0;
	my $lang_id = $G->get_lang_id();
	my $nodes = $C->get_all_siblings( $id );

	my @res;
	my @uu;
	my %cf;

	foreach ( @$nodes ) {
		my $name;
		my $Co = new HellFire::Configuration::CategoryDAO( $dbh, $G );
		my $params;
		if( $Co->load( $_->get_handler_id() ) ) {
			eval '$params='.$_->get_config();
			if( $params->{parent_id} ) {
				if( $Co->get_name() eq 'reference_page' && eval( 'require HellFire::Reference::CategoryDAO;' ) ) {
					my $I = new HellFire::Reference::CategoryDAO( $dbh, $G );
					$I->load( $params->{parent_id} );
					$name = $I->get_alias( $G->get_lang_id ) || $I->get_name();
				}
				elsif( $Co->get_name() eq 'article_page' && eval( 'require HellFire::Article::CategoryDAO;' ) ) {
					my $I = new HellFire::Article::CategoryDAO( $dbh, $G );
					$I->load( $params->{parent_id} );
					$name = $I->get_alias( $G->get_lang_id ) || $I->get_name();
				}
			}
		}
		my $c = $_->get_children();
		push @res, {
			id   => $_->get_id(),
			text => $_->get_name(),
			qtip => 'id: ' . $_->get_id(),

			#children => \@uu,
			expanded => 1,

			#leaf => ( $_->get_children() ) ? 0 : 1,
		};

		$res[-1]->{qtip} .= '<br>' . $_->get_alias( $lang_id );
		$res[-1]->{qtip} .= '<br>' . ( $Co->get_alias( $G->get_lang_id() ) || $Co->get_name() );

		if( $name ) {
			$res[-1]->{qtip} .= '->' . $name;
		}

		$res[-1]->{children} = \@uu unless( $c );

		#$res[-1]->{ expandable } = 0 unless( $c );
	}

	$self->obj( \@res );
}

sub site_category_view_action {
	require HellFire::User::ItemDAO;
	require HellFire::Configuration::ItemDAO;
	require HellFire::DataType;
	
	my $self = shift;
	my $dbh = $self->dbh;
	my $G = $self->guard;
	my $q = $self->q;
	my $parent_id = $q->param( 'pid' ) || 0;
	my $id = $q->param( 'id' ) || 0;
	
	
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );
	if( $q->param( 'add' ) ) {
		$C->set_parent_id( $id );
	}
	else {
		$C->load( $id );
	}

	my $res = $C->to_template();
	
	my $U = new HellFire::User::ItemDAO( $dbh, $G );
	$U->load( $C->get_user_id() );
	$res->{owner} = $U->get_name()||$U->get_name();
	
	my $CO = new HellFire::Configuration::ItemDAO( $dbh, $G );
	$CO->load( $C->get_handler_id() );
	$res->{handler_alias} = $CO->get_alias( $G->get_lang_id() ) || $CO->get_name() ;
	
	my $CP = new HellFire::Site::CategoryDAO( $dbh, $G );
	$CP->load( $C->get_parent_id() );
	$res->{parent_name}  = $CP->get_name() || '';

	my $T = new HellFire::DataType( $dbh );
	my $l = $T->get_languages();
	
	my $l10n = [];

	foreach ( @$l ) {
		my $lang = {
			title => $_->{alias},
			itemId => $_->{name},
			layout => 'form',
			autoHeight => 1,
			defaults => {
				width => '100%',
				bodyStyle => 'border:0'
			},
			items => []
		};
		
		push @{ $lang->{items} }, {
			xtype => 'textfield',
			fieldLabel => 'labelAlias',
			name => 'alias_'.$_->{id},
			itemId => 'alias',
			value => $C->get_alias( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textfield',
			fieldLabel => 'labelTitle',
			name => 'title_'.$_->{id},
			itemId => 'title',
			value => $C->get_title( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textarea',
			fieldLabel => 'labelKeywords',
			height => 100,
			itemId => 'keywords',
			name => 'keywords_'.$_->{id},
			value => $C->get_keywords( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textarea',
			fieldLabel => 'labelDescription',
			height => 100,
			itemId => 'description',
			name => 'description_'.$_->{id},
			value => $C->get_description( $_->{id} )
		};
		
		push @$l10n, $lang;
	}
	
	$res->{l10n} = $l10n;

	my @items_flags;

	my $ff = $self->db->get_set_values( 'site_categories', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags,
		  {
			fieldLabel => 'FLAG_'.$_,
			checked    => $C->get_flag( $_ )||0,
			value      => $_
		  };
	}

	$res->{flags} = \@items_flags;
	
	my $rows = $C->get_access_list();
    $res->{access}->{totalCount} = scalar @$rows;
    $res->{access}->{rows} = $rows;

	$self->obj( $res );
}

sub site_category_update_action {
	my $self = shift;
	my $dbh = $self->dbh;
	my $G = $self->guard;
	my $q = $self->q;
	my $parent_id = $q->param( 'pid' ) || 0;
	my $id = $q->param( 'id' ) || 0;
	
	my $C = new HellFire::Site::CategoryDAO( $dbh, $G );
	$C->load( $q->param( 'id' ) );

	foreach my $i ( $q->param() ) {
		if( $i eq 'flags' ) {
			foreach ( $q->param( 'flags' ) ) {
				$C->set_flag( $_ );
			}
		}
		elsif( $i =~ /alias_(\d+)/ ) {
			$C->set_alias( $1, $q->param( $i ) );
		}
		elsif( $i =~ /title_(\d+)/ ) {
			$C->set_title( $1, $q->param( $i ) );
		}
		elsif( $i =~ /keywords_(\d+)/ ) {
			$C->set_keywords( $1, $q->param( $i ) );
		}
		elsif( $i =~ /description_(\d+)/ ) {
			$C->set_description( $1, $q->param( $i ) );
		}
		elsif( $i =~ /json_access/ ) {
			my $code = $self->json->decode( $q->param( 'json_access' ) );
			foreach my $j ( @$code ) {
				if( $j->{value} eq 'false' || $j->{value} == 0 ) {
					$dbh->do( 'delete from site_category_access where parent_id = ? and group_id = ? and action_id = ?', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
				if( $j->{value} eq 'true' || $j->{value} > 0 ) {
					$dbh->do( 'insert ignore into site_category_access(parent_id,group_id,action_id) values(?,?,?)', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
			}
		}
		else {
			my $sf = "set_$i";
			$C->$sf( $q->param( $i ) ) if( $C->can( $sf) );
		}
	}

	$C->save();
	my $id = $C->get_id();

	$C->refresh_index();

	$self->obj( { success => 1 } );
}

sub site_category_move_action	{
	my $self = shift;
	my $dbh = $self->dbh;
	my $G = $self->guard;
	my $q = $self->q;
	my $id = $q->param( 'id' ) || 0;
	
	if( $q->param( 'src' ) && defined $q->param( 'dst' ) && $q->param( 'point' ) ) {
		my $C = new HellFire::Site::CategoryDAO( $dbh, $G );
		$C->load( $q->param( 'src' ) );
		$C->move( $q->param( 'point' ), $q->param( 'dst' ) );
	
		$self->obj( { success => 1 } );
	}
	else	{
		$self->obj( { failure => 1 } );		
	}
}

sub site_category_delete_action	{
	my $self = shift;
	
	if( $self->q->param( 'id' ) ) {
		my $C = new HellFire::Site::CategoryDAO( $self->dbh, $self->guard );
		$C->load( $self->q->param( 'id' ) );
		$C->destroy();
	
		$self->obj( { success => 1 } );
	}
	else	{
		$self->obj( { failure => 1 } );		
	}
}


1;
