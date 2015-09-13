//<!--
var siteModulePath = '/cgi-bin/wg/modules/site';
var sitePerPage = 50;

var siteHandlerStore = new Ext.data.JsonStore({
	proxy: new Ext.data.HttpProxy({
		url: '/cgi-bin/wg/modules/configuration/item.cgi'
	}),
	baseParams: {
		action: 'configuration_handlers_list'
	},
	fields: ['id', 'alias'],
	autoLoad: true
});


function sitel(msg) {
	return l('site', msg);
}

AxisDesktop.siteModule = function() {
    Ext.app.Module.superclass.constructor.call(this);
}

Ext.extend( AxisDesktop.siteModule, Ext.app.Module, {
	id: 'store-site',
	type: 'store/site',
    actionScript: 'index.cgi',
    modulePath: '/cgi-bin/wg/modules/site',
    gridPageSize: 50,

	init: function() {
		//this.l10n = AccordionWindow.Locale;
	},
    
	createWindow: function() {
		var desktop = this.app.getDesktop();
		var win = desktop.getWindow('site-win');
		if (!win) {
            this.initCategories();
            this.initTabs();
            
			win = desktop.createWindow({
				id: 'site-win',
				title: sitel('titleMainWindow'),
				width: 920,
				height: 500,
				iconCls: 'site-main-window',
				shim: false,
				animCollapse: false,
				border: false,
				constrainHeader: true,
				layout: 'border',
				items: [ this.categoriesPanel, this.tabsPanel ]
			});
		}
		win.show();	
	},
    
    initCategories: function()  {
        this.categoriesPanel = new Ext.wg.SiteCategoriesPanel({
            app: this,
            l10n: siteLang
        });
    },
    
    initTabs: function()    {
        this.tabsPanel = new Ext.TabPanel({
            id: 'site-tabs',
            activeTab: 0,
            region: 'center',
            enableTabScroll: true
        });
    }
});

//-------------------------------------------------------------
//    site CATEGORY
//-------------------------------------------------------------

Ext.wg.SiteCategoriesPanel = function( config ) {
    config = config || {};
    Ext.wg.SiteCategoriesPanel.superclass.constructor.call( this, config );
};

Ext.extend( Ext.wg.SiteCategoriesPanel, Ext.wg.CategoriesPanelAbstract, {
	initComponent: function() {
		var config = {
            id: 'siteTree',
            panelTitle: this.tr('labelStructure'),
            rootNodeTitle: this.tr('categoriesRootNodeAlias'),
            actionScript: siteModulePath + '/category.cgi',
            loaderAction: 'site_categories_list',
            ddGroup: 'siteGridDD'
		};
		
		Ext.apply(this, Ext.apply(this.initialConfig, config));
        Ext.wg.SiteCategoriesPanel.superclass.initComponent.apply(this, arguments);
        
        // fuck!!!
        this.on('click', siteCategoriesOnClick );
        this.on('beforenodedrop', siteCategoriesOnBeforeNodeDrop );
	},
    
    initContextMenu: function() {
        this.contextMenu = new Ext.menu.Menu({
            items: [
            {
                itemId: 'refresh',
                text: this.tr('labelRefresh'),
                iconCls: 'wg-toolbar-reload'
            },
            {
                itemId: 'properties',
                text: this.tr('labelProperties'),
                iconCls: 'wg-toolbar-properties'
            },
            {
                itemId: 'templates',
                iconCls: 'wg-toolbar-template',
                text: this.tr('labelTemplates')
            },
            {
                itemId: 'domains',
                iconCls: 'wg-toolbar-domain',
                text: this.tr('labelDomains')
            },
            {
                itemId: 'add',
                iconCls: 'wg-toolbar-add',
                text: this.tr('labelAdd')
            },
            {
                itemId: 'copy',
                iconCls: 'wg-toolbar-copy',
                text: this.tr('labelCopy')
            },
            {
                itemId: 'delete',
                iconCls: 'wg-toolbar-del',
                text: this.tr('labelDelete')
            }],
            listeners: {
                itemclick: function(item) {
                    var n = item.parentMenu.contextNode;
    
                    switch (item.itemId) {
                    case 'refresh':
                        n.reload();
                        break;
                    case 'properties':
                        siteCategoryView(n);
                        break;
                    case 'add':
                        siteCategoryView(n, 1);
                        break;
                    case 'copy':
                        siteCategoryCopy(n);
                        break;
                    case 'templates':
                        siteTemplatePanel(n);
                        break;
                    case 'site-domains-context':
                        siteDomainPanel(n);
                        break;
                    case 'site-delete-context':
                        if (confirm(sitel('labelDelete') + '?')) {
                                                    
                            Ext.Ajax.request({
                            url: siteModulePath + '/category.cgi',
                            success: function() {
                                //ds.reload();
                                //Ext.getCmp('site-tabs').getEl().unmask();
                            },
                            failure: function() {
                                //Ext.getCmp('site-tabs').getEl().unmask();
                                alert('failure')
                            },
                            params: {
                                action: 'site_category_delete',
                                id: n.id
                            }
                        });
                            
                            
                        }
                        break;
                    }
                }
            }
        });
    }
})



