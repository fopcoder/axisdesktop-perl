//<!--
var articleModulePath = '/cgi-bin/wg/modules/article';
var articlePerPage = 50;

function articlel(msg) {
	return l('article', msg);
}

AxisDesktop.articleModule = Ext.extend(Ext.app.Module, {
	id:'store-article',
    type: 'store/article',

	init: function() {
		//this.locale = QoDesk.AccordionWindow.Locale;
	},
	createWindow: function() {
		var desktop = this.app.getDesktop();
		var win = desktop.getWindow('article-win');
		if (!win) {
			win = desktop.createWindow({
				id: 'article-win',
				title: articlel('titleMainWindow'),
				width: 840,
				height: 500,
				iconCls: 'article-main-window',
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
			id: 'article-tabs',
			activeTab: 0,
			region: 'center',
			enableTabScroll: true
		})
	},
	createTreePanel: function() {
		var p = new Ext.tree.TreePanel({
			animate: false,
			id: 'articleTree',
			title: articlel('labelRubrics'),
			collapsible: true,
			enableDD: true,
			ddGroup: 'articleGridDD',
			enableDrop: true,
			containerScroll: true,
			rootVisible: true,
			width: '250',
			split: true,
			autoScroll: true,
			margins: '0 0 3 1',
			loader: this.createTreeLoader(),
			root: this.createTreeRootNode(),
			region: 'west',
			tbar: this.createTreeToolBar(),
			bbar: this.createTreeToolBarBottom(),
			contextMenu: articleCategoriesContextMenu(),
			listeners: {
				contextmenu: function(node, e) {
					node.select();
					var c = node.getOwnerTree().contextMenu;
					c.contextNode = node;
					c.showAt(e.getXY());
				}
			}
			,plugins:[new Ext.ux.state.TreePanel()]
		});
		p.on('click', this.onTreeClick);
		p.on('beforenodedrop', this.onTreeBeforeNodeDrop);
		return p;
	},
	createTreeLoader: function() {
		return new Ext.tree.TreeLoader({
			dataUrl: articleModulePath + '/category.cgi',
			baseParams: {
				action: 'article_category_list'
			}
		})
	},
	createTreeRootNode: function() {
		return new Ext.tree.AsyncTreeNode({
			text: articlel('treeRootNodeAlias'),
			draggable: false,
			allowDrag: false,
			allowDrop: true,
			expanded: true,
			id: '0'
		});
	},
	createTreeToolBar: function() {
		return new Ext.Toolbar({
			id: 'articleTreeToolBar',
			items: [{
				iconCls: 'icon-expand-all',
				tooltip: articlel('treeButtonExpandToolTip'),
				handler: function() {
					Ext.getCmp('articleTree').root.expand(true);
				}
			},
			'-', {
				iconCls: 'icon-collapse-all',
				tooltip: articlel('treeButtonCollapseToolTip'),
				handler: function() {
					Ext.getCmp('articleTree').root.collapse(true);
				}
			},
			'-', {
				iconCls: 'icon-reload-all',
				tooltip: articlel('treeButtonRefreshToolTip'),
				handler: function() {
					Ext.getCmp('articleTree').root.reload();
				}
			}]
		});
	},
	createTreeToolBarBottom: function() {
		return new Ext.Toolbar({
			id: 'articleTreeToolBarBottom',
			items: [new Ext.form.TextField({
				width: '100%',
				enableKeyEvents: true
			})]
		});
	},
	onTreeClick: function(item, e) {
		var tabs = Ext.getCmp('article-tabs');
		if (tabs.items.get('article_tab_' + item.id)) {
			tabs.setActiveTab('article_tab_' + item.id);
		} else {
			var grid = articleItemGridPanel(item.id);
			tabs.add({
				title: item.text.substring(0, 30),
				id: 'article_tab_' + item.id,
				tabTip: item.parentNode.text + ' / ' + item.text,
				bbar: new Ext.PagingToolbar({
					pageSize: articlePerPage,
					id: 'article-item-grid-bbar-' + item.id,
					store: grid.store,
					displayInfo: true,
					displayMsg: articlel('dlgMsgTopics'),
				afterPageText: articlel('dlgMsgAfterPage'),
				beforePageText: articlel('dlgMsgBeforePage'),
				nextText: articlel('dlgMsgNextText'),
				prevText: articlel('dlgMsgPrevText'),
				firstText: articlel('dlgMsgFirstText'),
				lastText: articlel('dlgMsgLastText'),
				refreshText: articlel('dlgMsgRefreshText'),
				emptyMsg: articlel('dlgMsgNoTopics')
				}),
				tbar: [
				{
					text: articlel('tabButtonRefresh'),
					tooltip: articlel('tabButtonRefreshToolTip'),
					iconCls: 'wg-toolbar-reload',
					handler: function() {
						grid.getStore().reload()
					}
				},'-',
				{
					text: articlel('tabButtonAdd'),
					tooltip: articlel('tabButtonAddToolTip'),
					iconCls: 'wg-toolbar-add',
					handler: function() {
						articleItemAdd(item.id, item.text, grid)
					}
				},
				'-', {
					text: articlel('tabButtonCopy'),
					tooltip: articlel('tabButtonCopyToolTip'),
					iconCls: 'wg-toolbar-copy',
					handler: function() {
						articleItemCopy(grid)
					}
				},
				'-', {
					text: articlel('tabButtonDel'),
					tooltip: articlel('tabButtonDelToolTip'),
					iconCls: 'wg-toolbar-del',
					handler: function() {
						Ext.Msg.confirm(articlel('dlgTitleDeleteItem'), articlel('dlgMsgDeleteItem'),
						function(btn) {
							if (btn == 'yes') {
								articleItemDelete(item.id, item.text, grid)
							}
						})
					}
				}
				],
				items: [grid],
				iconCls: 'wg-tab-folder',
				closable: true,
				//height: '100%',
				autoHeigh: true,
				autoScroll: true,
				layout: 'fit'
			}).show();

			var ddrow = new Ext.dd.DropTarget(grid.getView().mainBody, {
				ddGroup: 'articleGridDD',
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
					var h = new Array();
					if (!this.copy) {
						for (i = 0; i < rows.length; i++) {
							//ds.remove(ds.getById(rows[i].id));
							h[i] = rows[i].id;
						};
					};
					//ds.insert(cindex, data.selections);
					//sm.selectRecords(rows);
					Ext.Ajax.request({
						url: articleModulePath + '/item.cgi',
						success: function() {
							ds.reload();
							Ext.getCmp('article-win').getEl().unmask();
						},
						failure: function() {
							Ext.getCmp('article-win').getEl().unmask();
							alert('failure')
						},
						params: {
							action: 'article_item_ordering',
							src: h.join(','),
							dst: ds.getAt(cindex).id,
							pid: item.id
						}
					});
				}
			});
		}
	},
	onTreeBeforeNodeDrop: function(e) {
		new Ext.LoadMask(Ext.getCmp('article-win').getEl(), { msg: articlel('dlgMsgLoading') } ).show();
		
		var s = e.data.selections;
		var a = e.target.id;
		var t = e.source;
		if (s) {
			var w = new Array();
			for (i = 0; i < s.length; i++) {
				w[i] = s[i].id;
			}
			Ext.Ajax.request({
				url: articleModulePath + '/item.cgi',
				success: function() {
					s[0].store.reload();
					Ext.getCmp('article-win').getEl().unmask();
				},
				failure: function() {
					Ext.getCmp('article-win').getEl().unmask();
					alert('failure')
				},
				params: {
					action: 'article_item_move',
					src: w.join(','),
					dst: a
				}
			});
		}
		else	{
			Ext.Ajax.request({
				url: articleModulePath + '/category.cgi',
				success: function() {
					if (e.point == 'append') {
						e.target.reload();
					} else {
						e.target.parentNode.reload();
					}
					Ext.getCmp('article-win').getEl().unmask();
				},
				failure: function() {
					Ext.getCmp('article-win').getEl().unmask();
					alert('failure')
				},
				params: {
					action: 'article_category_move',
					src: e.dropNode.id,
					dst: e.target.id,
					point: e.point
				}
			});
		}
	}
});

