Ext.ns('Ext.wg');

/*
	MyClass Template
*/
Ext.wg.MyClass = function(config){}
Ext.extend( Ext.wg.MyClass, Ext.grid.EditorGridPanel, {
	constructor: function( config )	{
		config = config || {};
		config.listeners = config.listeners || {};
		Ext.applyIf(config.listeners, {
		// add listeners config here
		});
		
		Ext.wg.MyClass.superclass.constructor.call( this, config );
	},
	
	initComponent: function() {
		var config = {
			// add components here
		};
		
		Ext.apply(this, Ext.apply(this.initialConfig, config));
        Ext.wg.MyClass.superclass.initComponent.apply(this, arguments);
	},
	onRender: function()	{
		Ext.wg.MyClass.superclass.onRender.apply(this, arguments);
	}
})
//




/*
	AccessPanel
*/
Ext.wg.AccessPanel = function(config){
	Ext.apply( this, config );
	Ext.wg.AccessPanel.superclass.constructor.call(this);
}

Ext.extend( Ext.wg.AccessPanel, Ext.grid.EditorGridPanel, {
    // l10n, data
	
    initComponent:function() {
        var checkColumn = new Ext.grid.CheckColumn({
			header: this.tr('#'),
			dataIndex: 'value',
			groupable: false,
			menuDisabled: true,
			width: 75
		});
        
        var cm = new Ext.grid.ColumnModel([
			{
				header: this.tr('labelGroup'),
				dataIndex: 'group'
			},
			{
				header: this.tr('labelAction'),
				dataIndex: 'action',
				scope: this,
				renderer: function(v) { return this.tr(v) }
			},
			checkColumn
		]);
        
        var store = new Ext.data.GroupingStore({
			reader: new Ext.data.JsonReader( {
				id: 'id',
				root: 'rows',
				totalProperty: 'totalCount',
				successProperty: 'success',
				fields: [
					{ name: 'group' },
					{ name: 'group_id' },
					{ name: 'action' },
					{ name: 'action_id' },
					{ name: 'value', type: 'bool' }
				]
			} ),
			data: this.data,
			sortInfo: {
				field: 'action',
				direction:'desc'
			},
			groupField: 'group'
			
		});
        
        var config =  {
            width: '100%',
			height: '100%',
			autoScroll: true,
			cm: cm,
			store: store,
			border: false,
			loadMask: true,
			plugins: checkColumn,
			clicksToEdit: 1,
			view: new Ext.grid.GroupingView({
				forceFit:true,
				groupTextTpl: '{text}',
				startCollapsed: true
			})
        };
		
		Ext.apply(this, Ext.apply(this.initialConfig, config));
        Ext.wg.AccessPanel.superclass.initComponent.apply(this, arguments);
    },
    
    tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    }
});

Ext.preg('access-panel', Ext.wg.AccessPanel );

/*
	CategoryProperties
*/
Ext.wg.CategoryProperties = function(config){
	Ext.apply( this, config );
	Ext.wg.CategoryProperties.superclass.constructor.call(this);
}