function siteCategoriesOnClick(item, e) {
	var tabs = Ext.getCmp('site-tabs');
	if (tabs.items.get('site_' + item.id)) {
		tabs.setActiveTab('site_' + item.id);
	} else {
		var grid = siteItemGridPanel(item.id);
		tabs.add({
			title: item.text.substring(0, 30),
			id: 'site_' + item.id,
			tabTip: item.parentNode.text + ' / ' + item.text,
			tbar: [
			{
				text: sitel('buttonRefresh'),
				tooltip: sitel('buttonRefreshToolTip'),
				iconCls: 'wg-toolbar-reload',
				handler: function() {
					grid.getStore().reload()
				}
			},'-',
			{
				text: sitel('buttonAdd'),
				tooltip: sitel('buttonAddToolTip'),
				iconCls: 'wg-toolbar-add',
				handler: function() {
					siteItemAdd(item.id, item.text, grid)
				}
			},
			'-', {
				text: sitel('buttonCopy'),
				tooltip: sitel('buttonCopyToolTip'),
				iconCls: 'wg-toolbar-copy',
				handler: function() {
					siteItemCopy(grid)
				}
			},
			'-', {
				text: sitel('buttonDel'),
				tooltip: sitel('buttonDelToolTip'),
				iconCls: 'wg-toolbar-del',
				handler: function() {
					Ext.Msg.confirm(sitel('dlgTitleDeleteItem'), sitel('dlgMsgDeleteItem'),
					function(btn) {
						if (btn == 'yes') {
							siteItemDelete(item.id, item.text, grid)
						}
					})
				}
			}],
			bbar: new Ext.PagingToolbar({
				pageSize: sitePerPage,
				id: 'site-item-grid-bbar-' + item.id,
				store: grid.store,
				displayInfo: true,
				displayMsg: sitel('dlgMsgTopics'),
				afterPageText: sitel('dlgMsgAfterPage'),
				beforePageText: sitel('dlgMsgBeforePage'),
				nextText: sitel('dlgMsgNextText'),
				prevText: sitel('dlgMsgPrevText'),
				firstText: sitel('dlgMsgFirstText'),
				lastText: sitel('dlgMsgLastText'),
				refreshText: sitel('dlgMsgRefreshText'),
				emptyMsg: sitel('dlgMsgNoTopics')
			}),
			items: [grid],
			iconCls: 'wg-tab-folder',
			closable: true,
			//height: '100%',
			autoHeigh: true,
			autoScroll: true,
			deferredRender: false,
			layout: 'fit'
		}).show();

		var ddrow = new Ext.dd.DropTarget(grid.getView().mainBody, {
			ddGroup: 'siteGridDD',
			copy: false,
			notifyDrop: function(dd, e, data) {
				var sm = grid.getSelectionModel();
				var rows = sm.getSelections();
				var ds = grid.getStore();

				var cindex = dd.getDragData(e).rowIndex;
				if (cindex == undefined || cindex < 0) {
					e.cancel = true;
					return;
				}
				/*
		for (i = 0; i < rows.length; i++) {  
				rowData = ds.getById(rows[i].id);  
				 if (!this.copy) {  
					 ds.remove(ds.getById(rows[i].id));   // remove in datasource.  
					 ds.insert(cindex, rowData);              //insert record .  
				 }  
			 }  
		*/
				var h = new Array();
				if (!this.copy) {
					for (i = 0; i < rows.length; i++) {
						//ds.remove(ds.getById(rows[i].id));
						h[i] = rows[i].id;
					};
				};
				//ds.insert(cindex, data.selections);
				//sm.selectRecords(rows);
				//storeData(ds);
				Ext.Ajax.request({
						url: siteModulePath + '/item.cgi',
						success: function() {
							ds.reload();
							Ext.getCmp('site-tabs').getEl().unmask();
						},
						failure: function() {
							Ext.getCmp('site-tabs').getEl().unmask();
							alert('failure')
						},
						params: {
							action: 'site_item_ordering',
							src: h.join(','),
							dst: ds.getAt(cindex).id,
							pid: item.id
						}
					});
			}
		});
	}
}
	
function siteCategoriesOnBeforeNodeDrop(e) {
	new Ext.LoadMask(Ext.getCmp('site-win').getEl(), { msg: sitel('dlgMsgLoading') } ).show();
	
	var s = e.data.selections;
	var a = e.target.id;
	var t = e.source;
	if (s) {
		var w = new Array();
		for (i = 0; i < s.length; i++) {
			w[i] = s[i].id;
		}
		Ext.Ajax.request({
			url: siteModulePath + '/item.cgi',
			success: function() {
				s[0].store.reload();
				Ext.getCmp('site-win').getEl().unmask();
			},
			failure: function() {
				Ext.getCmp('site-win').getEl().unmask();
				alert('failure')
			},
			params: {
				action: 'site_item_move',
				src: w.join(','),
				dst: a
			}
		});
	}
	else	{
		Ext.Ajax.request({
			url: siteModulePath + '/category.cgi',
			success: function() {
				if (e.point == 'append') {
					e.target.reload();
				} else if( e.target.parentNode ) {
					e.target.parentNode.reload();
				}
				Ext.getCmp('site-win').getEl().unmask();
			},
			failure: function() {
				Ext.getCmp('site-win').getEl().unmask();
				alert('failure')
			},
			params: {
				action: 'site_category_move',
				src: e.dropNode.id,
				dst: e.target.id,
				point: e.point
			}
		});
	}
}

	




function siteCategoryView(node, add) {
	var tabs = Ext.getCmp('site-tabs');
	if (tabs.items.get('site-category-view-tab-' + node.id) && !add) {
		tabs.setActiveTab('site-category-view-tab-' + node.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('site-tabs').getEl(), {
			msg: sitel('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: siteModulePath + '/category.cgi',
			success: function(req) {
				Ext.getCmp('site-tabs').getEl().unmask();
				var obj = Ext.decode( req.responseText );
				
				for( var i = 0; i < obj.l10n.length; i++ )	{
					for( var j = 0; j < obj.l10n[i].items.length; j++ )	{
						obj.l10n[i].items[j].fieldLabel = sitel( obj.l10n[i].items[j].fieldLabel );
					}
				}
				
				siteCategoryViewTab(node, obj, add);
			},
			failure: function( req, obj ) {
				Ext.getCmp('site-tabs').getEl().unmask();
				alert(req.respnseText);
				failure_ajax( req, obj ); 
			},
			params: {
				action: 'site_category_view',
				id: node.id,
				add: add
			}
		});
	}
}

function siteCategoryViewTab(node, obj, add) {
	var title;
	var tabTip;
	var tabButtons;
	var parentNodeText;
	
	if( ! node.parentNode )	{
		parentNodeText = sitel('treeRootNodeAlias');
	}
	else	{
		parentNodeText = node.parentNode.text;
	}
	
	if (add) {
		title = sitel('tabAddToDirTitle') + ' "' + node.text + '"';
		tabTip = sitel('tabAddToDirTitle') + ' "' + parentNodeText + ' / ' + node.text;
		obj.add = 1;
	} else {
		title = node.text;
		tabTip = parentNodeText + ' / ' + node.text;
		obj.add = 0;
	}
	
	title = title.substring(0, 30);
	
	if( add )	{
		Ext.apply( obj, {
			handler_id: '',
			name: '',
			new_category: 1,
			id: 0
		} );
		delete obj['inserted'];
	}
	
	var siteCategoryViewConfig = {
		node:node,
		response: obj,
		module:'site',
		actionScript: siteModulePath + '/category.cgi',
		tabGeneral: true,
		tabL10n: true,
		tabAccess: ( defined(obj.new_category) ) ? false : true,
		tabVars: true,
		l10n: siteLang,
		handlerStore: siteHandlerStore
	};
	
	Ext.getCmp('site-tabs').add({
		title: title,
		tabTip: tabTip,
		id: 'site-category-view-tab-' + obj.id,
		items: new Ext.wg.CategoryProperties( siteCategoryViewConfig ),
		iconCls: 'wg-toolbar-properties',
		closable: true,
		layout: 'fit'
	}).show();
}



//-------------------------------------------------------------
//    site ITEM
//-------------------------------------------------------------

function siteItemGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: sitel('labelID'),
		dataIndex: 'id',
		width: 50
	}]);

	cm.defaultSortable = true;
	return (cm);
}