//------------------------------------------------------
//      article CATEGORIES
//------------------------------------------------------

function articleCategoriesContextMenu() {
	if( Ext.getCmp('article-categories-context-menu') )	{
		return Ext.getCmp('article-categories-context-menu');
	}
	else {
		var m = new Ext.menu.Menu({
			id: 'article-categories-context-menu',
			items: [
			{
				id: 'ac-cm-refresh',
				text: articlel('labelRefresh'),
				iconCls: 'wg-toolbar-reload'
			},
			{
				id: 'ac-cm-properties',
				text: articlel('labelProperties'),
				iconCls: 'wg-toolbar-properties'
			},
			{
				id: 'ac-cm-field-groups',
				text: articlel('labelFieldGroups'),
				iconCls: 'wg-toolbar-field-groups'
			},
			{
				id: 'ac-cm-add',
				iconCls: 'wg-toolbar-add',
				text: articlel('labelAdd')
			},
			{
				id: 'ac-cm-copy',
				iconCls: 'wg-toolbar-copy',
				text: articlel('labelCopy')
			},
			{
				id: 'ac-cm-delete',
				iconCls: 'wg-toolbar-del',
				text: articlel('labelDelete')
			}],
			listeners: {
				itemclick: function(item) {
					var n = item.parentMenu.contextNode;

					switch (item.id) {
					case 'ac-cm-refresh':
						n.reload();
						break;
					case 'ac-cm-properties':
						articleCategoryView(n,0);
						break;
					case 'ac-cm-add':
						articleCategoryView(n,1);
						break;
					case 'ac-cm-copy':
						articleCategoryCopy(n);
						break;
					case 'ac-cm-field-groups':
						articleFieldGroupTab(n);
						break;
					case 'ac-cm-delete':
						if (confirm(articlel('labelDelete') + '?')) {
							articleCategoryDel( n );
						}
						break;
					}
				}
			}
		})

		return m;
	}
}	

function articleCategoryDel( node )	{
	Ext.Ajax.request({
		url: articleModulePath + '/category.cgi',
		success: function(req) {
			if(node.parentNode) node.parentNode.reload();
		},
		failure: function() {
			alert('failure');
		},
		params: {
			action: 'article_category_delete',
			id: node.id
		}
	});
}


