package CGI::Session_M::ID::md5;

use strict;
use Digest::MD5;
use CGI::Session_M::ErrorHandler;

@CGI::Session_M::ID::md5::ISA     = qw( CGI::Session_M::ErrorHandler );

*generate = \&generate_id;
sub generate_id {
    my $md5 = new Digest::MD5();
    $md5->add($$ , time() , rand(time) );
    return $md5->hexdigest();
}


1;

