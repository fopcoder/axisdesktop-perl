#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI;
use JSON;
use HellFire::DataBase;
use HellFire::DataType;
use HellFire::Guard;
use HellFire::Config;
use HellFire::Article::CategoryDAO;
use HellFire::Configuration::CategoryDAO;
use HellFire::User::CategoryDAO;
use HellFire::Response;

my $INI = new HellFire::Config();
my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;
my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;

my $action    = $q->param( 'action' ) || '';
my $parent_id = $q->param( 'pid' )    || 0;
my $id        = $q->param( 'id' )     || 0;

if( $action eq 'article_category_list' ) {
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );

	my $node = $q->param( 'node' ) || 0;
	my $lang_id = $G->get_lang_id();

	my $nodes = $C->get_all_siblings( $node );

	my @res;
	foreach ( @$nodes ) {
		push @res,
		  {
			id   => $_->get_id(),
			text => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),
			qtip => 'id: ' . $_->get_id().'<br>name: '.$_->get_name()
		  };
		unless( $_->get_children() ) {
			my @w;
			$res[-1]->{children} = \@w;
		}
	}

	my $J = new JSON;
	$G->header( -type => 'text/x-json; charset=utf-8' );
	print( $J->encode( \@res ) );

	exit 0;
}

if( $action eq 'article_category_move' && $q->param( 'src' ) && defined $q->param( 'dst' ) && $q->param( 'point' ) ) {
	my $J = new JSON;
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	$C->load( $q->param( 'src' ) );
	$C->move( $q->param( 'point' ), $q->param( 'dst' ) );

	my $o;
	$o->{success} = 1;

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_category_copy' && $q->param( 'id' ) ) {
	my $J = new JSON;
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	$C->load( $q->param( 'id' ) );
	$C->copy();

	my $o;
	$o->{success} = 1;

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_category_view' ) {
	require HellFire::DataType;
	my $J = new JSON;

	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	if( $q->param( 'add' ) ) {
		$C->set_parent_id( $id );
	}
	else {
		$C->load( $id );
	}

	my $hash = $C->to_template();

	my $CP = new HellFire::Article::CategoryDAO( $dbh, $G );
	$CP->load( $C->get_parent_id() );
	$hash->{parent_name}  = $CP->get_name() || '';

	my $T = new HellFire::DataType( $dbh );
	my $l = $T->get_languages();
	
	my $l10n = {
		xtype => 'tabpanel',
		activeTab => 0,
		width => '100%',
		autoHeight => 1,
		deferredRender => 0,
		forceLayout => 1,
		defaults => {
			bodyStyle => 'padding:10px',
			width => '100%'
		},
		items => []
	};

	foreach ( @$l ) {
		my $lang = {
			title => $_->{alias},
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
			value => $C->get_alias( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textfield',
			fieldLabel => 'labelTitle',
			name => 'title_'.$_->{id},
			value => $C->get_title( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textarea',
			fieldLabel => 'labelKeywords',
			height => 100,
			name => 'keywords_'.$_->{id},
			value => $C->get_keywords( $_->{id} )
		};
		
		push @{ $lang->{items}  }, {
			xtype => 'textarea',
			fieldLabel => 'labelDescription',
			height => 100,
			name => 'description_'.$_->{id},
			value => $C->get_description( $_->{id} )
		};
		
		push @{$l10n->{items}}, $lang;
	}
	
	$hash->{l10n} = $l10n;

	my @items_flags;

	my $ff = $B->get_set_values( 'article_categories', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags,
		  {
			xtype      => 'checkbox',
			fieldLabel => 'FLAG_'.$_,
			name       => 'article_flag',
			autoHeight => 1,
			checked    => $C->get_flag( $_ ),
			value      => $_,
			inputValue => $_
		  };
	}

	#my @items_l10n;

	#use HellFire::DataType;

	#foreach ( @$l ) {
	#	push @items_l10n,
	#	  {
	#		xtype      => 'textfield',
	#		fieldLabel => $_->{alias},
	#		name       => 'alias_' . $_->{id},
	#		autoHeight => 1,
	#		value      => $R->get_alias( $_->{id} ),
	#		inputValue => $R->get_alias( $_->{id} )
	#	  };
	#}

	#my $UC = new HellFire::Configuration::CategoryDAO( $dbh, $G );
	#my $act = $UC->get_actions( $UC->find( 'article_lib' ) );
	#
	#my @items_actions;
	#foreach ( @$act ) {
	#	push @items_actions, { name => $_->{name}, id => $_->{id} };
	#}

	$hash->{flags}   = \@items_flags;
	#$hash->{items_actions} = \@items_actions;

	$G->header( -type => "text/x-json; charset=utf-8" );
	print( $J->encode( $hash ) );
	exit 0;
}

if( $action eq 'article_category_access_list' ) {
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
    $C->load( $id );
    my $rows = $C->get_access_list();
    
    my $res;
	$res->{metaData} = {
		id => "id",
        root => "rows",
        totalProperty => "totalCount",
        successProperty => "success",
        fields => [
            { name => "group"},
			{ name => "group_id"},
			{ name => "action"},
            { name => "action_id"},
            { name => "value", type => "bool" }
        ],
        sortInfo => {
           field => 'action',
           direction => 'desc'
        }
	};
    $res->{totalCount} = scalar @$rows;
    $res->{rows} = $rows;

	my $J = new JSON;
	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_category_update' ) {
	my $J = new JSON;

	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	$C->load( $q->param( 'id' ) || 0 );
	#$C->set_parent_id( $q->param( 'parent_id' ) );
	#$C->set_name( $q->param( 'name' ) );
	#$C->set_ordering( $q->param( 'ordering' ) );
	#$C->set_id( $q->param( 'id' ) || 0 );
	#$C->set_group_access( $J->decode( $q->param( 'access' ) ) ) if( $C->get_id() );

	foreach my $i ( $q->param() ) {
		if( $i eq 'article_flag' ) {
			foreach ( $q->param( 'article_flag' ) ) {
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
			my $code = $J->decode( $q->param( 'json_access' ) );
			foreach my $j ( @$code ) {
				if( $j->{value} eq 'false' || $j->{value} == 0 ) {
					$dbh->do( 'delete from article_category_access where parent_id = ? and group_id = ? and action_id = ?', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
				if( $j->{value} eq 'true' || $j->{value} > 0 ) {
					$dbh->do( 'insert ignore into article_category_access(parent_id,group_id,action_id) values(?,?,?)', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
			}
		}
		else {
			my $sf = "set_$i";
			$C->$sf( $q->param( $i ) ) if( $C->can( $sf) );
		}
	}

	#foreach ( $q->param( 'article_flag' ) ) {
	#	next if( $_ eq 'DELETED' );
	#	$C->set_flag( $_ );
	#}

	$C->save();

	if( $q->param( 'raccess_category' ) ) {
		my $cc = $C->get_all_children();
		push @$cc, $C;
		foreach my $i ( reverse @$cc ) {
			if( $C->get_id() != $i->get_id() ) {
				$i->clear_access();
				$i->set_access();
			}
			if( $q->param( 'raccess_field' ) ) {
				require HellFire::Article::FieldDAO;
				my $F = new HellFire::Article::FieldDAO( $dbh, $G );
				$F->set_parent_id( $i->get_id() );
				my $ff = $F->get_fields();
				foreach my $j ( @$ff ) {
					$j->clear_access();
					$j->set_access();
				}
			}
			if( $q->param( 'raccess_item' ) ) {
				require HellFire::Article::ItemDAO;
				my $I = new HellFire::Article::ItemDAO( $dbh, $G );
				my $ii = $I->get_all_siblings( $i->get_id() );
				foreach my $j ( @$ii ) {
					$j->clear_access();
					$j->set_access();
				}
			}
		}
	}

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_category_delete' ) {
	my $J = new JSON;
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	$C->load( $q->param( 'id' ) );

	$C->destroy();

	my $o;
	$o->{success} = 'true';

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'article_category_flat' ) {
	my $J = new JSON;
	my $C = new HellFire::Article::CategoryDAO( $dbh, $G );
	my @arr;

	$C->get_flat_references( 0, '', \@arr );

	$G->header( -type => "text/x-json;charset=utf-8" );
	print( $J->encode( \@arr ) );
	exit 0;
}

my $J = new JSON;
$G->header( $J->encode( { succes => 0 } ) );
exit 0;