function articleCategoryView(node, add) {
	var tabs = Ext.getCmp('article-tabs');
	if (tabs.items.get('article-category-view-tab-' + node.id) && !add) {
		tabs.setActiveTab('article-category-view-tab-' + node.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('article-tabs').getEl(), {
			msg: articlel('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: articleModulePath + '/category.cgi',
			success: function(req) {
				Ext.getCmp('article-tabs').getEl().unmask();
				var obj;
				eval('obj = ' + req.responseText);
				for( var i = 0; i < obj.l10n.items.length; i++ )	{
					for( var j = 0; j < obj.l10n.items[i].items.length; j++ )	{
						obj.l10n.items[i].items[j].fieldLabel = articlel( obj.l10n.items[i].items[j].fieldLabel );
					}
				}
				for( var i = 0; i < obj.flags.length; i++ )	{
						obj.flags[i].fieldLabel = articlel( obj.flags[i].fieldLabel);
				}
				articleCategoryViewTab(node, obj, add);
			},
			failure: function() {
				Ext.getCmp('article-tabs').getEl().unmask();
				alert('failure');
			},
			params: {
				action: 'article_category_view',
				id: node.id,
				add: add
			}
		});
	}
}

function articleCategoryViewTab(node, obj, add) {
	var simple = new Ext.FormPanel({
		labelWidth: 85,
		url: articleModulePath + '/category.cgi',
		border: false,
		bodyStyle: 'padding: 0;',
		width: '100%',
		forceLayout: true,
		id: 'article-category-view-form-'+obj.id,
		defaults: {
			width: '100%'
		},
		defaultType: 'textfield',
		autoHeight: true,
		items: {
			xtype: 'tabpanel',
			id: 'article-category-view-tab-form-tabpanel-'+obj.id,
			stateEvents:['tabchange'],
			border: false,
			activeTab: 0,
			deferredRender: false,
			getState:function() {
				return {
					activeTab:this.items.indexOf(this.getActiveTab())
				};
			},
			defaults: {
				autoHeight: true,
				bodyStyle: 'padding:10px',
				width: '500',
				border: false
			},
			items: [{
				title: articlel('tabTitleGeneral'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: [{
					fieldLabel: articlel('labelID'),
					name: 'id',
					value: obj.id,
					readOnly: 'true'
				},
				{
					fieldLabel: articlel('labelParent'),
					value: obj.parent_name + ' [' + obj.parent_id + ']',
					readOnly: 'true'
				},
				{
					fieldLabel: articlel('labelInserted'),
					name: 'inserted',
					value: obj.inserted,
					disabled: 'true'
				},
				{
					fieldLabel: articlel('labelUpdated'),
					name: 'updated',
					value: obj.updated,
					disabled: 'true'
				},
				{
					fieldLabel: articlel('labelName'),
					name: 'name',
					allowBlank: 'false',
					value: obj.name
				}
				]
			},
			{
				title: articlel('tabTitleLocalization'),
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
				title: articlel('tabTitleAccess'),
				layout: 'form',
				border: false,
				defaultType: 'textfield',
				autoHeight:true,
				bodyStyle: 'padding: 0',
                items: [ articleCategoryAccessGridPanel( obj.id ) ]
			},
			{
				title: articlel('tabTitleOptions'),
				layout: 'form',
				defaults: {
					width: 230
				},
				defaultType: 'textfield',
				items: obj.flags
			}]
		}
	});

	var title;
	var tabTip;
	var tabButtons;
	var parentNodeText;
	
	if( ! node.parentNode )	{
		parentNodeText = articlel('treeRootNodeAlias');
	}
	else	{
		parentNodeText = node.parentNode.text;
	}
	
	if (add) {
		title = articlel('tabTitleAddToDir') + ' "' + node.text + '"';
		tabTip = articlel('tabTitleAddToDir') + ' "' + parentNodeText + ' / ' + node.text;
		tabButons = new Array( articleCategoryViewTabButtonSave( obj ) );
		obj.add = 1;
	} else {
		title = node.text;
		tabTip = parentNodeText + ' / ' + node.text;
		tabButons = new Array(
			articleCategoryViewTabButtonSave( obj )//,'-',
		//	articleCategoryViewTabButtonCopy( obj ),'-',
			//articleCategoryViewTabButtonDel( obj )
		);
		obj.add = 0;
	}
	
	title = title.substring(0, 30)

	Ext.getCmp('article-tabs').add({
		title: title,
		id: 'article-category-view-tab-' + obj.id,
		tabTip: tabTip,
		items: [simple],
		iconCls: 'wg-toolbar-properties',
		closable: true,
		//height: '100%',
		autoHeigh: true,
		autoScroll: true,
		tbar: tabButons,
		layout: 'fit'
	}).show();
}

function articleCategoryViewTabButtonSave( obj )	{
	return new Ext.Button( {
		text: articlel('tabButtonSave'),
		//tooltip: articlel('formButtonSave'),
		iconCls: 'wg-toolbar-save',
		handler: function() {
			var gg = Ext.getCmp('article-category-access-grid-'+obj.id).getStore().getModifiedRecords();
			var h = new Array();
			for (i = 0; i < gg.length; i++) {
				h[i] = gg[i].data;
			}
			Ext.getCmp('article-category-view-form-'+obj.id).getForm().baseParams = {
				json_access: Ext.encode(h),
				action: 'article_category_update'
			};
			if( obj.add )	{
				Ext.getCmp('article-category-view-form-'+obj.id).getForm().baseParams.parent_id = obj.parent_id;
			}
			
			new Ext.LoadMask(Ext.getCmp('article-category-view-tab-' + obj.id).getEl(), {
				msg: articlel('dlgMsgSaving')
			}).show();
			Ext.getCmp('article-category-view-form-'+obj.id).getForm().submit({
				success: function() { Ext.getCmp('article-category-view-tab-' + obj.id).getEl().unmask(); },
				failure: function(f,a){
					alert( a.failureType );
				}
			});
		}
	} );		
}

var articleCategoryCM = new Array();

function articleCategoryAccessActionRenderer(val)	{
	return articlel(val);
}

function articleCategoryAccessGridColumnModel(actions) {
	var cm;
	var cols = new Array(
        {
        	header: articlel('labelGroup'),
            tooltip: articlel('labelGroup'),
        	dataIndex: 'group'
        },
        {
        	header: articlel('labelAction'),
            tooltip: articlel('labelAction'),
        	dataIndex: 'action',
			renderer: articleCategoryAccessActionRenderer
        }
    );
	
	var checkColumn = new Ext.grid.CheckColumn({
			header: articlel('#'),
			tooltip: articlel('#'),
			dataIndex: 'value',
			width: 75
	});
	cols.push( checkColumn );
	articleCategoryCM[0] = checkColumn;
	
	return ( cm = new Ext.grid.ColumnModel(cols) );
}

function articleCategoryAccessGridStore( pid ) {   
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: articleModulePath + '/category.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'article_category_access_list',
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

function articleCategoryAccessGridPanel(pid) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
        autoHeight: true,
		cm: articleCategoryAccessGridColumnModel(),
        store: articleCategoryAccessGridStore( pid ),
		border: false,
		loadMask: true,
        plugins: articleCategoryCM[0],
        clicksToEdit: 1,
		id: 'article-category-access-grid-' + pid,
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




function articleCategoryCopy( node ) {
	new Ext.LoadMask(Ext.getCmp('article-win').getEl(), {
		msg: articlel('dlgMsgLoading')
	}).show();
	
	Ext.Ajax.request({
		url: articleModulePath + '/category.cgi',
		success: function() {
			node.parentNode.reload();
			Ext.getCmp('article-win').getEl().unmask();
		},
		failure: function() {
			Ext.getCmp('article-win').getEl().unmask();
			alert('failure');
		},
		params: {
			action: 'article_category_copy',
			id: node.id
		}
	});
}

//-------------------------------------------------------------
//    article ITEM
//-------------------------------------------------------------

function articleItemGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: articlel('labelID'),
		dataIndex: 'id',
		width: 50
	}]);

	cm.defaultSortable = true;
	return (cm);
}

function articleItemAdd(pid, alias, grid) {
	var form = new Ext.FormPanel({
		labelWidth: 85,
		url: articleModulePath + '/item.cgi',
		border: false,
		bodyStyle: 'padding: 10px',
		width: '100%',
		defaults: {
			width: '100%'
		},
		defaultType: 'textfield',
		autoHeight: true,
		items: [{
			inputType: 'hidden',
			name: 'action',
			value: 'article_item_add'
		},
		{
			inputType: 'hidden',
			name: 'parent_id',
			value: pid
		},
		{
			fieldLabel: 'Имя',
			name: 'name',
			allowBlank: false
		}
		//,{
		//	fieldLabel: 'Обозначение'
		//	,name: 'alias'
		//	,allowBlank:false
		//}
		],
		buttons: [{
			text: 'Сохранить',
			handler: function() {
				form.getForm().submit({
					waitMsg: 'Сохранение...',
					success: function() {
						win.destroy();
						grid.getStore().reload()
					}
				});
			}
		},
		{
			text: 'Отменить',
			handler: function() {
				win.destroy();
			}
		}]
	});

	form.doLayout();

	var win = new Ext.Window({
		title: 'Добавить элемент в "' + alias + '"',
		closable: true,
		width: 400,
		height: 140,
		items: [form]
	});

	win.show();
}

function articleFieldCopy(grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: articleModulePath + '/field.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'article_field_copy',
			id: a.toString()
		}
	});

}



function articleItemDelete(pid, alias, grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: articleModulePath + '/item.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'article_item_delete',
			id: a.toString()
		}
	});

}

