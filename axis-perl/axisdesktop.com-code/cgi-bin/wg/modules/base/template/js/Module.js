Ext.app.Module = Ext.extend(Ext.util.Observable, {
	constructor : function(config){
      this.addEvents({
         'actioncomplete': true
      });

      config = config || {};
      Ext.apply(this, config);
      Ext.app.Module.superclass.constructor.call(this);  
   },
   locale: null,
   l10n: null,
   launcher: null,
   loaded: false,
   isLoading: false,
   silent: false,
   type: null,
   id: null,
   init : Ext.emptyFn,
   createWindow : Ext.emptyFn,
   setLocale : Ext.emptyFn,
   handleRequest : Ext.emptyFn,
   tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    }
}); 