function siteItemGridStore(pid, grid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: siteModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'site_items_list'
		},
		remoteSort: true
	});
	
	store.on('load',
	function(a, b, c) {
		if (typeof(store.reader.jsonData.columns) === 'object') {
			var columns = [];
			//if(this.rowNumberer) { columns.push(new Ext.grid.RowNumberer()); }
			//if(this.checkboxSelModel) { columns.push(new Ext.grid.CheckboxSelectionModel()); }
			Ext.each(store.reader.jsonData.columns,
			function(column) {
				column.header = sitel(column.header);
				columns.push(column);
			});
			if (grid) grid.getColumnModel().setConfig(columns);
		}
		//this.el.unmask();
	});

	store.load({
		params: {
			start: 0,
			limit: sitePerPage,
			pid: pid
		}
	});
	return (store);
}


function siteItemGridPanel(pid) {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		cm: siteItemGridColumnModel(),
		ddGroup: 'siteGridDD',
		autoScroll: true,
		border: false,
		enableDragDrop: true,
		loadMask: true,
		id: 'site-item-grid-panel-' + pid,
		viewConfig: {
			forceFit: true
		}
	});
	
	var store = siteItemGridStore(pid, grid);

	grid.store = store;
	grid.on('rowdblclick', siteItemGridOnRowDblClick);
	return (grid);
}





function siteItemAdd(pid, alias, grid) {
	var form = new Ext.FormPanel({
		labelWidth: 55,
		url: siteModulePath + '/item.cgi',
		border: false,
		bodyStyle: 'padding: 10',
		width: '100%',
		defaults: {
			width: '100%'
		},
		defaultType: 'textfield',
		autoHeight: true,
		items: [{
			fieldLabel: siteLang['labelURL'],
			name: 'name',
			allowBlank: false
		}],
		buttons: [{
			text: siteLang['formButtonSave'],
			handler: function() {
				form.getForm().baseParams = {
					action: 'site_item_add',
					parent_id: pid
				};
				form.getForm().submit({
					waitMsg: siteLang['dlgMsgSaving'],
					success: function() {
						win.destroy();
						grid.getStore().reload()
					}
				});
			}
		},
		{
			text: siteLang['formButtonCancel'],
			handler: function() {
				win.destroy();
			}
		}]
	});

	form.doLayout();

	var win = new Ext.Window({
		title: siteLang['dlgTitleAddItemTo'] + ' "' + alias + '"',
		closable: true,
		width: 400,
		height: 115,
		items: [form]
	});

	win.show();
}

function siteItemDelete(pid, alias, grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: siteModulePath + '/item.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'site_item_delete',
			id: a.toString()
		}
	});
}

function siteItemFileDelete(pid, grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: siteModulePath + '/item.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'site_item_del_file',
			fid: a.toString()
		}
	});

}

function siteItemCopy(grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: siteModulePath + '/item.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'site_item_copy',
			ids: a.toString()
		}
	});

}



