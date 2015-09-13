#!/usr/bin/perl 

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use CGI;
use HTML::Template::Pro;
use HellFire::Configuration::CategoryDAO;
use HellFire::Guard;
use HellFire::DataBase;
use HellFire::Config;
use JSON;
use HellFire::Response;

my $INI = new HellFire::Config();

my $B = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;


my $lang_id = $G->get_lang_id();

my $tpl_file;
if( $G->is_signed_in() )	{
	$tpl_file = $INI->home_dir().$INI->modules_dir()."/base/template/index.html";
}
else	{
	$tpl_file = $INI->home_dir().$INI->modules_dir()."/base/template/login.html";
}

my $t = HTML::Template::Pro->new		( 
	'die_on_bad_params' => 0,			
	'loop_context_vars' => 1,			
	filename => $tpl_file 
	);


my @desktop_modules;
my @desktop_shortcut;

my $C = new HellFire::Configuration::CategoryDAO( $dbh, $G );
my $store_modules = $C->get_store_modules();

foreach( @$store_modules )	{
	push @desktop_modules, {
		id => 'store-'.$_->get_name(),
		type => 'store/'.$_->get_name(),
		className => 'AxisDesktop.'.$_->get_name().'Module',
		launcher => {
			iconCls => $_->get_name().'-main-window',
			shortcutIconCls => $_->get_name().'-desktop-shortcut',
			text => 'moduleShortcutText',
			tooltip => 'moduleShortcutToolTip'
		},
		launcherPaths => {
			contextmenu => '/',
#			startmenutool => '/',
			startmenu => '/store/'
		}
	};
	
	push @desktop_shortcut, 'store-'.$_->get_name(); 
}

my $tool_modules = $C->get_tool_modules();

foreach( @$tool_modules )	{
	push @desktop_modules, {
		id => 'tool-'.$_->get_name(),
		type => 'tool/'.$_->get_name(),
		className => 'AxisDesktop.'.$_->get_name().'Module',
		launcher => {
			iconCls => $_->get_name().'-main-window',
			shortcutIconCls => $_->get_name().'-desktop-shortcut',
			text => 'moduleShortcutText',
			tooltip => 'moduleShortcutToolTip'
		},
		launcherPaths => {
			startmenutool => '/'
		}
	};
}

my $desktop_user = {
      name => $G->session->param('user_name'),
      group => 'Demo'
};

my $desktop_appearance = {
	fontColor => 'ffffff',
	taskbarTransparency => '100',
	theme => {
		id => 1,
		name => 'Blue',
		file => '/res/themes/xtheme-blue.css'
	}
};

my $desktop_background = {
	color => '3d71b8',
	wallpaperPosition => 'center',
	wallpaper => {
		id => 11,
		name => 'qWikiOffice',
		file => '/res/wallpapers/bluewawes.jpg'
	}
};

my $desktop_launchers = {
	autorun => [],
	quickstart => ["store-configuration"],
	shortcut => \@desktop_shortcut
};

my $desktop_taskbar = {
	buttonScale => 'large',
	position          => 'bottom',
	quickstartConfig  => { width => 120 },
	startButtonConfig => {
		iconCls => 'icon-qwikioffice',
		text    => 'baseStartButtonText'
	},
	startMenuConfig => {
		iconCls => 'icon-user-16',
		title   => $G->session->param( 'user_name' ),
		width   => 320
	}
};


my $cat = $C->get_all_siblings(); 
my @configuration;
foreach( @$cat )	{
    my $h = {
	title => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),
	alias => ( $_->get_alias( $lang_id ) ) ? $_->get_alias( $lang_id ) : $_->get_name(),
	border => 0,
	iconCls => 'nav',
	items => '['.$_->get_name().'TreeToolBar,'. $_->get_name().'Tree]',
	id => 'configuration_'.$_->get_name(),
	prefix => $_->get_name(),
	script_dir => $INI->script_dir(), 
	modules_dir => $INI->modules_dir(),
	lang_name => $G->get_lang_name() 
    };
    push @configuration, $h;
}

my $J = new JSON;
my $query = 'select name, value from user_session_state where user_id = ?';
my $sth = $dbh->prepare( $query );
$sth->execute( $G->get_user_id() );
my @ses;
while( my $h = $sth->fetchrow_hashref() )	{
	push @ses, $h;
}

my $config = {
	init => 'function(){
      Ext.BLANK_IMAGE_URL = "/img/spacer.gif";
      Ext.QuickTips.init();',
	memberInfo => {
      name => $G->session->param('user_name'),
      group => 'Demo'
	},
	modules => \@desktop_modules,
	desktopConfig => {
		appearance => {
			fontColor => 'ffffff',
			taskbarTransparency => '100',
			theme => {
				id => 1,
				name => 'Blue',
				file => '/res/themes/xtheme-blue.css'
			}
	  },
      background => {
		color => '3d71b8',
		wallpaperPosition => 'center',
		wallpaper => {
			id => 11,
			name => 'qWikiOffice',
			file => '/res/wallpapers/qwikioffice.jpg'
		}
	  },

      taskbarConfig => {
         buttonScale => 'large',
         position => 'bottom',
         quickstartConfig => {
            width => 120
         },
         startButtonConfig => {
            iconCls => 'icon-qwikioffice',
            text => 'baseStartButonText'
         },
         startMenuConfig => {
            iconCls => 'icon-user-48',
            title => $G->session->param('user_name'),
            width => 320
         }
      }
   }
	 
};


$t->param(
	configuration_items =>  \@configuration,
	user_name => $G->session->param('user_name'),
	user_id => $G->session->param('user_id'),
	title => $INI->obj->{project}->{title},
	script_dir => $INI->script_dir(),
	modules_dir => $INI->modules_dir(),
	script      => $ENV{SCRIPT_NAME},
	lang_name      => $G->get_lang_name(),
	user_session_state => $J->encode( \@ses ),
	desktop_config => $J->encode( $config ),
	
	desktop_modules => $J->encode( \@desktop_modules ),
	desktop_user => $J->encode( $desktop_user ),
	desktop_appearance => $J->encode( $desktop_appearance ),
	desktop_background => $J->encode( $desktop_background ),
	desktop_launchers => $J->encode( $desktop_launchers ),
	desktop_taskbar => $J->encode( $desktop_taskbar ),
);

print $R->header();
print($t->output());

