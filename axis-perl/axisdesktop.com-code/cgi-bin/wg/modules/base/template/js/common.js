//<!--

function w(module,msg) {
    var txt;
    
    if( eval( 'typeof(' + module + 'Lang )' ) != 'undefined' )  {
        txt = eval( module + 'Lang["' + msg + '"]' );
        if( !txt ) {
            txt = msg
        }
    }
    else {
        txt = 'localization error!';
    }
    
    document.write( txt );
}

function W(id,module,msg) {
    var txt;
    
    if( eval( 'typeof(' + module + 'Lang )' ) != 'undefined' )  {
        txt = eval( module + 'Lang["' + msg + '"]' );
        if( !txt ) {
            txt = msg
        }
    }
    else {
        txt = 'localization error!';
    }
    
    document.getElementById( id ).value = txt;
}

function l(module,msg) {
    var txt;
    
    if( eval( 'typeof(' + module + 'Lang )' ) != 'undefined' )  {
        txt = eval( module + 'Lang["' + msg + '"]' );
        if( !txt ) {
            txt = msg
        }
    }
    else {
        txt = 'localization error!';
    }
    
    return txt;
}

//-->