package HellFire::Config;

use strict;
use FindBin;
use Config::Tiny;

sub new {
    my $class = shift;
	my $_p = shift||'';
    my $self = {};

    (my $path, my $script_dir ) = split( /cgi-bin/, $FindBin::RealBin, 2);
    #(my $path, my $script_dir ) = split( /cgi-bin/, $ENV{'SCRIPT_FILENAME'}, 2);
	$path = $_p if( $_p );

    if( -e "$path/.htconfig/config.ini" )	{
	$self->{_Config} = Config::Tiny->read( "$path/.htconfig/config.ini" );
    }
    elsif( -e "$path/../.htconfig/config.ini" )	{
	$self->{_Config} = Config::Tiny->read( "$path/../.htconfig/config.ini" );
    }
    elsif( -e "$path/htdocs/.htconfig/config.ini" )	{
	$self->{_Config} = Config::Tiny->read( "$path/htdocs/.htconfig/config.ini" );
    }
    else    {
	$self->{_Config} = Config::Tiny->new();
    }

    $self->{_Config}->{_}->{document_root} ||=  $ENV{DOCUMENT_ROOT} ;
	$self->{_Config}->{_}->{res_dir} = '/res';
	$self->{_Config}->{_}->{res_dir_abs} = $ENV{DOCUMENT_ROOT}.$self->{_Config}->{_}->{res_dir};
    $self->{_Config}->{_}->{home_dir} ||=  $path ;
    $self->{_Config}->{_}->{lib_dir} ||=  "$path/lib" ;
    $self->{_Config}->{_}->{conf_dir} ||=  "$path/.htconfig" ;
    $self->{_Config}->{_}->{template_dir} ||= "$path/.httemplate" ;
    $self->{_Config}->{_}->{script_dir} ||=  "/cgi-bin/$script_dir";
    $self->{_Config}->{_}->{modules_dir} ||=  "/cgi-bin/wg/modules";
    $self->{_Config}->{_}->{modules_dir_abs} ||= $path.$self->{_Config}->{_}->{modules_dir} ;
    $self->{_Config}->{_}->{store_dir_rel} ||=  "/file";
    $self->{_Config}->{_}->{store_dir} ||=  $self->{_Config}->{_}->{document_root}.$self->{_Config}->{_}->{store_dir_rel};
    $self->{_Config}->{_}->{fonts_dir} ||=  "$path/.fonts" ;
    $self->{_Config}->{_}->{project} ||=  'CMS AxisDesktop';

    $self->{_Config}->{session}->{tmp_dir} ||= "/tmp/axis/session";
    $self->{_Config}->{cache}->{tmp_dir} ||= "/tmp/axis/cache";

    bless $self, $class;
    return $self;
}

sub obj	{
    my $self = shift;
    return $self->{_Config};
}


sub session_tmp_dir	{
    my $self = shift;
    return $self->{_Config}->{session}->{tmp_dir};
}

sub cache_tmp_dir	{
    my $self = shift;
    return $self->{_Config}->{cache}->{tmp_dir};
}

sub document_root	{
    my $self = shift;
    return $self->{_Config}->{_}->{document_root};
}

sub home_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{home_dir};
}

sub fonts_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{fonts_dir};
}

sub lib_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{lib_dir};
}

sub conf_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{conf_dir};
}

sub template_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{template_dir};
}

sub script_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{script_dir};
}

sub modules_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{modules_dir};
}

sub modules_dir_abs	{
    my $self = shift;
    return $self->{_Config}->{_}->{modules_dir_abs};
}

sub store_dir	{
    my $self = shift;
    return $self->{_Config}->{_}->{store_dir};
}

sub store_dir_rel	{
    my $self = shift;
    return $self->{_Config}->{_}->{store_dir_rel};
}

sub res_dir	{
	my $self = shift;
	return $self->{_Config}->{_}->{res_dir};
}

sub res_dir_abs	{
	my $self = shift;
	return $self->{_Config}->{_}->{res_dir_abs};
}

sub version	{
    my $self = shift;
    return $self->{_Config}->{_}->{version};
}

sub write   {
    my $self = shift;
    my $path = shift ||'';
    $self->{_Config}->write($path);
}

return 1;
