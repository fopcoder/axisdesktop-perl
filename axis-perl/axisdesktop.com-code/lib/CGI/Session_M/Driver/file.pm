package CGI::Session_M::Driver::file;

use strict;

#use Carp;
use File::Spec;
use Fcntl qw( :DEFAULT :flock :mode );
use CGI::Session_M::Driver;
use vars qw( $FileName $NoFlock $UMask $NO_FOLLOW );

BEGIN {
    # keep historical behavior

    no strict 'refs';
    
    *FileName = \$CGI::Session_M::File::FileName;
}

@CGI::Session_M::Driver::file::ISA        = ( "CGI::Session_M::Driver" );
$FileName                               = "cgisess_%s";
$NoFlock                                = 0;
$UMask                                  = 0660;
$NO_FOLLOW                              = eval { O_NOFOLLOW } || 0;

sub init {
    my $self = shift;
    $self->{Directory} ||= File::Spec->tmpdir();

    unless ( -d $self->{Directory} ) {
        require File::Path;
        unless ( File::Path::mkpath($self->{Directory}) ) {
            return $self->set_error( "init(): couldn't create directory path: $!" );
        }
    }
    
    $self->{NoFlock} = $NoFlock unless exists $self->{NoFlock};
    $self->{UMask} = $UMask unless exists $self->{UMask};
    
    return 1;
}

sub _file {
    my ($self,$sid) = @_;
    my $id = $sid;
    $id =~ s|\\|/|g;

	if ($id =~ m|/|)
    {
        return $self->set_error( "_file(): Session ids cannot contain \\ or / chars: $sid" );
    }

    return File::Spec->catfile($self->{Directory}, sprintf( $FileName, $sid ));
}

sub retrieve {
    my $self = shift;
    my ($sid) = @_;

    my $path = $self->_file($sid);
    
    return 0 unless -e $path;

    # make certain our filehandle goes away when we fall out of scope
    local *FH;

    if (-l $path) {
        unlink($path) or 
          return $self->set_error("retrieve(): '$path' appears to be a symlink and I couldn't remove it: $!");
        return 0; # we deleted this so we have no hope of getting back anything
    }
    sysopen(FH, $path, O_RDONLY | $NO_FOLLOW ) || return $self->set_error( "retrieve(): couldn't open '$path': $!" );
    
    $self->{NoFlock} || flock(FH, LOCK_SH) or return $self->set_error( "retrieve(): couldn't lock '$path': $!" );

    my $rv = "";
    while ( <FH> ) {
        $rv .= $_;
    }
    close(FH);
    return $rv;
}



sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    
    my $path = $self->_file($sid);
    
    # make certain our filehandle goes away when we fall out of scope
    local *FH;
    
    my $mode = O_WRONLY|$NO_FOLLOW;
    
    # kill symlinks when we spot them
    if (-l $path) {
        unlink($path) or 
          return $self->set_error("store(): '$path' appears to be a symlink and I couldn't remove it: $!");
    }
    
    $mode = O_RDWR|O_CREAT|O_EXCL unless -e $path;
    
    sysopen(FH, $path, $mode, $self->{UMask}) or return $self->set_error( "store(): couldn't open '$path': $!" );
    
    # sanity check to make certain we're still ok
    if (-l $path) {
        return $self->set_error("store(): '$path' is a symlink, check for malicious processes");
    }
    
    # prevent race condition (RT#17949)
    $self->{NoFlock} || flock(FH, LOCK_EX)  or return $self->set_error( "store(): couldn't lock '$path': $!" );
    truncate(FH, 0)  or return $self->set_error( "store(): couldn't truncate '$path': $!" );
    
    print FH $datastr;
    close(FH)               or return $self->set_error( "store(): couldn't close '$path': $!" );
    return 1;
}


sub remove {
    my $self  = shift;
    my ($sid) = @_;
    my $path  = $self -> _file($sid);
    unlink($path) or return $self->set_error( "remove(): couldn't unlink '$path': $!" );
    return 1;
}


sub traverse {
    my $self = shift;
    my ($coderef) = @_;

    unless ( $coderef && ref($coderef) && (ref $coderef eq 'CODE') ) {
        die "traverse(): usage error";
    }

    opendir( DIRHANDLE, $self->{Directory} ) 
        or return $self->set_error( "traverse(): couldn't open $self->{Directory}, " . $! );

    my $filename_pattern = $FileName;
    $filename_pattern =~ s/\./\\./g;
    $filename_pattern =~ s/\%s/(\.\+)/g;
    while ( my $filename = readdir(DIRHANDLE) ) {
        next if $filename =~ m/^\.\.?$/;
        my $full_path = File::Spec->catfile($self->{Directory}, $filename);
        my $mode = (stat($full_path))[2] 
            or return $self->set_error( "traverse(): stat failed for $full_path: " . $! );
        next if S_ISDIR($mode);
        if ( $filename =~ /^$filename_pattern$/ ) {
            $coderef->($1);
        }
    }
    closedir( DIRHANDLE );
    return 1;
}


sub DESTROY {
    my $self = shift;
}

1;