function articleItemGridStore(pid, grid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: articleModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'article_item_list'
		},
		remoteSort: true
	});

	//store.setDefaultSort('ordering', 'desc');

	store.on('load',
	function(a, b, c) {
		if (typeof(store.reader.jsonData.columns) === 'object') {
			var columns = [];
			//if(this.rowNumberer) { columns.push(new Ext.grid.RowNumberer()); }
			//if(this.checkboxSelModel) { columns.push(new Ext.grid.CheckboxSelectionModel()); }
			Ext.each(store.reader.jsonData.columns,
			function(column) {
				column.header = articlel(column.header);
				columns.push(column);
			});
			if (grid) grid.getColumnModel().setConfig(columns);
			//Ext.getCmp('article-item-grid-bbar-'+pid).store = grid.store;
		}
		//this.el.unmask();
	});

	store.load({
		params: {
			start: 0,
			limit: articlePerPage,
			pid: pid
		}
	});
	return (store);
}

function articleItemGridPanel(pid, rows) {
	//var store = articleItemGridStore( pid );
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		cm: articleItemGridColumnModel(),
		ddGroup: 'articleGridDD',
		autoScroll: true,
		enableDragDrop: true,
		loadMask: true,
		id: 'article_item_grid_' + pid,
		viewConfig: {
			forceFit: true
		}
	});

	var store = articleItemGridStore(pid, grid);

	grid.store = store;
	grid.on('rowdblclick', articleItemGridOnRowDblClick);
	return (grid);
}


function articleItemGridOnRowDblClick(grid, rowIndex, e) {
	var tabs = Ext.getCmp('article-tabs');
	var record = grid.getStore().getAt(rowIndex);
	
	if (tabs.items.get('article_item_tab_' + record.id) ) {
		tabs.setActiveTab('article_item_tab_' + record.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('article-tabs').getEl(), {
			msg: articlel('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: articleModulePath + '/item.cgi',
			success: function(req) {
				Ext.getCmp('article-tabs').getEl().unmask();
				var obj;
				var tt = 'obj = ' + req.responseText;
				eval(tt);
				
				for( var i = 0; i < obj.l10n.items.length; i++ )	{
					for( var j = 0; j < obj.l10n.items[i].items.length; j++ )	{
						obj.l10n.items[i].items[j].fieldLabel = articlel( obj.l10n.items[i].items[j].fieldLabel );
					}
				}
				
				for( var i = 0; i < obj.flags.length; i++ )	{
						obj.flags[i].fieldLabel = articlel( obj.flags[i].fieldLabel);
				}
				articleItemTab(record, obj);
			},
			failure: function() {
				Ext.getCmp('article-tabs').getEl().unmask();
				alert('failure');
			},
			params: {
				action: 'article_item_view',
				id: record.id
			}
		});
	}
}

function articleItemTab(record, obj) {
	var simple = new Ext.FormPanel({
		labelWidth: 85,
		url: articleModulePath + '/item.cgi',
		border: false,
		bodyStyle: 'padding: 0',
		width: '100%',
		id: 'article-item-form-' + obj.id,
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
				title: articlel('tabTitleGeneral'),
				layout: 'form',
				border: false,
				defaults: {
					anchor: '100%',
					border: false
				},
				defaultType: 'textfield',
				items: [
					{
						fieldLabel: articlel('labelID'),
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
						fieldLabel: articlel('labelName'),
						name: 'name',
						value: obj.name
					},
					{
						fieldLabel: articlel('labelOwner'),
						value: obj.owner,
						name: 'module',
						disabled: 'true'
					},
					{
						fieldLabel: articlel('labelInserted'),
						value: obj.inserted,
						name: 'inserted',
						disabled: 'true'
					},
					{
						fieldLabel: articlel('labelUpdated'),
						value: obj.updated,
						name: 'updated',
						disabled: 'true'
					}
                ]
			},
			{
				title: articlel('tabTitleLocalization'),
				layout: 'form',
				border: false,
				bodyStyle: 'padding: 0',
				//width: '100%',
				defaults: {
					anchor: '100%',
					border: false
				},
				defaultType: 'textfield',
				items: obj.l10n
			},
			{
				title: articlel('tabTitleContent'),
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
				title: articlel('tabTitleFiles'),
				layout: 'form',
				border: false,
				bodyStyle: 'padding: 0',
				defaults: {
					width: '100%'
				},
				tbar: [
				{
					text: articlel('tabButtonRefresh'),
					tooltip: articlel('tabButtonRefreshToolTip'),
					iconCls: 'wg-toolbar-reload',
					handler: function() {
						Ext.getCmp('article_item_files_grid_panel_' + obj.id).getStore().reload();
					}
				},'-',
				{
					text: articlel('tabButtonAdd'),
					tooltip: articlel('tabButtonAddFileToolTip'),
					iconCls: 'wg-toolbar-add',
					handler: function() {
						var dialog;
						Ext.apply(Ext.ux.UploadDialog.Dialog.prototype.i18n, articleLang['uploadDialogI18n'] );
						if (!dialog) {
							dialog = new Ext.ux.UploadDialog.Dialog({
								url: articleModulePath + '/item.cgi',
								base_params: {
									action: 'article_item_add_file',
									id: obj.id
								},
								//reset_on_hide: true
								allow_close_on_upload: true,
								//upload_autostart: false
								post_var_name: 'fileupload'
							});
							
							//dialog.on('beforefileuploadstart', this.onUploadSuccess, this);
							dialog.on('beforefileuploadstart', articleItemOnBeforeFileUploadStart );
							dialog.on('uploadcomplete', function( d ){
								Ext.getCmp('article_item_files_grid_panel_' + obj.id).getStore().reload();
							} );
							//dialog.on('uploadsuccess', this.onUploadSuccess, this);
						}
						dialog.show();
					}
				},'-',
				{
					text: articlel('tabButtonDel'),
					tooltip: articlel('tabButtonDelFileToolTip'),
					iconCls: 'wg-toolbar-del',
					handler: function() {
						articleItemFileDelete( obj.id, Ext.getCmp('article_item_files_grid_panel_' + obj.id) );
					}
				},'-'
				],
				defaultType: 'textfield',
				items: [ articleItemFilesGridPanel( obj.id ) ]
			},
			{
				title: articlel('tabTitleAccess'),
				layout: 'form',
				border: false,
				defaultType: 'textfield',
				autoHeight:true,
				bodyStyle: 'padding: 0',
                items: [ articleItemAccessGridPanel( obj.id ) ]
			},
			{
				title: articlel('tabTitleOptions'),
				layout: 'form',
				border: false,
				defaults: {
					width: '100%'
				},
				defaultType: 'textfield',
				items: obj.flags
			}
            ]
		}
	});

	var title = record.get('name');
	var tabTip = obj.parent_name + '/' + record.get('name');
	
	title = title.substring(0, 30)

	Ext.getCmp('article-tabs').add({
		title: title,
		id: 'article_item_tab_' + obj.id,
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
				fn: function(){ articleItemSave( obj ) }
			}
		],
		tbar:[
			{
				text: articlel('formButtonSave'),
				tooltip: articlel('formButtonSave'),
				iconCls: 'wg-toolbar-save',
				handler: function() {
					var gg = Ext.getCmp('article_item_access_grid_'+obj.id).getStore().getModifiedRecords();
					var h = new Array();
					for (i = 0; i < gg.length; i++) {
						h[i] = gg[i].data;
					}
					simple.getForm().baseParams = {
						json_access: Ext.encode(h),
						action: 'article_item_update'
					};
					new Ext.LoadMask(Ext.getCmp('article_item_tab_' + obj.id).getEl(), {
						msg: articlel('dlgMsgSaving')
					}).show();
					simple.getForm().submit({
						//clientValidation: false,
						success: function() { Ext.getCmp('article_item_tab_' + obj.id).getEl().unmask(); },
						failure: function(f,a){
							Ext.getCmp('article_item_tab_' + obj.id).getEl().unmask();
							alert( 'failure' );
						}
					});
				}
			}
		]
	}).show();
}