function siteItemGridOnRowDblClick(grid, rowIndex, e) {
	var tabs = Ext.getCmp('site-tabs');
	var record = grid.getStore().getAt(rowIndex);
	
	if (tabs.items.get('site_item_tab_' + record.id) ) {
		tabs.setActiveTab('site_item_tab_' + record.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('site-tabs').getEl(), {
			msg: sitel('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: siteModulePath + '/item.cgi',
			success: function(req) {
				Ext.getCmp('site-tabs').getEl().unmask();
				var obj;
				var tt = 'obj = ' + req.responseText;
				eval(tt);
				
				for( var i = 0; i < obj.l10n.items.length; i++ )	{
					for( var j = 0; j < obj.l10n.items[i].items.length; j++ )	{
						obj.l10n.items[i].items[j].fieldLabel = sitel( obj.l10n.items[i].items[j].fieldLabel );
					}
				}
				
				for( var i = 0; i < obj.flags.length; i++ )	{
						obj.flags[i].fieldLabel = sitel( obj.flags[i].fieldLabel);
				}
				siteItemTab(record, obj);
			},
			failure: function() {
				Ext.getCmp('site-tabs').getEl().unmask();
				alert('failure');
			},
			params: {
				action: 'site_item_view',
				id: record.id
			}
		});
	}
}

function siteItemTab(record, obj) {
	var simple = new Ext.FormPanel({
		labelWidth: 85,
		url: siteModulePath + '/item.cgi',
		border: false,
		bodyStyle: 'padding: 0',
		width: '100%',
		id: 'site-item-form-' + obj.id,
		forceLayout: true,
		defaults: {
			width: '100%',
			labelWidth: 120
		},
		defaultType: 'textfield',
		autoHeight: true,
		items: {
			xtype: 'tabpanel',
			activeTab: 0,
			id: 'item-main-tabpanel-'+obj.id,
			stateEvents:['tabchange'],
			border: false,
			deferredRender: false,
			getState:function() {
				return {
					activeTab:this.items.indexOf(this.getActiveTab())
				};
			},
			defaults: {
				autoHeight: true,
				autoScroll: true,
				border: false,
				bodyStyle: 'padding:10px',
				width: '500'
			},
			items: [
                {
				title: sitel('tabGeneralTitle'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%',
					border: false
				},
				defaultType: 'textfield',
				items: [
				{
					fieldLabel: sitel('labelID'),
					name: 'id',
					value: obj.id,
					readOnly: 'true'
				},
				{
					xtype: 'hidden',
					name: 'parent_id',
					value: obj.parent_id
				},
				{
					xtype: 'hidden',
					name: 'ordering',
					value: obj.ordering
				},
				{
					inputType: 'hidden',
					name: 'handler_id2',
					value: obj.handler_id
				},
				{
					fieldLabel: sitel('labelPath'),
					value: obj.path,
					name: 'path',
					readOnly: 'true'
				},
				{
					fieldLabel: sitel('labelName'),
					name: 'name',
					value: obj.name
				},
                {
					fieldLabel: sitel('labelOwner'),
					value: obj.owner,
                    name: 'module',
					disabled: 'true'
				},
				{
					fieldLabel: sitel('labelInserted'),
					value: obj.inserted,
                    name: 'inserted',
					disabled: 'true'
				},
				{
					fieldLabel: sitel('labelUpdated'),
					value: obj.updated,
                    name: 'updated',
					disabled: 'true'
				},
				{
					xtype: 'combo',
					store: siteHandlerStore,
					fieldLabel: sitel('labelHandler'),
					name: 'handler_id_old',
					hiddenName: 'handler_id',
					id: 'site_item_handler_id_' + obj.id,
					displayField: 'alias',
					valueField: 'id',
					typeAhead: true,
					triggerAction: 'all',
					mode: 'local',
					selectOnFocus: true
				},
				{
					xtype: 'combo',
					store: siteTemplateStore(obj.parent_id),
					fieldLabel: sitel('labelTemplate'),
					name: 'template_id_old',
					hiddenName: 'template_id',
					id: 'site_item_template_id_' + obj.id,
					displayField: 'alias',
					valueField: 'id',
					typeAhead: true,
					triggerAction: 'all',
					//mode: 'local',
					selectOnFocus: true
				}
                ]
			},
			{
				title: sitel('tabL10nTitle'),
				layout: 'form',
				border: false,
				bodyStyle: 'padding: 0',
				width: '100%',
				defaults: {
					width: '100%',
					border: false
				},
				defaultType: 'textfield',
				items: obj.l10n
			},
			{
				title: sitel('tabContentTitle'),
				layout: 'form',
				border: false,
				bodyStyle: 'padding:0',
				width: '100%',
				defaults: {
					width: '100%',
					border: false
				},
				items: [ obj.tpl ]
			},
			{
				title: sitel('tabFilesTitle'),
				layout: 'form',
				border: false,
				bodyStyle: 'padding: 0',
				defaults: {
					width: '100%'
				},
				tbar: [
				{
					text: sitel('buttonRefresh'),
					tooltip: sitel('buttonRefreshToolTip'),
					iconCls: 'wg-toolbar-reload',
					handler: function() {
						Ext.getCmp('site_item_files_grid_panel_' + obj.id).getStore().reload();
					}
				},'-',
				{
					text: sitel('buttonAdd'),
					tooltip: sitel('buttonAddFileToolTip'),
					iconCls: 'wg-toolbar-add',
					handler: function() {
						var dialog;
						Ext.apply(Ext.ux.UploadDialog.Dialog.prototype.i18n, siteLang['uploadDialogI18n'] );
						if (!dialog) {
							dialog = new Ext.ux.UploadDialog.Dialog({
								url: siteModulePath + '/item.cgi',
								base_params: {
									action: 'site_item_add_file',
									id: obj.id
								},
								//reset_on_hide: true
								allow_close_on_upload: true,
								//upload_autostart: false
								post_var_name: 'fileupload'
							});
							
							//dialog.on('beforefileuploadstart', this.onUploadSuccess, this);
							dialog.on('beforefileuploadstart', siteItemOnBeforeFileUploadStart );
							dialog.on('uploadcomplete', function( d ){
								Ext.getCmp('site_item_files_grid_panel_' + obj.id).getStore().reload();
							} );
							//dialog.on('uploadsuccess', this.onUploadSuccess, this);
						}
						dialog.show();
					}
				},'-',
				{
					text: sitel('buttonDel'),
					tooltip: sitel('buttonDelFileToolTip'),
					iconCls: 'wg-toolbar-del',
					handler: function() {
						siteItemFileDelete( obj.id, Ext.getCmp('site_item_files_grid_panel_' + obj.id) );
					}
				},'-'
				],
				defaultType: 'textfield',
				items: [ siteItemFilesGridPanel( obj.id ) ]
			},
			{
				title: sitel('tabAccessTitle'),
				layout: 'form',
				border: false,
				defaultType: 'textfield',
				autoHeight:true,
				bodyStyle: 'padding: 0',
                items: [ siteItemAccessGridPanel( obj.id ) ]
			},
			{
				title: sitel('tabOptionsTitle'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: obj.flags
			},
			{
				title: sitel('tabVarsTitle'),
				layout: 'fit',
				items: [{
					labelWidth: 0,
					hideLabel: true,
					xtype: 'textarea',
					name: 'config',
					width: '100%',
					height: '70%',
					value: obj.config
				}]
			}
            ]
		}
	});

	var title = record.get('name');
	var tabTip = obj.parent_name + '/' + record.get('name');
	
	title = title.substring(0, 30)

	Ext.getCmp('site-tabs').add({
		title: title,
		id: 'site_item_tab_' + obj.id,
		tabTip: tabTip,
		items: [simple],
		iconCls: 'wg-tab-file',
		closable: true,
		//height: '100%',
		autoHeigh: true,
		autoScroll: true,
		layout: 'fit',
		deferredRender: false,
		forceLayout: true,
		keys: [
			{
				key: "s",
				ctrl:true,
				stopEvent: true,
				fn: function(){ siteItemSave( obj ) }
			}
		],
		tbar:[
			{
				text: sitel('buttonSave'),
				iconCls: 'wg-toolbar-save',
				handler: function() {
					var gg = Ext.getCmp('site_item_access_grid_'+obj.id).getStore().getModifiedRecords();
					var h = new Array();
					for (i = 0; i < gg.length; i++) {
						h[i] = gg[i].data;
					}
					simple.getForm().baseParams = {
						json_access: Ext.encode(h),
						action: 'site_item_update'
					};
					new Ext.LoadMask(Ext.getCmp('site_item_tab_' + obj.id).getEl(), {
						msg: sitel('dlgMsgSaving')
					}).show();
					simple.getForm().submit({
						//clientValidation: false,
						success: function() { Ext.getCmp('site_item_tab_' + obj.id).getEl().unmask(); },
						failure: function(f,a){
							Ext.getCmp('site_item_tab_' + obj.id).getEl().unmask();
							alert( 'failure' );
						}
					});
				}
			}
		]
	}).show();
	
	Ext.getCmp('site_item_handler_id_' + obj.id).setValue( obj.handler_id );
	Ext.getCmp('site_item_template_id_' + obj.id).setValue( obj.template_id );
	
}

function siteItemSave( obj )	{
	var gg = Ext.getCmp('site_item_access_grid_' + obj.id).getStore().getModifiedRecords();
	var h = new Array();
	for (i = 0; i < gg.length; i++) {
		h[i] = gg[i].data;
	}
	Ext.getCmp('site-item-form-'+obj.id).getForm().baseParams = {
		json_access: Ext.encode(h),
		action: 'site_item_update'
	};
	new Ext.LoadMask(Ext.getCmp('site_item_tab_' + obj.id).getEl(), {
		msg: sitel('dlgMsgSaving')
	}).show();
	Ext.getCmp('site-item-form-'+obj.id).getForm().submit({
		//clientValidation: false,
		success: function() {
			Ext.getCmp('site_item_tab_' + obj.id).getEl().unmask();
		},
		failure: function(f, a) {
			Ext.getCmp('site_item_tab_' + obj.id).getEl().unmask();
			alert('failure');
		}
	});
}

function siteItemOnBeforeFileUploadStart(dialog, filename, record)	{
    if( Ext.getCmp('file_upload_type').getValue() )	{
		dialog.base_params.type_id = Ext.getCmp('file_upload_type').getValue();
		dialog.base_params.overwrite = Ext.getCmp('file_upload_overwrite').getValue();
		dialog.base_params.filename = filename;
		//alert(filename);
		return true;
	}
	
	return false;
}


function siteItemFileRenderPreview( val )	{
	if( val.length > 1 )	{
		return '<img src="' + val + '">';
	}
	else	{
		return '';
	}
}

function siteItemFileRenderView( val )	{
	if( val && val.length > 1 )	{
		return '<a href="'+val+'" target="_blank">' + sitel('#') + '</a>';
	}
	else	{
		return '';
	}
}

function siteItemFilesGridColumnModel(actions) {
	var cm = new Ext.grid.ColumnModel([
		{
			header: sitel('labelImg'),
			dataIndex: 'preview',
			renderer: siteItemFileRenderPreview,
			width: 50
		},
		{
			header: sitel('labelType'),
			dataIndex: 'type_name_alias',
			width: 50
		},
		{
			header: sitel('labelSize'),
			dataIndex: 'size',
			width: 50
		},
		{
			header: sitel('labelInserted'),
			dataIndex: 'inserted',
			width: 50
		},
		{
			header: sitel('#'),
			dataIndex: 'src',
			renderer: siteItemFileRenderView,
			width: 50
		},
		{
			header: sitel('labelURL'),
			dataIndex: 'src',
			editor: new Ext.form.TextField({
                allowBlank: true,
				selectOnFocus: true
            }),
			width: 50
		},
		{
			header: sitel('labelAlias'),
			dataIndex: 'alias',
			editor: new Ext.form.TextField({
                allowBlank: true,
				selectOnFocus: true
            }),
			width: 50
		}
	]);

	return (cm);
}

function siteItemFilesGridStore( id, grid )	{
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: siteModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'site_item_files_list',
			id: id
		},
		groupField:'type_name_alias',
		remoteSort: true
	});

	store.load({
		params: {
			start: 0,
			limit: 1000,
			id: id
		}
	});
	return (store);
}

