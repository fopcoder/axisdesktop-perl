//<!--
var configurationModulePath = '/cgi-bin/wg/modules/configuration';
var configurationPerPage = 50;

function configurationl(msg) {
	return l('configuration', msg);
}

AxisDesktop.configurationModule = Ext.extend(Ext.app.Module, {
	id: 'store-configuration',
	type: 'store/configuration',

	init: function() {
		//this.locale = QoDesk.AccordionWindow.Locale;
	},
	createWindow: function() {
		var desktop = this.app.getDesktop();
		var win = desktop.getWindow('configuration-win');
		if (!win) {
			win = desktop.createWindow({
				id: 'configuration-win',
				title: configurationl('titleMainWindow'),
				width: 840,
				height: 500,
				iconCls: 'configuration-main-window',
				shim: false,
				animCollapse: false,
				border: false,
				constrainHeader: true,
				layout: 'border',
				items: [this.createTabPanel(), this.createTreePanel()]
			});
		}

		win.show();
	},
	createTabPanel: function() {
		return new Ext.TabPanel({
			id: 'configuration-tabs',
			activeTab: 0,
			region: 'center',
			enableTabScroll: true
		})
	},
	createTreePanel: function() {
		var p = new Ext.tree.TreePanel({
			animate: false,
			id: 'configurationTree',
			title: configurationl('labelClasses'),
			collapsible: true,
			enableDD: false,
			containerScroll: true,
			rootVisible: true,
			width: '250',
			split: true,
			autoScroll: true,
			margins: '0 0 3 1',
			loader: this.createTreeLoader(),
			root: this.createTreeRootNode(),
			region: 'west',
			tbar: this.createTreeToolBar()
		});
		p.on('click', this.onTreeClick);
		return p;
	},
	createTreeLoader: function() {
		return new Ext.tree.TreeLoader({
			dataUrl: configurationModulePath + '/category.cgi',
			baseParams: {
				action: 'configuration_category_list'
			}
		})
	},
	createTreeRootNode: function() {
		return new Ext.tree.AsyncTreeNode({
			text: configurationl('treeRootNodeAlias'),
			draggable: false,
			allowDrag: false,
			allowDrop: false,
			expanded: true,
			id: '0'
		});
	},
	createTreeToolBar: function() {
		return new Ext.Toolbar({
			id: 'configurationTreeToolBar',
			items: [
            {
				iconCls: 'icon-reload-all',
				tooltip: configurationl('treeButtonRefreshToolTip'),
				handler: function() {
					Ext.getCmp('configurationTree').root.reload();
                }
			},'-',
            {
				iconCls: 'icon-expand-all',
				tooltip: configurationl('treeButtonExpandToolTip'),
				handler: function() {
					Ext.getCmp('configurationTree').root.expand(true);
				}
			},
			'-', {
				iconCls: 'icon-collapse-all',
				tooltip: configurationl('treeButtonCollapseToolTip'),
				handler: function() {
					Ext.getCmp('configurationTree').root.collapse(true);
				}
			},'-',
			{
				iconCls: 'wg-toolbar-package',
				tooltip: configurationl('labelModules'),
				handler: function() {
					configurationAllPackages();
					//Ext.getCmp('configurationTree').root.collapse(true);
				}
			}
			]
		});
	},
	onTreeClick: function(item, e) {
		var tabs = Ext.getCmp('configuration-tabs');
		if (tabs.items.get('configuration_tab_' + item.id)) {
			tabs.setActiveTab('configuration_tab_' + item.id);
		} else {
			var grid = configurationItemGridPanel(item.id);
			tabs.add({
				title: item.text.substring(0, 30),
				id: 'configuration_tab_' + item.id,
				tabTip: item.parentNode.text + ' / ' + item.text,
				bbar: new Ext.PagingToolbar({
					pageSize: configurationPerPage,
					id: 'configuration-item-grid-bbar-' + item.id,
					store: grid.store,
					displayInfo: true,
					displayMsg: configurationl('dlgMsgTopics'),
                    afterPageText: configurationl('dlgMsgAfterPage'),
                    beforePageText: configurationl('dlgMsgBeforePage'),
                    nextText: configurationl('dlgMsgNextText'),
                    prevText: configurationl('dlgMsgPrevText'),
                    firstText: configurationl('dlgMsgFirstText'),
                    lastText: configurationl('dlgMsgLastText'),
                    refreshText: configurationl('dlgMsgRefreshText'),
					emptyMsg: configurationl('dlgMsgNoTopics')
				}),
				tbar: [
				{
					text: configurationl('tabButtonRefreshText'),
					tooltip: configurationl('tabButtonRefreshToolTip'),
					iconCls: 'wg-toolbar-reload',
					handler: function() {
						grid.getStore().reload()
					}
				}
				],
				items: [grid],
				iconCls: 'wg-tab-folder',
				closable: true,
				height: '100%',
				autoHeigh: true,
				autoScroll: true,
				layout: 'fit'
			}).show();

			var ddrow = new Ext.dd.DropTarget(grid.getView().mainBody, {
				ddGroup: 'configurationGridDD',
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
					if (!this.copy) {
						for (i = 0; i < rows.length; i++) {
							ds.remove(ds.getById(rows[i].id));
						};
					};
					ds.insert(cindex, data.selections);
					sm.selectRecords(rows);
				}
			});
		}
	}
});