Ext.extend(Ext.wg.CategoryProperties, Ext.TabPanel, {
	module: 'none',
	node: {},
	tabGeneral: true,
	response: { id:0 },
	actionScript: '/',
	handlerStore: {},
    
    initComponent:function() {
		this.initToolbar();

        var tabs = new Array();

        if( this.tabGeneral )   {
			var fields = new Array();
            if( defined( this.response.id ) )   {
                fields.push({
                    xtype: 'textfield',
                    fieldLabel: this.tr('labelID'),
                    name: 'id',
                    value: this.response.id,
                    readOnly: 'true'
                });
            }
			if( defined( this.response.parent_id ) )   {
                fields.push({
					xtype: 'textfield',
					name: 'parent_name',
					fieldLabel: this.tr('labelParent'),
					value: this.response.parent_name + ' [' + this.response.parent_id + ']',
					readOnly: 'true'
				});
            }
			if( defined( this.response.path ) )   {
                fields.push({
					xtype: 'textfield',
					name: 'path',
					fieldLabel: this.tr('labelPath'),
					value: this.response.path,
					readOnly: 'true'
				});
            }
			if( defined( this.response.inserted ) )   {
                fields.push({
					xtype: 'textfield',
					name: 'inserted',
					fieldLabel: this.tr('labelInserted'),
					value: this.response.inserted,
					disabled: 'true'
				});
            }
			if( defined( this.response.updated ) )   {
                fields.push({
					xtype: 'textfield',
					name: 'updated',
					fieldLabel: this.tr('labelUpdated'),
					value: this.response.updated,
					disabled: 'true'
				});
            }
			if( defined( this.response.name ) )   {
                fields.push({
					xtype: 'textfield',
					name: 'name',
					fieldLabel: this.tr('labelName'),
					allowBlank: 'false',
					value: this.response.name
				});
            }
			if( defined( this.response.handler_id ) )   {
                fields.push({
					xtype: 'combo',
					store: this.handlerStore,
					mode: 'local',
					fieldLabel: this.tr('labelHandler'),
					name: 'handler_id_old',
					hiddenName: 'handler_id',
					displayField: 'alias',
					valueField: 'id',
					value: this.response.handler_id,
					typeAhead: true,
					triggerAction: 'all',
					emptyText: this.tr('labelSelectHandler'),
					selectOnFocus: true
				});
            }
			
			var flags = new Array();
			for( var i = 0; i < this.response.flags.length; i++ )	{
				flags.push( {
					xtype: 'checkbox',
					fieldLabel: this.tr(this.response.flags[i].fieldLabel),
					itemId: this.response.flags[i].fieldLabel,
					name: 'flags',
					checked: this.response.flags[i].checked,
					inputValue: this.response.flags[i].value
				} );
			}
			
			this.generalForm = new Ext.FormPanel({
				labelWidth: 85,
				url: this.actionScript,
				border: false,
				bodyStyle: 'padding: 0;',
				height:'100%',
				layout: 'column',
				forceLayout: true,
				deferredRender: false,
				baseParams: {
					action: this.module + '_category_update',
					parent_id: this.response.parent_id
				},
				items: [
					{
						columnWidth:.7,
						border: false,
						deferredRender: false,
						bodyStyle: 'padding: 5px',
						items: [
							{
								xtype:'fieldset',
								stateEvents:['expand','collapse'],
								getState:function() {
									return {
										collapsed:this.collapsed
									};
								},
								title: this.tr('tabParamsTitle'),
								stateId: this.module + '-category-params',
								collapsible: true,
								layout: 'form',
								autoScroll: true,
								defaults: { anchor: '100%' },
								defaultType: 'textfield',
								deferredRender: false,
								items: fields
							}
						]
					},
					{
						columnWidth:.3,
						border: false,
						deferredRender: false,
						bodyStyle: 'padding: 5px',
						deferredRender: false,
						itemId: 'options-column',
						items: [
							{
								xtype:'fieldset',
								stateEvents:['expand','collapse'],
								getState:function() {
									return {
										collapsed:this.collapsed
									};
								},
								title: this.tr('tabOptionsTitle'),
								stateId: this.module + '-category-options',
								collapsible: true,
								layout: 'form',
								itemId: 'options-fieldset',
								deferredRender: false,
								autoScroll: true,
								items: flags
							}
						]
					}
				]
			});			
            
            tabs.push( { title: this.tr('tabGeneralTitle'), items: this.generalForm  } );
        }
		if( this.tabL10n )	{
			this.initL10n();
			
            tabs.push( {
				title: this.tr('tabL10nTitle'),
				layout: 'fit',
				deferredRender: false,
				border: false,
				defaultType: 'textfield',
				stateId: this.module + '-category-view-l10n',
				getState:function() {
					return {
						activeTab:this.items.indexOf(this.getActiveTab())
					};
				},
				items: this.l10nPanel
			} );
        }
        if( this.tabAccess )	{
			this.initAccess();
			
			tabs.push( {
				title: this.tr('tabAccessTitle'),
				layout: 'fit',
				deferredRender: false,
				border: false,
                items: this.accessPanel 
			} );
        }
		if( this.tabVars )	{
			this.initVars();
			
			tabs.push(	{
				title: this.tr('tabVarsTitle'),
				layout: 'fit',
				deferredRender: false,
				items: [ this.varsPanel ]
			} );
		}
		
        Ext.apply(this, {
            items: tabs,
			tbar: this.tbar,
			stateEvents:['tabchange'],
    		border: false,
    		activeTab: 0,
    		deferredRender: false,
			forceLayout: true,
    		autoScroll: true,
			stateId: this.module + '-category-view-tab',
    		getState:function() {
    			return {
    				activeTab:this.items.indexOf(this.getActiveTab())
    			};
    		}
        });
		
        Ext.wg.CategoryProperties.superclass.initComponent.apply(this, arguments);
	},
	
    tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    },
	
	initToolbar: function()	{
		var b = new Array();
		if( ! defined( this.response.new_category ) )	{
			b.push(
				{
					xtype: 'button',
					text: this.tr('buttonRefresh'),
					iconCls: 'wg-toolbar-reload',
					scope: this,
					handler: this.doReload
				},'-'
			);
		}
		b.push( {
			xtype: 'button',
			text: this.tr('buttonSave'),
			iconCls: 'wg-toolbar-save',
			scope: this,
			handler: this.doSave
		});
		this.tbar = new Ext.Toolbar({ items: b });
	},
	
	initAccess: function()	{
		this.accessPanel = new Ext.wg.AccessPanel({
			l10n: this.l10n,
			data: this.response.access
		});
	},
	
	initVars: function()	{
		this.varsPanel = new Ext.FormPanel({
			border: false,
			frame: false,
			bodyStyle: 'padding: 5px',
			items: [
				{
					labelWidth: 0,
					hideLabel: true,
					xtype: 'textarea',
					name: 'config',
					width: '100%',
					height: '100%',
					value: this.response.config
				}
			]
		})
	},
	
	initL10n: function()	{
		this.l10nPanel = new Ext.FormPanel({
			border: false,
			frame: false,
			defaults: {
				border: false
			},
			items: [
				{
					xtype: 'tabpanel',
					activeTab: 0,
					width: '100%',
					autoHeight: 1,
					deferredRender: 0,
					forceLayout: 1,
					itemId: 'tabpanel',
					defaults: {
						bodyStyle: 'padding:10px',
						width: '100%'
					},
					items: this.response.l10n
				}
			]
		})
	},
	
	doReload: function( b, e )	{
		new Ext.LoadMask( this.getEl(), { msg: this.tr('dlgMsgLoading') } ).show();
		Ext.Ajax.request({
			url: this.actionScript,
			scope: this,
			success: function(req) {
				this.getEl().unmask();
				var obj = Ext.decode( req.responseText );
				Ext.apply( this.response, obj );
				
				for( var i in obj )	{
					if( i == 'flags' ) continue;
					var f = this.generalForm.getForm().findField(i);
					if( f )	{
						f.setValue( obj[i] );
					}
				}
				
				var c = this.generalForm.getComponent( 'options-column' ).getComponent( 'options-fieldset' );
				
				for( var i = 0; i < obj.flags.length; i++ )	{
					var f = c.getComponent( obj.flags[i].fieldLabel );
					if( defined(f) )	{
						f.setValue( obj.flags[i].checked );
					}
				}
							
				if( defined( this.accessPanel ) )	{
					this.accessPanel.store.loadData( obj.access );
				}
				
				if( defined( this.varsPanel ) )	{
					this.varsPanel.getForm().findField('config').setValue( obj.config );
				}
				
				if( defined( this.l10nPanel ) )	{
					var c = this.l10nPanel.getComponent('tabpanel');
					for( var i = 0; i < obj.l10n.length; i++ )	{
						for( var j = 0; j < obj.l10n[i].items.length; j++ )	{
							c.getComponent( obj.l10n[i].itemId ).getComponent( obj.l10n[i].items[j].itemId ).setValue(
								obj.l10n[i].items[j].value
							);
						}
					}	
				}
			},
			failure: function( req, obj ) {
				this.getEl().unmask();
				failure_ajax( req, obj ); 
			},
			params: {
				action: this.module + '_category_view',
				id: this.response.id
			}
		});
	},
	
	doSave: function( b, e )	{
		new Ext.LoadMask( this.getEl(), { msg: this.tr('dlgMsgLoading') } ).show();
		var form = this.generalForm.getForm();
		var params = {};
		
		if( defined( this.l10nPanel ) )	{
			params = Ext.apply( params, this.l10nPanel.getForm().getValues() );
		}
		
		if( defined( this.varsPanel ) )	{
			params = Ext.apply( params, this.varsPanel.getForm().getValues() );
		}
		
		if( defined( this.accessPanel ) )	{
			var gg = this.accessPanel.getStore().getModifiedRecords();
			var h = new Array();
			for (i = 0; i < gg.length; i++) {
				h[i] = gg[i].data;
			}
			params.json_access = Ext.encode(h);
		}
		
		form.submit({
			params:params,
			scope: this,
			failure: function( f, a  ) {
				this.getEl().unmask();
				failure_form( f, a ); 
			},
			success: function( f, a ) {
				this.getEl().unmask();

				if( defined( this.response.new_category ) )	{
					Ext.getCmp(this.module+ '-category-view-tab-0').destroy();
					this.node.reload();
				}
				else	{
//					this.node.parentNode.reload();	
				}
			}
		});
	}
});