function siteItemFilesGridPanel( id ) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
		autoHeight: true,
		cm: siteItemFilesGridColumnModel(),
		ddGroup: 'siteFilesGridDD',
		autoScroll: true,
		enableDragDrop: true,
		selModel: new Ext.grid.RowSelectionModel({singleSelect:false}),
		clicksToEdit: 1,
		loadMask: true,
		border: false,
		id: 'site_item_files_grid_panel_' + id,
		view: new Ext.grid.GroupingView({
            forceFit:true,
            groupTextTpl: '{text}'
//			enableRowBody:true,
//			getRowClass : function(record, rowIndex, p, store){
//                if(this.showPreview){
//                    p.body = '<p>=============</p>';
//                    return 'x-grid3-row-expanded';
//                }
//                p.body = '<p>=============</p>';
//				p.body = { xtype: 'textfield' };
//                return 'x-grid3-row-expanded';
////                return 'x-grid3-row-collapsed';
//            }
        }),
		viewConfig: {
			forceFit: true
		}
	});
	
	var store = siteItemFilesGridStore( id, grid);

	grid.store = store;
	//grid.on('rowdblclick', siteItemFilesGridOnRowDblClick);
	return (grid);
}

function siteItemFilesGridOnRowDblClick()	{
	var form = new Ext.form.FormPanel({
        baseCls: 'x-plain',
        labelWidth: 55,
        url:'save-form.php',
        defaultType: 'textfield',

        items: [{
            fieldLabel: 'Send To',
            name: 'to',
            anchor:'100%'  // anchor width by percentage
        },{
            fieldLabel: 'Subject',
            name: 'subject',
            anchor: '100%'  // anchor width by percentage
        }, {
            xtype: 'htmleditor',
            hideLabel: true,
            name: 'msg',
            anchor: '100% -53'  // anchor width by percentage and height by raw adjustment
        }]
    });

	var window = new Ext.Window({
        title: 'Resize Me',
        width: 500,
        height:300,
        minWidth: 300,
        minHeight: 200,
        layout: 'fit',
        plain:true,
        bodyStyle:'padding:5px;',
        buttonAlign:'center',
        items: form,

        buttons: [{
            text: 'Send'
        },{
            text: 'Cancel'
        }]
    });

    window.show();
}

var siteItemCM = new Array();

function siteItemAccessActionRenderer(val)	{
	return sitel(val);
}

function siteItemAccessGridColumnModel(actions) {
	var cm;
	var cols = new Array(
        {
        	header: sitel('labelGroup'),
            tooltip: sitel('labelGroup'),
        	dataIndex: 'group'
        },
        {
        	header: sitel('labelAction'),
            tooltip: sitel('labelAction'),
        	dataIndex: 'action',
			renderer: siteItemAccessActionRenderer
        }
    );
	
	var checkColumn = new Ext.grid.CheckColumn({
			header: sitel('#'),
			tooltip: sitel('#'),
			dataIndex: 'value',
			width: 75
	});
	cols.push( checkColumn );
	siteItemCM[0] = checkColumn;
	
	cm = new Ext.grid.ColumnModel(cols);

	return (cm);
}

function siteItemAccessGridStore( pid ) {   
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: siteModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'site_item_access_list',
			id: pid
		},
        groupField:'group',
		remoteSort: true
	});

	store.load({
		params: {
			start: 0,
			limit: 1000,
			pid: pid
		}
	});
	return (store);
}

function siteItemAccessGridPanel(pid) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
        autoHeight: true,
		cm: siteItemAccessGridColumnModel(),
        store: siteItemAccessGridStore( pid ),
		border: false,
		loadMask: true,
        plugins: siteItemCM[0],
        clicksToEdit: 1,
		id: 'site_item_access_grid_' + pid,
        view: new Ext.grid.GroupingView({
            forceFit:true,
            groupTextTpl: '{text}',
			startCollapsed: true
        }),
		viewConfig: {
			forceFit: true
		}
	});

	return (grid);
}


function siteTemplateStore( pid ) {
	var store = new Ext.data.JsonStore({
		url: siteModulePath + '/template.cgi',
		baseParams: {
			action: 'site_template_item_list',
			pid: pid
		},
		//autoLoad: true,
		fields: ['id', 'alias']
		
	});

	store.load();
	return (store);
}