function articleItemOnBeforeFileUploadStart(dialog, filename, record)	{
    if( Ext.getCmp('file_upload_type').getValue() )	{
		dialog.base_params.type_id = Ext.getCmp('file_upload_type').getValue();
		dialog.base_params.overwrite = Ext.getCmp('file_upload_overwrite').getValue();
		dialog.base_params.filename = filename;
		return true;
	}
	
	return false;
}

function articleItemFileDelete(pid, grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: articleModulePath + '/item.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'article_item_del_file',
			fid: a.toString()
		}
	});

}

function articleItemFileRenderPreview( val )	{
	if( val.length > 1 )	{
		return '<img src="' + val + '">';
	}
	else	{
		return '';
	}
}

function articleItemFileRenderView( val )	{
	if( val && val.length > 1 )	{
		return '<a href="'+val+'" target="_blank">' + articlel('#') + '</a>';
	}
	else	{
		return '';
	}
}

function articleItemFilesGridColumnModel(actions) {
	var cm = new Ext.grid.ColumnModel([
		{
			header: articlel('labelImg'),
			dataIndex: 'preview',
			renderer: articleItemFileRenderPreview,
			width: 50
		},
		{
			header: articlel('labelType'),
			dataIndex: 'type_name_alias',
			width: 50
		},
		{
			header: articlel('labelSize'),
			dataIndex: 'size',
			width: 50
		},
		{
			header: articlel('labelInserted'),
			dataIndex: 'inserted',
			width: 50
		},
		{
			header: articlel('#'),
			dataIndex: 'src',
			renderer: articleItemFileRenderView,
			width: 50
		},
		{
			header: articlel('labelURL'),
			dataIndex: 'src',
			editor: new Ext.form.TextField({
                allowBlank: true,
				selectOnFocus: true
            }),
			width: 50
		},
		{
			header: articlel('labelAlias'),
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

function articleItemFilesGridStore( id, grid )	{
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: articleModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'article_item_files_list',
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

function articleItemFilesGridPanel( id ) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
		autoHeight: true,
		cm: articleItemFilesGridColumnModel(),
		ddGroup: 'articleFilesGridDD',
		autoScroll: true,
		enableDragDrop: true,
		selModel: new Ext.grid.RowSelectionModel({singleSelect:false}),
		clicksToEdit: 1,
		loadMask: true,
		border: false,
		id: 'article_item_files_grid_panel_' + id,
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
	
	var store = articleItemFilesGridStore( id, grid);

	grid.store = store;
	//grid.on('rowdblclick', articleItemFilesGridOnRowDblClick);
	return (grid);
}

var articleItemCM = new Array();

function articleItemAccessActionRenderer(val)	{
	return articlel(val);
}

function articleItemAccessGridColumnModel(actions) {
	var cm;
	var cols = new Array(
        {
        	header: articlel('labelGroup'),
            tooltip: articlel('labelGroup'),
        	dataIndex: 'group'
        },
        {
        	header: articlel('labelAction'),
            tooltip: articlel('labelAction'),
        	dataIndex: 'action',
			renderer: articleItemAccessActionRenderer
        }
    );
	
	var checkColumn = new Ext.grid.CheckColumn({
			header: articlel('#'),
			tooltip: articlel('#'),
			dataIndex: 'value',
			width: 75
	});
	cols.push( checkColumn );
	articleItemCM[0] = checkColumn;
	
	cm = new Ext.grid.ColumnModel(cols);

	return (cm);
}

function articleItemAccessGridStore( pid ) {   
	var store = new Ext.data.GroupingStore({
		proxy: new Ext.data.HttpProxy({
			url: articleModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'article_item_access_list',
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

function articleItemAccessGridPanel(pid) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
        autoHeight: true,
		cm: articleItemAccessGridColumnModel(),
        store: articleItemAccessGridStore( pid ),
		border: false,
		loadMask: true,
        plugins: articleItemCM[0],
        clicksToEdit: 1,
		id: 'article_item_access_grid_' + pid,
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


//---------------------------------------------------------
//     FIELDS
//---------------------------------------------------------

function articleFieldGridPanel(pid) {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		id: 'article-field-grid-panel-' + pid,
		store: articleFieldGridStore(pid),
		cm: articleFieldGridColumnModel(),
		autoHeight: true,
		autoScroll: true,
		border: false,
		enableDragDrop: true,
		ddGroup: 'articleFieldsDD',
		loadMask: true,
		viewConfig: {
			forceFit: true
		}
	});
	grid.getView().getRowClass = function(row, index) {
		if (row.data.inherit == 1) {
			return 'wg-inherited-field';
		}
		else return ''
	}
	
	grid.on('rowdblclick', function(grid, rowIndex, item) { articleFieldView(grid, rowIndex, item, 0) });
	return (grid);
}

function articleFieldGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: articlel('labelID'),
		dataIndex: 'id',
		sortable: true,
		minWidth: 20
	},
	{
		header: articlel('labelName'),
		dataIndex: 'name',
		sortable: true,
		width: 200
	},
	{
		header: articlel('labelAlias'),
		dataIndex: 'alias',
		sortable: true,
		width: 200
	},
	{
		header: articlel('labelType'),
		dataIndex: 'type_alias',
		width: 100
	}]);

	//cm.defaultSortable = true;
	return (cm);
}

function articleFieldGridStore(pid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: articleModulePath + '/field.cgi'
		}),
		reader: new Ext.data.JsonReader({
			totalProperty: 'totalCount',
			root: 'rows',
			id: 'id',
			fields: ['id', 'name', 'alias', 'inherit', 'type_alias']
		}),
		remoteSort: true,
		baseParams: {
			action: 'article_field_list'
		}
	});

	store.setDefaultSort('name', 'desc');
	store.load({
		params: {
			start: 0,
			limit: 1000,
			pid: pid
		}
	});
	return (store);
}

