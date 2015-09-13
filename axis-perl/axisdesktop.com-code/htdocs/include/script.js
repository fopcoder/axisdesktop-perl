var gtalk_win = null;
var mail_win = null;
function open_gtalk_chat() {
  if( !gtalk_win || gtalk_win.closed ) {
    gtalk_win = window.open('http://www.google.com/talk/service/badge/Start?tk=z01q6amlqfu2u0dovvdfp2s02om3c5nkodk6p59ib8g3st8hp2ugs3uai0sk57ue2f8h6hr2kka0bpd9q4vai13491q0av56fcke9n6d8m21g0cth9ar58pgmbi1que20besnm77j5mk8bg3jfvsro4k6k8p5nngq3bk8q6qom0ig71v9v7or1p83dl1dfa5jl8',
'gtalk_chat', 'height=400,width=300,modal=yes,alwaysRaised=yes,status=no,location=no');
  }
  else {
    gtalk_win.focus();
  }
}
function open_mail_win() {
  if( !mail_win || mail_win.closed ) {
    mail_win = window.open('/form','mail_win', 'height=300,width=420,modal=yes,alwaysRaised=yes,status=no,location=no');
  }
  else {
    mail_win.focus();
  }
}