Ext.preg('category-properties', Ext.wg.CategoryProperties );


/*
	GridPanelAbstract
*/
Ext.wg.GridPanelAbstract = function(config){
	Ext.apply( this, config );
	Ext.wg.GridPanelAbstract.superclass.constructor.call(this);
}

Ext.extend(Ext.wg.GridPanelAbstract, Ext.grid.GridPanel, {
    buttonRefresh: true,
    enablePaging: true,
    ddGroup: false,
	enableDragDrop: false,
    pageSize: 50,
    actionScript: '/',
    storeAction: false,
    
    initComponent:function() {
        this.initToolbar();
        this.initColumnModel();
        this.initStore();
        
        if( this.enablePaging ) {
            this.initBottomToolbar();
        }
        
        Ext.apply(this, {
            width: '100%',
			height: '100%',
            tbar: this.tbar,
            bbar: this.bbar,
			autoScroll: true,
            ddGroup: false,
            enableDragDrop: false,
            loadMask: true,
			cm: this.columnModel,
			store: this.store,
			border: false,
			loadMask: true,
			viewConfig: {
				forceFit:true
			}
        });
		
        Ext.wg.GridPanelAbstract.superclass.initComponent.apply(this, arguments);
    },
    
    tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    },
    
    initToolbar: function()    {
        var b = new Array();
        if( this.buttonRefresh )    {
            b.push(
				{
					xtype: 'button',
					text: this.tr('buttonRefresh'),
					iconCls: 'wg-toolbar-reload',
					scope: this,
					handler: this.doReload
				},'-'
			);
        }
        if( this.buttonAdd )    {
            b.push(
				{
					xtype: 'button',
					text: this.tr('buttonAdd'),
					iconCls: 'wg-toolbar-add',
					scope: this,
					handler: this.doAdd
				},'-'
			);
        }
        if( this.buttonCopy )    {
            b.push(
				{
					xtype: 'button',
					text: this.tr('buttonCopy'),
					iconCls: 'wg-toolbar-copy',
					scope: this,
					handler: this.doCopy
				},'-'
			);
        }
        if( this.buttonDel )    {
            b.push(
				{
					xtype: 'button',
					text: this.tr('buttonDel'),
					iconCls: 'wg-toolbar-del',
					scope: this,
					handler: this.doRemove
				},'-'
			);
        }
        
		this.tbar = new Ext.Toolbar({ items: b });
    },
    
    initBottomToolbar: function()   {
        this.bbar = new Ext.PagingToolbar({
            pageSize: this.pageSize,
            store: this.store,
            displayInfo: true,
            displayMsg: this.tr('dlgMsgTopics'),
            afterPageText: this.tr('dlgMsgAfterPage'),
            beforePageText: this.tr('dlgMsgBeforePage'),
            nextText: this.tr('dlgMsgNextText'),
            prevText: this.tr('dlgMsgPrevText'),
            firstText: this.tr('dlgMsgFirstText'),
            lastText: this.tr('dlgMsgLastText'),
            refreshText: this.tr('dlgMsgRefreshText'),
            emptyMsg: this.tr('dlgMsgNoTopics')
        });
    },
    
    initColumnModel: function() {
        this.columnModel = new Ext.grid.ColumnModel({
            items: {
                header: this.tr('labelID'),
                dataIndex: 'id',
                width: 20
            },
            defaultSortable: true
        });
    },
    
    initStore: function()   {
        this.store = new Ext.data.Store({
            autoDestroy: true,
            proxy: new Ext.data.HttpProxy({
                url: this.actionScript
            }),
            reader: new Ext.data.JsonReader(),
            baseParams: {
                action: this.storeAction,
                start: 0,
                limit: this.pageSize,
                pid: this.item_id
            },
            remoteSort: true,
            autoLoad: true,
            listeners: {
                scope: this,
                'load': function(a, b, c) {
                    if (typeof(a.reader.jsonData.columns) === 'object') {
                        var columns = [];
                        //if(this.rowNumberer) { columns.push(new Ext.grid.RowNumberer()); }
                        //if(this.checkboxSelModel) { columns.push(new Ext.grid.CheckboxSelectionModel()); }
                        Ext.each(a.reader.jsonData.columns, function(column) {
                            column.header = this.tr(column.header);
                            columns.push(column);
                        }, this );
                        this.getColumnModel().setConfig(columns);
                    }
                }
            }
        });
    },
    
    doReload: function()  { this.store.reload() },
    doAdd: function()  {},
    doEdit: function() {},
    doCopy: function()  {},
    doRemove: function()  {}
})