function articleFieldView(grid, rowIndex, e, add) {
	var item = grid.getStore().getAt(rowIndex);
	var item_id;
	item_id = (item) ? item.id: 0;
	if (add) {
		item_id = 0;
		item = null;
	}

	Ext.Ajax.request({
		url: articleModulePath + '/field.cgi',
		success: function(req) {
			var obj;
			eval('obj = ' + req.responseText);

			for( var i = 0; i < obj.flags.length; i++ )	{
					obj.flags[i].fieldLabel = articlel( obj.flags[i].fieldLabel);
			}
			
			articleFieldViewTab(item, obj, grid);
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'article_field_view',
			id: item_id,
			pid: rowIndex
		}
	});
}

function articleFieldViewTab(item, json, grid) {
	var tabs = Ext.getCmp('article-tabs');
	if( item && tabs.items.get('article-field-tab-' + item.id) ) {
		tabs.setActiveTab('article-field-tab-' + item.id);
	}
	else	{
		var item_id;
		item_id = (item) ? item.id: 0;
		var form = new Ext.FormPanel({
			labelWidth: 85,
			url: articleModulePath + '/field.cgi',
			border: false,
			bodyStyle: 'padding: 0',
			width: '100%',
			defaults: {
				width: '100%',
				border: false
			},
			defaultType: 'textfield',
			autoHeight: true,
			id: 'article_field_edit_form',
			items: {
				xtype: 'tabpanel',
				activeTab: 0,
				id: 'article_field_tabs_' + item_id,
				defaults: {
					autoHeight: true,
					border: false,
					bodyStyle: 'padding:5px',
					width: '500'
				},
				items: [{
					title: articlel('tabTitleGeneral'),
					layout: 'form',
					border: false,
					defaults: {
						width: '100%'
					},
					defaultType: 'textfield',
					id: 'article_field_common_' + item_id,
					items: [{
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
						fieldLabel: articlel('labelID'),
						value: json.id,
						disabled: 'true'
					},
					{
						fieldLabel: articlel('labelParent'),
						value: json.parent_alias,
						disabled: 'true'
					},
					{
						fieldLabel: articlel('labelInserted'),
						value: json.inserted,
						disabled: 'true'
					},
					{
						fieldLabel: articlel('labelName'),
						name: 'name',
						allowBlank: 'false',
						value: json.name
					},
					{
						xtype: 'combo',
						height: '1px',
						hideLabel: true,
						disabled: true,
						hidden: true
					},
					{
						xtype: 'combo',
						store: articleFieldDataTypeStore(),
						fieldLabel: articlel('labelType'),
						name: 'type_id_old',
						hiddenName: 'type_id',
						id: 'article_type_id',
						displayField: 'alias',
						valueField: 'id',
						allowBlank: 'false',
						mode: 'local',
						disabled: true
					},
					{
						xtype: 'combo',
						store: articleFieldConfigurationStore(),
						fieldLabel: articlel('labelGroup'),
						name: 'source_group_id_old',
						hiddenName: 'source_group_id',
						id: 'article_source_group_id',
						displayField: 'alias',
						valueField: 'id',
						allowBlank: 'false',
						mode: 'local',
						disabled: true
					},
					{
						xtype: 'combo'
						//,store: articleFieldCategoryStore(json.group_name)
						,
						fieldLabel: articlel('labelCategory'),
						name: 'source_category_id_old',
						hiddenName: 'source_category_id',
						id: 'article_source_category_id',
						displayField: 'alias',
						valueField: 'id',
						allowBlank: 'false',
						mode: 'local',
						disabled: true
					}
	
					]
				},
				{
					title: articlel('tabTitleLocalization'),
					layout: 'form',
					border: false,
					defaults: {
						width: '100%'
					},
					defaultType: 'textfield',
					id: 'article_field_aliases_' + item_id,
					items: json.items_l10n
				},
				{
					title: articlel('tabTitleAccess'),
					layout: 'form',
					border: false,
					defaultType: 'textfield',
					items: [articleFieldAccessGrid(item_id, json.items_actions)]
				},
				{
					title: articlel('tabTitleOptions'),
					layout: 'form',
					defaults: {
						width: 230
					},
					defaultType: 'textfield',
					id: 'article_field_flags_' + item_id,
					items: json.flags
				}
	
				]
			},
			buttons: [{
				text: articleLang['formButtonSave'],
				handler: function() {
					var gg = Ext.getCmp('article_field_access_grid').getStore().getModifiedRecords();
					var h = new Array();
					for (i = 0; i < gg.length; i++) {
						h[i] = gg[i].data;
					}
					form.getForm().baseParams = {
						access: Ext.encode(h), //h.toJSON(),
						parent_id: json.parent_id,
						action: 'article_field_update'
					};
					form.getForm().submit({
						waitMsg: articleLang['dlgMsgSaving'],
						success: function() {
							win.destroy();
							grid.getStore().reload()
						}
					});
				}
			},
			{
				text: articleLang['formButtonRefresh'],
				handler: function() {
					var gg = Ext.getCmp('article_field_access_grid').getStore().getModifiedRecords();
					var h = new Array();
					for (i = 0; i < gg.length; i++) {
						h[i] = gg[i].data;
					}
					form.getForm().baseParams = {
						access: Ext.encode(h), //h.toJSON(),
						parent_id: json.parent_id,
						action: 'article_field_update'
					};
					form.getForm().submit({
						waitMsg: articleLang['dlgMsgSaving'],
						success: function() {
							Ext.getCmp('article_field_access_grid').getStore().commitChanges();
							grid.getStore().reload()
						}
					});
				}
			},
			{
				text: articleLang['formButtonCancel'],
				handler: function() {
					win.destroy();
				}
			}]
		});
	
		Ext.getCmp('article_type_id').on('select', articleFieldConfiguration);
		Ext.getCmp('article_source_group_id').on('select', articleFieldCategory);
	
		if (item_id) {
			Ext.getCmp('article_type_id').setValue(json.type_alias);
			Ext.getCmp('article_source_group_id').setValue(json.group_alias);
			Ext.getCmp('article_source_category_id').store = articleFieldCategoryStore(json.group_name);
			Ext.getCmp('article_source_category_id').setValue(json.category_name);
		} else {
			Ext.getCmp('article_type_id').disabled = false;
			Ext.getCmp('article_source_group_id').disabled = false;
			Ext.getCmp('article_source_category_id').disabled = false;
		}
	
		var title = 'Без имени';
		if (item_id) {
			title = item.get('alias');
			if (item.get('alias').length > 0) {
				title = item.get('alias');
			} else {
				title = item.get('id');
			}
		}
	
		tabs.add({
			title: title,
			id: 'article-field-tab-' + item_id,
			//tabTip: tabTip,
			items: [form],
			iconCls: 'wg-toolbar-fields',
			closable: true,
			//height: '100%',
			autoHeigh: true,
			autoScroll: true,
			//tbar: tabButons,
			layout: 'fit',
			tbar:[
			
			]
		}).show();

	
	}
}

