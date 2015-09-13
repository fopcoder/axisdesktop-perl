
Ext.onReady(function(){
    Ext.EventManager.onWindowResize(centerPanel);
    var loginPanel = Ext.get("wg-login-panel");
    centerPanel();
    
    function centerPanel(){
        var xy = loginPanel.getAlignToXY(document, 'c-c');
        positionPanel(loginPanel, xy[0], xy[1]);
    }
    
    function positionPanel(el, x, y){
        if(x && typeof x[1] == 'number'){
            y = x[1];
            x = x[0];
        }
        el.pageX = x;
        el.pageY = y;
        
        if(x === undefined || y === undefined){ // cannot translate undefined points
            return;
        }
        
        if(y < 0){ y = 10; }
        
        var p = el.translatePoints(x, y);
        el.setLocation(p.left, p.top);
        return el;
    }
});