//------------------------------------------------------------------
//  TEMPLATES
//------------------------------------------------------------------

function siteTemplatePanel( item ) {
	var tabs = Ext.getCmp('site-tabs');
	if (tabs.items.get('site-templates-list') ) {
		tabs.setActiveTab('site-templates-list');
	} else {
		tabs.add({
			title: sitel('tabSiteTemplatesTitle'),
			id: 'site-template-list',
			items: [
				new Ext.wg.TemplateGridPanel({
					l10n: siteLang,
					buttonAdd: true,
					buttonCopy: true,
					buttonDel: true,
					actionScript: siteModulePath + '/template.cgi',
					storeAction: 'site_template_list',
					item_id: item.id
				})
			],
			iconCls: 'wg-tab-template',
			closable: true,
			//height: '100%',
			border: false,
			autoHeigh: true,
			autoScroll: true,
			layout: 'fit'
		}).show();
	}
}


/*
    TemplateGridPanel
*/
Ext.wg.TemplateGridPanel = function(config){
	Ext.apply( this, config );
	Ext.wg.TemplateGridPanel.superclass.constructor.call(this);
	this.on( 'rowdblclick', this.doEdit );
}

Ext.extend(Ext.wg.TemplateGridPanel, Ext.wg.GridPanelAbstract, {
	itemId: 'template-grid-panel',
	
    initComponent:function() {
        var config = {};
        Ext.apply(this, Ext.apply(this.initialConfig, config));
        Ext.wg.TemplateGridPanel.superclass.initComponent.apply(this, arguments);
    },
	
	doAdd: function( grid, rowIndex, e )	{
        this.doEdit( this, this.item_id, e, 1 )
	},
	
	doEdit: function( grid, rowIndex, e, add )	{
		var item = grid.getStore().getAt(rowIndex);
		var item_id;
		item_id = (item) ? item.id: 0;
		if (add) {
			item_id = 0;
			item = null;
		}
		
		var tabs = Ext.getCmp('site-tabs');
		if( tabs.getComponent('template-tab-' + item_id) ) {
			tabs.setActiveTab('template-tab-' + item_id);
		} else {
			new Ext.LoadMask(Ext.getCmp('site-tabs').getEl(), {
				msg: this.tr('dlgMsgLoading')
			}).show();
			Ext.Ajax.request({
				url: this.actionScript,
				success: function( req, obj ) {
					Ext.getCmp('site-tabs').getEl().unmask();
					var json = Ext.decode( req.responseText );
					
					for( var i = 0; i < json.tpl.length; i++ )	{
						for( var j = 0; j < json.tpl[i].items.length; j++ )	{
							json.tpl[i].items[j].fieldLabel = sitel( json.tpl[i].items[j].fieldLabel );
						}
					}
					
					siteTemplateEditWindow(item, json, grid, add );
					
				},
				failure: function( req, obj ) {
					Ext.getCmp('site-win').getEl().unmask();
					failure_ajax( req, obj )
				},
				params: {
					action: 'site_template_view',
					id: item_id,
					pid: rowIndex
				}
			});
		}
	},
	
	doCopy: function()	{
		var rows = this.getSelectionModel().getSelections();
		
		if( rows.length > 0 )	{
		
			var h = new Array();
			for (i = 0; i < rows.length; i++) {
				h.push( rows[i].id );
			}
			
			Ext.Msg.confirm( 
				this.tr('dlgMsgMessage'),
				this.tr('dlgMsgCopySelected')+'?',
				function(btn) {
					if (btn == 'yes') {
						Ext.Ajax.request({
							url: this.actionScript,
							scope: this,
							success: function() {
								this.store.reload(),
								this.getSelectionModel().deselectRange(0,1000)
							},
							failure: function( req, obj ) {
								failure_ajax( req, obj );
							},
							params: {
								action: 'site_template_copy',
								ids: h.join()
							}
						});
					}
				},
				this
			)
		}
		else	{
			msg( this.tr('dlgMsgNoSelection') );
		}
	},
	
	doRemove: function()	{
		var rows = this.getSelectionModel().getSelections();
		
		if( rows.length > 0 )	{
			var h = new Array();
			for (i = 0; i < rows.length; i++) {
				h.push( rows[i].id );
			}
			
			Ext.Msg.confirm( 
				this.tr('dlgMsgMessage'),
				this.tr('dlgMsgDeleteSelected')+'?',
				function(btn) {
					if (btn == 'yes') {
						
						Ext.Ajax.request({
							url: this.actionScript,
							scope: this,
							success: function() {
								this.store.reload(),
								this.getSelectionModel().deselectRange(0,1000)
							},
							failure: function() {
								failure_ajax( req, obj );
							},
							params: {
								action: 'site_template_delete',
								ids: h.toString()
							}
						});
					}
				},
				this
			)
		}
		else	{
			msg( this.tr('dlgMsgNoSelection') );
		}
	}
})

/*
    TemplateProperties
*/
Ext.wg.TemplateProperties = function( config )	{
	Ext.apply( this, config );
	Ext.wg.TemplateProperties.superclass.constructor.call(this);
}