function configurationAllPackages() {
	var tabs = Ext.getCmp('configuration-tabs');
	if( tabs.items.get('configuration-tab-all-packages') ) {
		tabs.setActiveTab( 'configuration-tab-all-packages' );
	} else {
		var grid = configurationAllPackagesGridPanel();
		tabs.add({
			title: configurationl('tabTitleModules'),
			id: 'configuration-tab-all-packages',
			iconCls: 'wg-tab-package',
			//tabTip: item.parentNode.text + ' / ' + item.text,
			bbar: new Ext.PagingToolbar({
				pageSize: configurationPerPage,
				id: 'configuration-all-packets-grid-bbar',
				store: grid.store,
				displayInfo: true,
				displayMsg: configurationl('dlgMsgTopics'),
				afterPageText: configurationl('dlgMsgAfterPage'),
				beforePageText: configurationl('dlgMsgBeforePage'),
				nextText: configurationl('dlgMsgNextText'),
				prevText: configurationl('dlgMsgPrevText'),
				firstText: configurationl('dlgMsgFirstText'),
				lastText: configurationl('dlgMsgLastText'),
				refreshText: configurationl('dlgMsgRefreshText'),
				emptyMsg: configurationl('dlgMsgNoTopics')
			}),
			tbar: [
			{
				text: configurationl('tabButtonRefreshText'),
				tooltip: configurationl('tabButtonRefreshToolTip'),
				iconCls: 'wg-toolbar-reload',
				handler: function() {
					grid.getStore().reload()
				}
			}
			],
			items: [grid],
			closable: true,
			height: '100%',
			autoHeigh: true,
			autoScroll: true,
			layout: 'fit'
		}).show();
	}
}

function configurationAllPackagesGridPanel() {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		cm: configurationAllPackagesGridColumnModel(),
		autoScroll: true,
		loadMask: true,
		id: 'configuration-all-packages-grid',
		viewConfig: {
			forceFit: true
		}
	});

	var store = configurationAllPackagesGridStore();

	grid.store = store;
	grid.on('rowdblclick', function(grid,rowIndex,item) { 
		Ext.Msg.confirm( configurationl('update?'),configurationl('update?'), function(btn){ 
			if(btn == 'yes'){ configurationModuleUpdate(grid,rowIndex,item,0) }
		} ) 
	} ); 
	return (grid);
}

function configurationModuleUpdate(grid,rowIndex,e,add) 	{
    var item = grid.getStore().getAt(rowIndex);
    var item_id;
	//alert( item.get('name')+' '+item.get('version')+': '+item.get('file') );
    Ext.Ajax.request({
	url: configurationModulePath + '/item.cgi'
	,success: function(req){ 
	    //var tt = 'json = '+req.responseText;
	    //eval( tt );
	    //baseFieldEditWindow( item, json, grid );
		grid.getStore().reload();
	}
	,failure: function(){ alert('failure') }
	,params: { action: 'configuration_modules_update', file: item.get('file'), name:item.get('name'), version:item.get('version')  }
    });
}

function configurationAllPackagesGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([
		{
			header: configurationl('labelName')
			,dataIndex: 'name'
			,width: 200
		}
		,{
			header: configurationl('labelVersion')
			,dataIndex: 'version'
			,width: 200
		}
		,{
			header: configurationl('labelUpdate')
			,dataIndex: 'update'
			,width: 200
		}
    ]);
	cm.defaultSortable = true;

	return( cm );
}

function configurationAllPackagesGridStore() {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: configurationModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'configuration_all_packages'
		},
		remoteSort: true
	});

	store.load({
		params: {
			start: 0,
			limit: 1000
		}
	});
	return (store);
}




//-------------------------------------------------------------
//    configuration ITEM
//-------------------------------------------------------------

function configurationItemGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: configurationl('labelID'),
		dataIndex: 'id',
		width: 50
	}]);

	cm.defaultSortable = true;
	return (cm);
}

function configurationItemGridStore(pid, grid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: configurationModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'configuration_item_list'
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
				column.header = configurationl(column.header);
				columns.push(column);
			});
			if (grid) grid.getColumnModel().setConfig(columns);
			//Ext.getCmp('configuration-item-grid-bbar-'+pid).store = grid.store;
		}
		//this.el.unmask();
	});

	store.load({
		params: {
			start: 0,
			limit: configurationPerPage,
			pid: pid
		}
	});
	return (store);
}

function configurationItemGridPanel(pid, rows) {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		cm: configurationItemGridColumnModel(),
		ddGroup: 'configurationGridDD',
		autoScroll: true,
		enableDragDrop: true,
		loadMask: true,
		id: 'configuration_item_grid_' + pid,
		viewConfig: {
			forceFit: true
		}
	});

	var store = configurationItemGridStore(pid, grid);

	grid.store = store;
	grid.on('rowdblclick', configurationItemGridOnRowDblClick);
	return (grid);
}

