Ext.app.App = function(config){
   Ext.apply(this, config);

   this.addEvents({
      'ready': true,
      'beforeunload': true,
      'moduleactioncomplete': true
   });

   Ext.onReady(this.initApp, this);
};

Ext.extend(Ext.app.App, Ext.util.Observable, {
   desktopConfig: null,
   memberInfo: null,
   modules: null,
   plugins: null,
   isReady: false,
   connection: '/cgi-bin/wg/index.cgi',
   requestQueue: [],
   init: Ext.emptyFn,
   initApp : function(){
      this.init();
      this.preventBackspace();

      this.desktop = new Ext.Desktop(Ext.applyIf({
         app: this
      }, this.desktopConfig));

      if(this.plugins){
         if(Ext.isArray(this.plugins)){
            for(var i = 0, len = this.plugins.length; i < len; i++){
               this.plugins[i] = this.initPlugin(this.plugins[i]);
            }
         }else{
            this.plugins = this.initPlugin(this.plugins);
         }
      }

      Ext.EventManager.on(window, 'beforeunload', this.onBeforeUnload, this);
      this.fireEvent('ready', this);
      this.isReady = true;
   },
   initPlugin : function(p){
      if(p.ptype && !Ext.isFunction(p.init)){
         p = Ext.ComponentMgr.createPlugin(p);
      }else if(Ext.isString(p)){
         p = Ext.ComponentMgr.createPlugin({
            ptype: p
         });
      }
      p.init(this);
      return p;
   },
   requestModule : function(v, cb, scope){
      var m = this.getModule(v);
      if(m){
         if(m.loaded === true){
            cb.call(scope, m);
         }else{
            if(cb && scope){
               this.requestQueue.push({ id: m.id, callback: cb, scope: scope });
               this.loadModule(m);
            }
         }
      }
   },
   loadModule : function(m){
      if(m.isLoading){ return false; }
    	var id = m.id;
    	var moduleName = m.launcher.text;
//    	var notifyWin = this.desktop.showNotification({
//			html: 'Loading ' + moduleName + '...'
//			, title: 'Please wait'
//		});
		
		m.isLoading = true;
  
    	this.loadModuleComplete(true, id);
//    	Ext.Ajax.request({
//    		url: this.connection,
//    		params: {
//            service: 'load',
//    			moduleId: id
//    		},
//    		success: function(o){
//    			notifyWin.setIconClass('x-icon-done');
//				notifyWin.setTitle('Finished');
//				notifyWin.setMessage(moduleName + ' loaded.');
//				this.desktop.hideNotification(notifyWin);
//				notifyWin = null;
//		
//    			if(o.responseText !== ''){
//               eval(o.responseText);
//    				this.loadModuleComplete(true, id);
//    			}else{
//    				alert('An error occured on the server.');
//    			}
//    		},
//    		failure: function(){
//    			alert('Connection to the server failed!');
//    		},
//    		scope: this
//    	});

      return true;
    },
    loadModuleComplete : function(success, id){
    	if(success === true && id){
    		var m = this.instantiateModule(id);

         if(m){
            m.isLoading = false;
            m.loaded = true;
            m.init();
            m.on('actioncomplete', this.onModuleActionComplete, this);

            var q = this.requestQueue;
            var nq = [];
            var found = false;

            for(var i = 0, len = q.length; i < len; i++){
               if(found === false && q[i].id === id){
                  found = q[i];
               }else{
                  nq.push(q[i]);
               }
            }

            this.requestQueue = nq;

            if(found){
               found.callback.call(found.scope, m);
            }
         }
      }
   },
   instantiateModule : function(id){
      var p = this.getModule(id); // get the placeholder

    	if(p && p.loaded === false){
         if( eval('typeof ' + p.className) === 'function'){
	    		var m = eval('new ' + p.className + '()');
				m.app = this;

				var ms = this.modules;
				for(var i = 0, len = ms.length; i < len; i++){ // replace the placeholder with the module
					if(ms[i].id === m.id){
						Ext.apply(m, ms[i]); // transfer launcher properties
						ms[i] = m;
					}
				}

				return m;
    		}
      }
      return null;
   },
   getModule : function(v){
      var ms = this.modules;

      for(var i = 0, len = ms.length; i < len; i++){
         if(ms[i].id == v || ms[i].moduleType == v){
            return ms[i];
         }
      }

      return null;
   },
   registerModule: function(m){
    	if(!m){ return false; }
		this.modules.push(m);
		m.launcher.handler = this.desktop.launchWindow.createDelegate(this.desktop, [m.id]);
		m.app = this;
      return true;
   },
   makeRequest : function(id, requests){
      if(id !== '' && requests){
         var m = this.requestModule(id, function(m){
            if(m){
               m.handleRequest(requests);
            }
         }, this);
      }
   },
   getDesktop : function(){
      return this.desktop;
   },
   onReady : function(fn, scope){
      if(!this.isReady){
         this.on('ready', fn, scope);
      }else{
         fn.call(scope, this);
      }
   },
   onBeforeUnload : function(e){
      if(this.fireEvent('beforeunload', this) === false){
         e.stopEvent();
      }
   },
   preventBackspace : function(){
      var map = new Ext.KeyMap(document, [{
         key: Ext.EventObject.BACKSPACE,
         stopEvent: false,
         fn: function(key, e){
            var t = e.target.tagName;
            if(t != "INPUT" && t != "TEXTAREA"){
               e.stopEvent();
            }
         }
      }]);
   },
   onModuleActionComplete : function(module, data, options){
      this.fireEvent('moduleactioncomplete', this, module, data, options);
   }
});