Ext.extend( Ext.wg.TemplateProperties, Ext.TabPanel, {
	response: {id:0},
	
	initComponent: function()	{
		this.initToolbar();
		var tabs = new Array();
	
		var fields = new Array();
		
		if( this.response.id )	{
			fields.push({
				fieldLabel: this.tr('labelID'),
				value: this.response.id,
				disabled: 'true'
			});
		}
		
		if( this.response.parent_alias || this.new_template )	{
			fields.push({
				fieldLabel: this.tr('labelSite'),
				value: this.response.parent_alias,
				disabled: 'true'
			});
		}
		
		if( this.response.inserted )	{
			fields.push({
				fieldLabel: this.tr('labelInserted'),
				value: this.response.inserted,
				disabled: 'true'
			});
		}
		
		if( this.response.updated )	{
			fields.push({
				fieldLabel: this.tr('labelUpdated'),
				value: this.response.updated,
				disabled: 'true'
			});
		}
		
		if( this.response.name || this.new_template )	{
			fields.push({
				fieldLabel: this.tr('labelName'),
				name: 'name',
				allowBlank: 'false',
				value: this.response.name
			});
		}
		
		this.generalForm = new Ext.form.FormPanel({
			labelWidth: 85,
			url: this.actionScript,
			border: false,
			bodyStyle: 'padding: 5px;',
			forceLayout: true,
			deferredRender: false,
			baseParams: {
				action: 'site_template_update',
				id: this.response.id,
				parent_id: this.response.parent_id
			},
			defaults: { width: '100%' },
			defaultType: 'textfield',
			items: fields
		});
		
		
		this.contentForm = new Ext.form.FormPanel({
			labelWidth: 85,
			border: false,
			forceLayout: true,
			deferredRender: false,
			defaults: { width: '100%' },
			layout:'fit',
			items: {
				xtype: 'tabpanel',
				itemId: 'tabpanel',
				activeTab: 0,
				width: '100%',
				deferredRender: false,
				forceLayout: true,
				border: false,
				defaults: {
					width: '100%'
				},
				items: this.response.tpl
			}
		});
		
		tabs.push( {
			title: this.tr('tabGeneralTitle'),
			layout: 'fit',
			border: false,
			forceLayout: true,
			deferredRender: false,
			items: this.generalForm
		});
		tabs.push( {
			title: this.tr('tabContentTitle'),
			layout: 'fit',
			border: false,
			forceLayout: true,
			deferredRender: false,
			defaults: {
				width: '100%'
			},
			items: this.contentForm
		});
			
		Ext.apply(this, {
			activeTab: 0,
			border: false,
			items: tabs,
			stateEvents:['tabchange'],
    		deferredRender: false,
			forceLayout: true,
    		autoScroll: true,
			stateId: 'template-view-tab',
    		getState:function() {
    			return {
    				activeTab:this.items.indexOf(this.getActiveTab())
    			};
    		}
		});
		
		Ext.wg.TemplateProperties.superclass.initComponent.apply(this, arguments);	
	},
	
	tr: function( lbl )  {
        return ( defined(this.l10n) && defined( this.l10n[lbl] ) ) ? this.l10n[lbl] : lbl;
    },
	
	initToolbar: function()	{
		var b = new Array();
		if( ! defined( this.new_template ) )	{
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
		this.tbar = new Ext.Toolbar( b );
	},
	
	doReload: function()	{
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

				if( defined( this.contentForm ) )	{
					var c = this.contentForm.getComponent('tabpanel');
					for( var i = 0; i < obj.tpl.length; i++ )	{
						for( var j = 0; j < obj.tpl[i].items.length; j++ )	{
							c.getComponent( obj.tpl[i].itemId ).getComponent( obj.tpl[i].items[j].itemId ).setValue(
								obj.tpl[i].items[j].value
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
				action: 'site_template_view',
				id: this.response.id
			}
		});
	},
	
	doSave: function()	{
		new Ext.LoadMask( this.getEl(), { msg: this.tr('dlgMsgLoading') } ).show();
		var form = this.generalForm.getForm();
		
		var params = {};		
		if( defined( this.contentForm ) )	{
			Ext.apply( params, this.contentForm.getForm().getValues() );
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
		
				if( defined( this.response.new_template ) )	{
					Ext.getCmp(this.module+ 'template-tab-0').destroy();
					warn('new')
				}
				
				if( defined( Ext.getCmp('site-template-list') ) )	{
					Ext.getCmp('site-template-list').getComponent('template-grid-panel').store.reload();
				}
			}
		});
	}
});


function siteTemplateEditWindow(item, json, grid, add ) {
	Ext.form.Field.prototype.msgTarget = 'side';
	var item_id;
	item_id = (item) ? item.id: 0;

	var title = sitel('tabNoNameTitle');
	if (item_id) {
		title = item.get('alias');
		if (item.get('alias').length > 0) {
			title = item.get('alias');
		} else {
			title = item.get('id');
		}
	}

	Ext.getCmp('site-tabs').add({
		title: title,
		itemId: 'template-tab-' + json.id,
		//tabTip: tabTip,
		
		items: new Ext.wg.TemplateProperties( {
			response: json,
			actionScript: siteModulePath + '/template.cgi',
			l10n: siteLang,
            new_template: add
		}),
		
		iconCls: 'wg-toolbar-template',
		closable: true,
		//height: '100%',
		autoHeigh: true,
		border: false,
		autoScroll: true,
		layout: 'fit'
	}).show();	
}




//------------------------------------------------------------------
// 	DOMAINS 
//------------------------------------------------------------------

function siteDomainPanel( item ) {
	var tabs = Ext.getCmp('site-tabs');
	if (tabs.items.get('site-domains-list') ) {
		tabs.setActiveTab('site-domains-list');
	} else {
		tabs.add({
			title: sitel('tabSiteDomainsTitle'),
			id: 'site-domains-list',
			items: [
				new Ext.wg.DomainGrid({
					l10n: siteLang,
					buttonAdd: true,
					buttonDel: true,
                    enablePaging: false,
					actionScript: siteModulePath + '/domain.cgi',
					storeAction: 'site_domain_list',
					item_id: item.id
				})
			],
			iconCls: 'wg-toolbar-domain',
			closable: true,
			//height: '100%',
			border: false,
			autoHeigh: true,
			autoScroll: true,
			layout: 'fit'
		}).show();
	}
}

/*
    DomainGrid
*/
Ext.wg.DomainGrid = function(config){
	Ext.apply( this, config );
	Ext.wg.DomainGrid.superclass.constructor.call(this);
	this.on( 'rowdblclick', this.doEdit );
}

Ext.extend(Ext.wg.DomainGrid, Ext.wg.GridPanelAbstract, {
	itemId: 'domain-grid',
	
    initComponent:function() {
        Ext.wg.DomainGrid.superclass.initComponent.apply(this, arguments);
    },
	
	doAdd: function( grid, rowIndex, e )	{
        warn(this.store.getRange() );
        if( ! this.store.getById(0) ) {
            this.store.add( new Ext.data.Record( {id:0, name:'unnamed.domain'}, {id:0} ) );
        }
	},
	
	doEdit: function( grid, rowIndex, e, add )	{
		var item = grid.getStore().getAt(rowIndex);
		var item_id;
		item_id = (item) ? item.id: 0;
		if (add) {
			item_id = 0;
			item = null;
		}
		
		var tabs = Ext.getCmp('site-tabs');
		if( tabs.getComponent('template-tab-' + item_id) ) {
			tabs.setActiveTab('template-tab-' + item_id);
		} else {
			new Ext.LoadMask(Ext.getCmp('site-tabs').getEl(), {
				msg: this.tr('dlgMsgLoading')
			}).show();
			Ext.Ajax.request({
				url: this.actionScript,
				success: function( req, obj ) {
					Ext.getCmp('site-tabs').getEl().unmask();
					var json = Ext.decode( req.responseText );
					
					for( var i = 0; i < json.tpl.length; i++ )	{
						for( var j = 0; j < json.tpl[i].items.length; j++ )	{
							json.tpl[i].items[j].fieldLabel = sitel( json.tpl[i].items[j].fieldLabel );
						}
					}
					
					siteTemplateEditWindow(item, json, grid, add );
					
				},
				failure: function( req, obj ) {
					Ext.getCmp('site-win').getEl().unmask();
					failure_ajax( req, obj )
				},
				params: {
					action: 'site_template_view',
					id: item_id,
					pid: rowIndex
				}
			});
		}
	},
		
	doRemove: function()	{
		var rows = this.getSelectionModel().getSelections();
		
		if( rows.length > 0 )	{
			var h = new Array();
			for (i = 0; i < rows.length; i++) {
				h.push( rows[i].id );
			}
			
			Ext.Msg.confirm( 
				this.tr('dlgMsgMessage'),
				this.tr('dlgMsgDeleteSelected')+'?',
				function(btn) {
					if (btn == 'yes') {
						
						Ext.Ajax.request({
							url: this.actionScript,
							scope: this,
							success: function() {
								this.store.reload(),
								this.getSelectionModel().deselectRange(0,1000)
							},
							failure: function() {
								failure_ajax( req, obj );
							},
							params: {
								action: 'site_template_delete',
								ids: h.toString()
							}
						});
					}
				},
				this
			)
		}
		else	{
			msg( this.tr('dlgMsgNoSelection') );
		}
	}
})