function configurationItemGridOnRowDblClick(grid, rowIndex, e) {
	var tabs = Ext.getCmp('configuration-tabs');
	var record = grid.getStore().getAt(rowIndex);

	if (tabs.items.get('configuration_item_tab_' + record.id) ) {
		tabs.setActiveTab('configuration_item_tab_' + record.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('configuration-win').getEl(), {
			msg: configurationl('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: configurationModulePath + '/item.cgi',
			success: function(req) {
				Ext.getCmp('configuration-win').getEl().unmask();
				var obj;
				var tt = 'obj = ' + req.responseText;
				eval(tt);
				configurationItemTab(record, obj);
			},
			failure: function() {
				Ext.getCmp('configuration-win').getEl().unmask();
				alert('failure');
			},
			params: {
				action: 'configuration_item_view',
				id: record.id
			}
		});
	}
}

function configurationItemTab(record, obj) {
	var simple = new Ext.FormPanel({
		labelWidth: 85,
		url: configurationModulePath + '/item.cgi',
		border: false,
		bodyStyle: 'padding: 0',
		width: '100%',
		defaults: {
			width: '100%'
		},
		defaultType: 'textfield',
		autoHeight: true,
		items: {
			xtype: 'tabpanel',
			activeTab: 0,
			defaults: {
				autoHeight: true,
				bodyStyle: 'padding:10px',
				width: '500'
			},
			items: [
                {
				title: configurationl('tabTitleGeneral'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: [{
					fieldLabel: configurationl('labelID'),
					name: 'id',
					value: obj.id,
					readOnly: 'true'
				},
				{
					fieldLabel: configurationl('labelClass'),
					value: obj.type,
					disabled: 'true'
				},
				
				{
					fieldLabel: configurationl('labelInserted'),
					name: 'inserted',
					value: obj.inserted,
					disabled: 'true'
				},
				{
					fieldLabel: configurationl('labelName'),
					name: 'name',
                    disabled: 'true',
					value: obj.name
				},
                {
					fieldLabel: configurationl('labelModule'),
					value: obj.module,
                    name: 'module'
				},
				{
					fieldLabel: configurationl('labelOrdering'),
					name: 'ordering',
					value: obj.ordering
				},
				{
					fieldLabel: configurationl('labelVersion'),
					name: 'version',
                    disabled: 'true',
					value: obj.version
				},
				{
					fieldLabel: configurationl('labelVersionDate'),
					name: 'version_date',
                    disabled: 'true',
					value: obj.version_date
				}
                ]
			},
			{
				title: configurationl('tabTitleAlias'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: obj.item_aliases
			},
			{
				title: configurationl('tabTitleDescription'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: obj.item_descriptions
			},
            {
				title: configurationl('tabTitleActions'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: obj.item_action_list
			},
			{
				title: configurationl('tabTitleAccess'),
				layout: 'form',
				border: false,
				defaultType: 'textfield',
                items: [ configurationItemAccessGridPanel( obj.id ) ]
			}
            ]
		},
		buttons: [{
			text: configurationl('formButtonSave'),
			handler: function() {
				var gg = Ext.getCmp('configuration_item_access_grid_'+obj.id).getStore().getModifiedRecords();
				var h = new Array();
				for (i = 0; i < gg.length; i++) {
					h[i] = gg[i].data;
				}
				simple.getForm().baseParams = {
					json_access: Ext.encode(h),
					action: 'configuration_item_update'
				};
                alert(Ext.encode(h));
				simple.getForm().submit({
					waitMsg: configurationl('dlgMsgSaving')
				});
			}
		}]
	});

	var title = record.get('alias');
	var tabTip = record.get('alias');
	
	tabTip = obj.type + ' / ' + tabTip;
	title = title.substring(0, 30)

	Ext.getCmp('configuration-tabs').add({
		title: title,
		id: 'configuration_item_tab_' + obj.id,
		tabTip: tabTip,
		items: [simple],
		iconCls: 'wg-tab-file',
		closable: true,
		height: '100%',
		autoHeigh: true,
		autoScroll: true,
		layout: 'fit'
	}).show();

}

var configurationItemCM = new Array();

function configurationItemAccessGridColumnModel(actions) {
	var cm;
	var cols = new Array(
        {
        	header: configurationl('labelGroup'),
            tooltip: configurationl('labelGroup'),
        	dataIndex: 'group'
        },
        {
        	header: configurationl('labelAction'),
            tooltip: configurationl('labelAction'),
        	dataIndex: 'action'
        }
    );
	
	var checkColumn = new Ext.grid.CheckColumn({
			header: configurationl('#'),
			tooltip: configurationl('#'),
			dataIndex: 'value',
			width: 75
	});
	cols.push( checkColumn );
	configurationItemCM[0] = checkColumn;
	
	cm = new Ext.grid.ColumnModel(cols);

	return (cm);
}


function configurationItemAccessGridStore( pid ) {   
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: configurationModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'configuration_access_list'
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

function configurationItemAccessGridPanel(pid) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
        autoHeight: true,
		cm: configurationItemAccessGridColumnModel(),
        store: configurationItemAccessGridStore( pid ),
		autoScroll: true,
		loadMask: true,
        plugins: configurationItemCM,
        clicksToEdit: 1,
		id: 'configuration_item_access_grid_' + pid,
        view: new Ext.grid.GroupingView({
            forceFit:true,
            groupTextTpl: '{text}'
        }),
		viewConfig: {
			forceFit: true
		}
	});

	return (grid);
}


//=========================================

//Ext.grid.CheckColumn = function(config) {
//	Ext.apply(this, config);
//	if (!this.id) {
//		this.id = Ext.id();
//	}
//	this.renderer = this.renderer.createDelegate(this);
//};
//
//Ext.grid.CheckColumn.prototype = {
//	init: function(grid) {
//		this.grid = grid;
//		this.grid.on('render',
//		function() {
//			var view = this.grid.getView();
//			view.mainBody.on('mousedown', this.onMouseDown, this);
//		},
//		this);
//	},
//
//	onMouseDown: function(e, t) {
//		if (t.className && t.className.indexOf('x-grid3-cc-' + this.id) != -1) {
//			e.stopEvent();
//			var index = this.grid.getView().findRowIndex(t);
//			var record = this.grid.store.getAt(index);
//			record.set(this.dataIndex, !record.data[this.dataIndex]);
//		}
//	},
//
//	renderer: function(v, p, record) {
//		p.css += ' x-grid3-check-col-td';
//		return '<div class="x-grid3-check-col' + (v ? '-on': '') + ' x-grid3-cc-' + this.id + '">&#160;</div>';
//	}
//};


//-->