function articleFieldConfiguration(combo, record, index) {
	var name = record.get('name');

	if (name == 'article') {
		//Ext.getCmp('article_source_group_id').hide();
		Ext.getCmp('article_source_group_id').disabled = false;
		//Ext.getCmp('article_source_group_id').show();
	} else {
		//Ext.getCmp('article_source_group_id').disabled = true;
	}
	//Ext.getCmp('article_field_edit_form').doLayout();
}

function articleFieldConfigurationStore() {
	var store = new Ext.data.JsonStore({
		url: '/cgi-bin/wg/modules/configuration/category.cgi',
		baseParams: {
			action: 'configuration_store_list'
		},
		fields: ['id', 'alias', 'name']
	});

	store.load();
	return (store);
}

function articleFieldCategory(combo, record, index) {
	var name = record.get('name');
	Ext.getCmp('article_source_category_id').store = articleFieldCategoryStore(name);
}

function articleFieldCategoryStore(name) {
	var store = new Ext.data.JsonStore({
		url: '/cgi-bin/wg/modules/' + name + '/category.cgi',
		baseParams: {
			action: name + '_category_flat'
		},
		fields: ['id', 'alias']
	});

	if (name) {
		store.load();
	}

	return (store);
}

function articleFieldDataTypeStore() {
	var store = new Ext.data.JsonStore({
		url: articleModulePath + '/field.cgi',
		baseParams: {
			action: 'article_datatypes'
		},
		fields: ['id', 'alias']
	});

	store.load();
	return (store);
}

function articleFieldDelete(pid, alias, grid) {
	var y = grid.getSelectionModel().getSelections();
	var a = [];
	for (var x = 0; x < y.length; x++) {
		a[x] = y[x].id;
	}

	Ext.Ajax.request({
		url: articleModulePath + '/field.cgi',
		success: function() {
			grid.getStore().reload()
		},
		failure: function() {
			alert('failure')
		},
		params: {
			action: 'article_field_delete',
			id: a.toString()
		}
	});
}


//-----------------------------------------------------------------
//		FIELD GROUPS
//-----------------------------------------------------------------
function articleFieldGroupTab( item )    {
	var tree = articleFieldGroupPanel( item );
	var grid = articleFieldGridPanel( item.id );
	grid.region = 'center';
	
	var tabs = Ext.getCmp('article-tabs');
	if (tabs.items.get('article-field-group-tab-' + item.id) ) {
		tabs.setActiveTab('article-field-group-tab-' + item.id);
	}
	else	{
		tabs.add({
			title: item.text,
			id: 'article-field-group-tab-' + item.id,
			//tabTip: tabTip,
			items: [tree,grid],
			iconCls: 'wg-toolbar-field-groups',
			closable: true,
			//height: '100%',
			autoHeigh: true,
			autoScroll: true,
			//tbar: tabButons,
			layout: 'border',
			defaults: {
				split: true
			},
			tbar:[
			'->',
			{
				text: articlel('tabButtonRefresh'),
				tooltip: articlel('tabButtonRefreshFieldsToolTip'),
				iconCls: 'wg-toolbar-reload',
				handler: function() {
					grid.getStore().reload()
				}
			},'-',
			{
				text: articlel('tabButtonAdd'),
				tooltip: articlel('tabButtonAddFieldToolTip'),
				iconCls: 'wg-toolbar-add',
				handler: function() {
					articleFieldView(grid, item.id, null, 1)
				}
			},'-',
			{
				text: articlel('tabButtonDel'),
				tooltip: articlel('tabButtonDelFieldsToolTip'),
				iconCls: 'wg-toolbar-del',
				handler: function() {
					if( confirm( articlel('tabButtonDelFieldsToolTip') + '?' ) )	{
						articleFieldDelete(item.id, item.text, grid);
					}
				}
			}
			]
		}).show();
		
		var ddrow = new Ext.dd.DropTarget(grid.getView().mainBody, {
			ddGroup: 'articleFieldsDD',
			notifyDrop: function(dd, e, data) {
				var sm = grid.getSelectionModel();
				var rows = sm.getSelections();
				var cindex = dd.getDragData(e).rowIndex;
				if (sm.hasSelection()) {
					for (i = 0; i < rows.length; i++) {
						grid.store.remove(grid.store.getById(rows[i].id));
						grid.store.insert(cindex, rows[i]);
					}
					sm.selectRecords(rows);
					var r = grid.store.getRange();
					var w = new Array();
					for (i = 0; i < r.length; i++) {
						w[i] = r[i].get('id');
					}
	
					Ext.Ajax.request({
						url: articleModulePath + '/field.cgi',
						success: function() {
							grid.store.reload()
						},
						failure: function() {
							alert('failure')
						},
						params: {
							action: 'article_field_order',
							ord: w.join(',')
						}
					});
				}
			}
		});
	}
}

function articleFieldGroupPanel( item )	{
	var tree = new Ext.tree.TreePanel({
		region:'west',
        id:'article-field-group-tree-' + item.id,
        autoScroll:true,
		loader: new Ext.tree.TreeLoader({
            dataUrl:articleModulePath+'/field.cgi'
			,baseParams:{action:'article_field_group_list', pid:item.id}
		}),
		root: new Ext.tree.AsyncTreeNode({
		    text: articlel('labelFieldGroups'), 
			draggable: false,
			allowDrag: false,
			allowDrop: true,
			expanded: true,
			id: '0'
		}),
        enableDD:true,
		ddGroup: 'articleFieldsDD',
        containerScroll: true,
        border: false,
		width:200,
        //height: 300,
		contextMenu: articleFieldGroupContextMenu( item ),
		listeners: {
			contextmenu: function(node, e) {
				node.select();
				var c = node.getOwnerTree().contextMenu;
				c.contextNode = node;
				c.showAt(e.getXY());
			}
		},
		plugins:[new Ext.ux.state.TreePanel()]
    });
	
	tree.on('beforenodedrop', function( e ){ articleFieldGroupBeforeNodeDrop( e, item.id ) } ); 
	tree.on('dblclick', function( node, e ){ articleFieldGroupView( node );	} );
	
	return tree;
}