function siteDomainContext(item) {
	var grid = siteDomainGridPanel(item.id);
	var win = new Ext.Window({
		title: siteLang['tabTitleSiteDomains'] + ' "' + item.text + '"',
		closable: true,
		width: 600,
		height: 350,
		items: [grid],
		tbar: [{
			text: siteLang['tabButtonAddText'],
			tooltip: siteLang['tabButtonAddTemplateToolTip'],
			iconCls: 'add',
			handler: function() {
				siteDomainEdit(grid, item.id, null, 1)
			}
		},
		{
			text: siteLang['tabButtonDelText'],
			tooltip: siteLang['tabButtonDelTemplateToolTip'],
			iconCls: 'remove',
			handler: function() {
				Ext.Msg.confirm(siteLang['dlgTitleDeleteTemplate'], siteLang['dlgMsgDeleteTemplate'],
				function(btn) {
					if (btn == 'yes') {
						siteDomainDelete(item.id, item.text, grid)
					}
				})
			}
		},
		'-', {
			text: siteLang['tabButtonRefreshText'],
			tooltip: siteLang['tabButtonRefreshToolTip'],
			iconCls: 'reload',
			handler: function() {
				grid.getStore().reload()
			}
		}],
		autoScroll: true
	});
	win.show();
}

function siteDomainGridPanel(pid) {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		store: siteDomainGridStore(pid),
		cm: siteDomainGridColumnModel(),
		autoHeight: true,
		autoScroll: true,
		enableDragDrop: true,
		loadMask: true,
		viewConfig: {
			forceFit: true
		}
	});
	return (grid);
}

function siteDomainGridStore(pid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: siteModulePath + '/category.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		remoteSort: true,
		baseParams: {
			action: 'site_domain_list',
			pid: pid
		}
	});

	//store.setDefaultSort('ordering', 'desc');
	store.load({
		params: {
			start: 0,
			limit: sitePerPage,
			pid: pid
		}
	});
	return (store);
}

function siteDomainGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: siteLang['labelID'],
		dataIndex: 'id',
		width: 20
	},
	{
		header: siteLang['labelAlias'],
		dataIndex: 'alias',
		width: 200
	}]);

	//cm.defaultSortable = true;
	return (cm);
}

function siteDomainEdit(grid, rowIndex, e, add) {
	var item = grid.getStore().getAt(rowIndex);
	var item_id;
	item_id = (item) ? item.id: 0;
	if (add) {
		item_id = 0;
		item = null;
	}

	Ext.Ajax.request({
		url: siteModulePath + '/category.cgi',
		success: function(req) {
			var tt = 'json = ' + req.responseText;
			eval(tt);
			siteDomainEditWindow(item, json, grid);
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'site_domain_view',
			id: item_id,
			pid: rowIndex
		}
	});
}

function siteDomainEditWindow(item, json, grid) {
	Ext.form.Field.prototype.msgTarget = 'side';
	var item_id;
	item_id = (item) ? item.id: 0;
	var form = new Ext.FormPanel({
		labelWidth: 85,
		url: siteModulePath + '/category.cgi',
		border: false,
		bodyStyle: 'padding: 0',
		width: '100%',
		defaults: {
			width: '100%'
		},
		defaultType: 'textfield',
		autoHeight: true,
		id: 'site_domain_edit_form',
		items: {
			xtype: 'tabpanel',
			activeTab: 0,
			id: 'site_domain_tabs_' + item_id,
			defaults: {
				autoHeight: true,
				bodyStyle: 'padding:5px',
				width: '500'
			},
			items: [{
				title: siteLang['tabTitleGeneral'],
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				id: 'site_domain_common_' + item_id,
				items: [{
					inputType: 'hidden',
					name: 'action',
					value: 'site_domain_update'
				},
				{
					inputType: 'hidden',
					name: 'parent_id',
					value: json.parent_id
				},
				{
					inputType: 'hidden',
					name: 'id',
					value: json.id
				},
				{
					fieldLabel: siteLang['labelSite'],
					value: json.parent_alias,
					disabled: 'true'
				},
				{
					fieldLabel: siteLang['labelName'],
					name: 'name',
					allowBlank: 'false',
					value: json.name
				}]
			}

			]
		},
		buttons: [{
			text: siteLang['formButtonSave'],
			handler: function() {
				form.getForm().submit({
					waitMsg: siteLang['dlgMsgSaving'],
					success: function() {
						win.destroy();
						grid.getStore().reload()
					}
				});
			}
		},
		{
			text: siteLang['formButtonRefresh'],
			handler: function() {
				form.getForm().submit({
					waitMsg: siteLang['dlgMsgSaving'],
					success: function() {
						grid.getStore().reload()
					}
				});
			}
		},
		{
			text: siteLang['formButtonCancel'],
			handler: function() {
				win.destroy();
			}
		}]
	});

	var title = siteLang['tabTitleNoName'];
	if (item_id) {
		title = item.get('alias');
		if (item.get('alias').length > 0) {
			title = item.get('alias');
		} else {
			title = item.get('id');
		}
	}

	var win = new Ext.Window({
		title: siteLang['tabTitleDomain'] + ' "' + title + '"',
		closable: true,
		width: 700,
		height: 400,
		autoScroll: true,
		items: [form]
	});

	win.show();
}