/*
	CategoriesPanelAbstract 
*/
Ext.wg.CategoriesPanelAbstract = function(config){
	config = config || {};
	config.listeners = config.listeners || {};
	Ext.applyIf(config.listeners, {
		contextmenu: this.onContextMenu,
		click: this.onClick,
		beforenodedrop: this.onBeforeNodeDrop
	});
	Ext.wg.CategoriesPanelAbstract.superclass.constructor.call( this, config );
}

Ext.extend( Ext.wg.CategoriesPanelAbstract, Ext.tree.TreePanel, {
	region: 'west',
	ddGroup: 'groupDD',
	panelTitle: 'TreePanel',
	rootNodeTtitle: '/',
	actionScrtip: undefined,
	loaderAction: undefined,
	
	initComponent: function() {
		this.initComponents();
		
		var config = {
			animate: false,
			collapsible: true,
			enableDD: true,
			enableDrop: true,
			containerScroll: true,
			rootVisible: true,
			width: '250',
			split: true,
			autoScroll: true,
			margins: '0 0 3 1',
			region: this.region,
			root: this.rootNode,
			loader: this.categoriesLoader,
			tbar: this.toolbar,
			bbar: this.bottomToolbar,
			contextMenu: this.contextMenu,
			title: this.panelTitle,
			plugins:[ new Ext.ux.state.TreePanel() ]
		};

		Ext.apply(this, Ext.apply(this.initialConfig, config));
        Ext.wg.CategoriesPanelAbstract.superclass.initComponent.apply(this, arguments);
	},
	
	initComponents: function()	{
		this.initRootNode();
		this.initCategoriesLoader();
		this.initToolbar();
		this.initBottomToolbar();
		this.initContextMenu();
	},
	
	tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    },
	
	initRootNode: function()	{
		this.rootNode = new Ext.tree.AsyncTreeNode({
			text: this.rootNodeTitle,
			draggable: false,
			allowDrag: false,
			allowDrop: false,
			expanded: true,
			id: '0'
		});
	},
	
	initCategoriesLoader: function()	{
		this.categoriesLoader = new Ext.tree.TreeLoader({
			dataUrl: this.actionScript,
			baseParams: {
				action: this.loaderAction
			},
			listeners: {
				loadexception: function( o, n, r )	{
					failure( r.status + ' ' + r.statusText );
				},
				load: function( o, n, r )	{
					var t = Ext.decode( r.responseText );
					if( t.failure || ( defined(t.success) && !t.success ) ) failure( t.msg );
				}
			}
		})
	},
	
	initToolbar: function()	{
		this.toolbar =  new Ext.Toolbar({
			items: [{
				iconCls: 'icon-expand-all',
				tooltip: this.tr('buttonExpandAllToolTip'),
				scope: this,
				handler: function() { this.root.expand(true) }
			},
			'-', {
				iconCls: 'icon-collapse-all',
				tooltip: this.tr('buttonCollapseAllToolTip'),
				scope: this,
				handler: function() { this.root.collapse(true) }
			},
			'-', {
				iconCls: 'icon-reload-all',
				tooltip: this.tr('buttonRefreshAllToolTip'),
				scope: this,
				handler: function() { this.root.reload() }
			}]
		});
	},
	
	initBottomToolbar: function()	{
		this.bottomToolbar = undefined;
		return;
	
		this.bottomToolbar = new Ext.Toolbar({
			items: [new Ext.form.TextField({
				width: '100%',
				enableKeyEvents: true
			})]
		});
	},
	
	initContextMenu: function() {
		this.contextMenu = undefined;
	},
	
	onContextMenu: function( o, e )	{
		o.select();
		var c = o.getOwnerTree().contextMenu;
		if( defined(c) )	{
			c.contextNode = o;
			c.showAt(e.getXY());
		}
	},
	
	onClick: function( o, e ) {},
	onBeforeNodeDrop: function( o, e )	{}
})
//


/*
	Msg
*/
//Ext.wg.Msg = function(config){
//	Ext.apply( this, config );
//	Ext.wg.Msg.superclass.constructor.call(this);
//}
//
//Ext.extend( Ext.wg.Msg, Ext.Msg, {
//	l10n: {},
//	message: '',
//	title: '',
//	
//	initComponent:function() {
//		
//		Ext.apply(this, {
//			title: this.basel('dlgMsgMessage'),
//			msg: m,
//			minWidth: 250,
//			modal: false,
//			icon: Ext.MessageBox.WARNING,
//			buttons: Ext.Msg.YES
//        });
//		
//        Ext.wg.Msg.superclass.initComponent.apply(this, arguments);
//	}
//})
//