function articleFieldGroupContextMenu( obj )	{
	if( Ext.getCmp('article-field-group-context-menu-' + obj.id) )	{
		return Ext.getCmp('article-field-group-context-menu-' + obj.id);
	}
	else{
		var m = new Ext.menu.Menu({
			id: 'article-field-group-context-menu-' + obj.id,
			items: [
			{
				id: 'fgcm-refresh-' + obj.id,
				text: articlel('labelRefresh'),
				iconCls: 'wg-toolbar-reload'
			},
			{
				id: 'fgcm-properties-' + obj.id,
				text: articlel('labelProperties'),
				iconCls: 'wg-toolbar-properties'
			},
			{
				id: 'fgcm-add-' + obj.id,
				iconCls: 'wg-toolbar-add',
				text: articlel('labelAddGroup')
			},
			{
				id: 'fgcm-delete-' + obj.id,
				iconCls: 'wg-toolbar-del',
				text: articlel('labelDelete')
			}
			],
			listeners: {
				itemclick: function(item) {
					var n = item.parentMenu.contextNode;

					switch (item.id) {
					case 'fgcm-refresh-' + obj.id:
						if( !n.leaf ) n.reload();
						break;
					case 'fgcm-properties-' + obj.id:
						articleFieldGroupView(n);
						break;
					case 'fgcm-add-' + obj.id:
						articleFieldGroupAdd( obj.id );
						break;
					case 'fgcm-delete-' + obj.id:
						if (confirm(articlel('labelDelete') + ' '+ n.text + '?')) {
							articleFieldGroupDel(n);
						}
						break;
					}
				}
			}
		});

		return m;
	}
}	

function articleFieldGroupBeforeNodeDrop( e, pid )	{
	var tid = e.target.id;
	var tl = e.target.leaf;
	
	if( e.target.leaf == true && e.point == 'append' )	{
		e.cancel = true;
	}
	else if( e.point == 'above' || e.point == 'below' )	{
		var s = Ext.getCmp('article-field-group-tree-' + pid ).getSelectionModel().getSelectedNode().id;
		Ext.Ajax.request({
			url: articleModulePath + '/field.cgi'
			,success: function(){ e.target.parentNode.reload() }
			,failure: function(){ alert('failure') }
			,params: { action: 'article_field_group_item_move', src: s, dst: e.target.id, point:e.point }
		});
	}
	else	{
		if(  e.point == 'append' )	{
			if(Ext.isArray(e.data.selections)) {
				var a = new Array();
	
				for(var i = 0; i < e.data.selections.length; i++) {
					a.push( e.data.selections[i].id );
				}
				
				Ext.Ajax.request({
					url: articleModulePath + '/field.cgi'
					,success: function(){ e.target.reload() }
					,failure: function(){ alert('failure') }
					,params: { action: 'article_field_group_item_add', src: a.toString(), dst: e.target.id }
				});
			}
		}
	}
}


function articleFieldGroupAdd( pid ) 	{
    Ext.Ajax.request({
		url: articleModulePath+'/field.cgi'
		,success: function(req){ 
			Ext.getCmp('article-field-group-tree-' + pid ).root.reload();
		}
		,failure: function(){ alert('failure') }
		,params: { action: 'article_field_group_add', pid: pid  }
    });
}

function articleFieldGroupDel( node ) 	{
    Ext.Ajax.request({
		url: articleModulePath+'/field.cgi'
		,success: function(req){ 
			node.parentNode.reload();
		}
		,failure: function(){ alert('failure') }
		,params: { action: 'article_field_group_del', id: node.id, leaf: node.leaf  }
    });
}

function articleFieldGroupView( node )    {
	Ext.Ajax.request({
		url: articleModulePath + '/field.cgi',
		success: function( req ) {
			var json;
			eval('json = ' + req.responseText);
			articleFieldGroupWindow( json, node )
		},
		failure: function() {
			alert('failure');
		},
		params: {
			action: 'article_field_group_view',
			id: node.id,
			grp: ( node.hasChildNodes() ) ? 1 : 0
		}
	});
}

function articleFieldGroupWindow( obj, node )    {
    var form = new Ext.FormPanel({
		labelWidth: 55
		,url:articleModulePath+'/field.cgi'
		,border: false
		,bodyStyle:'padding: 5'
		,width: '100%'
		,defaults: { width: '100%', labelWidth: 85 }
		,defaultType: 'textfield'
		,autoHeight: true
		,items: [
		{
            xtype:'fieldset',
            title: profilel('labelGeneral'),
            collapsible: true,
            autoHeight:true,
            defaults: { width: '100%' },
            defaultType: 'textfield',
            items :[
				{
					inputType: 'hidden'
					,name: 'grp'
					,value: obj.grp
				}
				,{
					inputType: 'hidden'
					,name: 'id'
					,value: obj.id
				}
				,{
					fieldLabel: 'Имя'
					,name: 'name'
					,value: obj.name
					,allowBlank:false
				}
			]
		},
		{
            xtype:'fieldset',
            title: profilel('labelLocalization'),
            collapsible: true,
            autoHeight:true,
            defaults: { width: '100%' },
            defaultType: 'textfield',
            items :[ obj.l10n ]
		}
		]
    });

    var win = new Ext.Window({
        title: articlel('labelFieldGroup') + ' ' + obj.name
        ,closable:true
        ,width:400
        ,height:300
        ,items: [form]
		,tbar: [
		{
			text: articlel('labelSave'),
			iconCls: 'wg-toolbar-save',
			listeners: {
				click: function() {
						form.getForm().baseParams = {
							action: 'article_field_group_update'
						};
						form.getForm().submit( {
							success: function(){
								if( node.parentNode ) node.parentNode.reload();
								win.destroy();
							},
							failure: function(){ alert('failure') }
						});
				}
			}
		},'-',
		{
			text: articlel('labelClose'),
			iconCls: 'wg-toolbar-close',
			listeners: {
				click: function() {
					win.destroy();
				}
			}
			
		}
		]
    });

    win.show();
}




//---------------------------------------------------------
//  CATEGORY PROPERTIES
//---------------------------------------------------------
var articleFieldCM = new Array();
function articleFieldAccessGridColumnModel(actions) {
	var cm;
	var cols = new Array({
		header: "Group",
		dataIndex: 'name'
	});
	for (i = 0; i < actions.length; i++) {
		var checkColumn = new Ext.grid.CheckColumn({
			header: articleLang[actions[i].name],
			tooltip: articleLang[actions[i].name],
			dataIndex: 'field_' + actions[i].id,
			width: 75
		});
		cols[i + 1] = checkColumn;
		articleFieldCM[i] = checkColumn;
	}
	cm = new Ext.grid.ColumnModel(cols);

	return (cm);
}

function articleFieldAccessGridStore(pid) {
	var store = new Ext.data.JsonStore({
		url: articleModulePath + '/field.cgi',
		baseParams: {
			action: 'article_access_list',
			pid: pid
		}
	});

	store.load();
	return (store);
}

function articleFieldAccessGrid(pid, actions) {
	var grid = new Ext.grid.EditorGridPanel({
		width: '100%',
		store: articleFieldAccessGridStore(pid),
		cm: articleFieldAccessGridColumnModel(actions),
		id: 'article_field_access_grid',
		autoHeight: true,
		autoScroll: true,
		loadMask: true,
		plugins: articleFieldCM,
		clicksToEdit: 1,
		viewConfig: {
			forceFit: true
		}
	});
	return (grid);
}

