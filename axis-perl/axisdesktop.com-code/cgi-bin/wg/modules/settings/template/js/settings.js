//<!--

var settingsModulePath = '/cgi-bin/wg/modules/settings';
var settingsPerPage = 50;

function settingsl(msg) {
	return l('settings', msg);
}

AxisDesktop.settingsModule = Ext.extend(Ext.app.Module, {
    id:'store-settings',
    type: 'store/settings',

	init: function() {
		//this.locale = QoDesk.AccordionWindow.Locale;
	},

    createWindow : function(){
        var desktop = this.app.getDesktop();
        var win = desktop.getWindow('settings-win');
        if(!win){
            win = desktop.createWindow({
                id: 'settings-win',
                title: settingsl('titleMainWindow'),
                width:740,
                height:480,
                iconCls: 'settings-main-window',
                shim:false,
                animCollapse:false,
                border:false,
                constrainHeader:true,
                layout: 'border',
                items:[settingsItemsPanel(), settingsCategoriesPanel()]
            });
        }
        win.show();
    }
});




	
var settings_context_item;

var settingsTree;
var settingsTreeToolBar;
var settingsTreeRootNode;



function settingsItemsPanel() {
	return new Ext.TabPanel({
		id: 'settings-tabs',
		activeTab: 0,
		region: 'center',
		enableTabScroll: true
	});
}

//------------------------------------------------------
//      settings TREE
//------------------------------------------------------

function settingsCategoriesPanel() {
	var p = new Ext.tree.TreePanel({
		animate: false,
		id: 'settingsTree',
		title: settingsl('labelStructure'),
		collapsible: true,
		enableDD: true,
		ddGroup: 'settingsGridDD',
		enableDrop: true,
		containerScroll: true,
		rootVisible: true,
		width: '250',
		split: true,
		autoScroll: true,
		margins: '0 0 3 1',
		loader: settingsCategoriesLoader(),
		root: settingsCategoriesRootNode(),
		region: 'west',
		tbar: settingsCategoriesToolBar(),
		bbar: settingsCategoriesToolBarBottom(),
		contextMenu: settingsCategoriesContextMenu(),
		listeners: {
			contextmenu: function(node, e) {
				node.select();
				var c = node.getOwnerTree().contextMenu;
				c.contextNode = node;
				c.showAt(e.getXY());
			}
		}
	});
	p.on('click', settingsCategoriesOnClick);
	p.on('beforenodedrop', settingsCategoriesOnBeforeNodeDrop);
	return p;
}

function settingsCategoriesLoader() {
	return new Ext.tree.TreeLoader({
		dataUrl: settingsModulePath + '/category.cgi',
		baseParams: {
			action: 'settings_category_list'
		}
	})
}

function settingsCategoriesRootNode() {
	return new Ext.tree.AsyncTreeNode({
		text: settingsl('treeRootNodeAlias'),
		draggable: false,
		allowDrag: false,
		allowDrop: false,
		expanded: true,
		id: '0'
	});
}

function settingsCategoriesToolBar() {
	return new Ext.Toolbar({
		id: 'settingsTreeToolBar',
		items: [{
			iconCls: 'icon-expand-all',
			tooltip: settingsl('treeButtonExpandToolTip'),
			handler: function() {
				Ext.getCmp('settingsTree').root.expand(true);
			}
		},
		'-', {
			iconCls: 'icon-collapse-all',
			tooltip: settingsl('treeButtonCollapseToolTip'),
			handler: function() {
				Ext.getCmp('settingsTree').root.collapse(true);
			}
		},
		'-', {
			iconCls: 'icon-reload-all',
			tooltip: settingsl('treeButtonRefreshToolTip'),
			handler: function() {
				Ext.getCmp('settingsTree').root.reload();
			}
		}]
	});
}

function settingsCategoriesToolBarBottom() {
	return new Ext.Toolbar({
		id: 'settingsTreeToolBarBottom',
		items: [new Ext.form.TextField({
			width: '100%',
			enableKeyEvents: true
		})]
	});
}

function settingsCategoriesContextMenu() {
	if( Ext.getCmp('settings-categories-context-menu') )	{
		return Ext.getCmp('settings-categories-context-menu');
	}
	else {
	var m = new Ext.menu.Menu({
		id: 'settings-categories-context-menu',
		items: [{
			id: 'settings-properties-context',
			text: settingsl('labelProperties'),
			iconCls: 'wg-toolbar-properties'
		},
		{
			id: 'settings-refresh-context',
			text: settingsl('labelRefresh'),
			iconCls: 'wg-toolbar-reload'
		},
		{
			id: 'settings-fields-context',
			text: settingsl('labelFields'),
			iconCls: 'wg-toolbar-fields'
		},
		{
			id: 'settings-add-context',
			iconCls: 'wg-toolbar-add',
			text: settingsl('labelAdd')
		},
		{
			id: 'settings-delete-context',
			iconCls: 'wg-toolbar-del',
			text: settingsl('labelDelete')
		}],
		listeners: {
			itemclick: function(item) {
				var n = item.parentMenu.contextNode;

				switch (item.id) {
				case 'settings-refresh-context':
					n.reload();
					break;
				case 'settings-properties-context':
					settingsCategoryView(n);
					break;
				case 'settings-fields-context':
					settingsFieldContext(n);
					break;
				case 'settings-add-context':
					settingsCategoryView(n, 1);
					break;
				case 'settings-delete-context':
					if (confirm(settingsl('labelDelete') + '?')) {
						var opt = {
							method: 'post',
							postBody: 'id=' + item.id + '&action=settings_category_delete',
							onSuccess: function() {
								settingsTree.root.reload()
							}
						}
						new Ajax.Request(settingsModulePath + '/category.cgi', opt);
					}
					break;
				}
			}
		}
	});

	return m;
	}
}

function settingsCategoriesOnClick(item, e) {
	var tabs = Ext.getCmp('settings-tabs');
	if (tabs.items.get('settings_' + item.id)) {
		tabs.setActiveTab('settings_' + item.id);
	} else {
		var grid = settingsItemGridPanel(item.id);
		tabs.add({
			title: item.text.substring(0, 30),
			id: 'settings_' + item.id,
			tabTip: item.parentNode.text + ' / ' + item.text,
			tbar: [
			{
				text: settingsl('tabButtonRefresh'),
				tooltip: settingsl('tabButtonRefreshToolTip'),
				iconCls: 'wg-toolbar-reload',
				handler: function() {
					grid.getStore().reload()
				}
			},'-',
			{
				text: settingsl('tabButtonAdd'),
				tooltip: settingsl('tabButtonAddToolTip'),
				iconCls: 'wg-toolbar-add',
				handler: function() {
					settingsItemAdd(item.id, item.text, grid)
				}
			},
			'-', {
				text: settingsl('tabButtonCopy'),
				tooltip: settingsl('tabButtonCopyToolTip'),
				iconCls: 'wg-toolbar-copy',
				handler: function() {
					settingsItemCopy(grid)
				}
			},
			'-', {
				text: settingsl('tabButtonDel'),
				tooltip: settingsl('tabButtonDelToolTip'),
				iconCls: 'wg-toolbar-del',
				handler: function() {
					Ext.Msg.confirm(settingsl('dlgTitleDeleteItem'), settingsl('dlgMsgDeleteItem'),
					function(btn) {
						if (btn == 'yes') {
							settingsItemDelete(item.id, item.text, grid)
						}
					})
				}
			}],
			bbar: new Ext.PagingToolbar({
				pageSize: settingsPerPage,
				id: 'settings-item-grid-bbar-' + item.id,
				store: grid.store,
				displayInfo: true,
				displayMsg: settingsl('dlgMsgTopics'),
				afterPageText: settingsl('dlgMsgAfterPage'),
				beforePageText: settingsl('dlgMsgBeforePage'),
				nextText: settingsl('dlgMsgNextText'),
				prevText: settingsl('dlgMsgPrevText'),
				firstText: settingsl('dlgMsgFirstText'),
				lastText: settingsl('dlgMsgLastText'),
				refreshText: settingsl('dlgMsgRefreshText'),
				emptyMsg: settingsl('dlgMsgNoTopics')
			}),
			items: [grid],
			iconCls: 'wg-tab-folder',
			closable: true,
			height: '100%',
			autoHeigh: true,
			autoScroll: true,
			deferredRender: false,
			layout: 'fit'
		}).show();

		//tabs.doLayout();
		//Ext.getCmp('viewport').fireEvent('resize');
		var ddrow = new Ext.dd.DropTarget(grid.getView().mainBody, {
			ddGroup: 'settingsGridDD',
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
				if (!this.copy) {
					for (i = 0; i < rows.length; i++) {
						ds.remove(ds.getById(rows[i].id));
					};
				};
				ds.insert(cindex, data.selections);
				sm.selectRecords(rows);
				//storeData(ds);  
			}
		});
	}
}
	
function settingsCategoriesOnBeforeNodeDrop(e) {
	new Ext.LoadMask(Ext.getCmp('settings-win').getEl(), { msg: settingsl('dlgMsgLoading') } ).show();
	
	var s = e.data.selections;
	var a = e.target.id;
	var t = e.source;
	if (s) {
		var w = new Array();
		for (i = 0; i < s.length; i++) {
			w[i] = s[i].id;
		}
		Ext.Ajax.request({
			url: settingsModulePath + '/item.cgi',
			success: function() {
				s[0].store.reload();
				Ext.getCmp('settings-win').getEl().unmask();
			},
			failure: function() {
				Ext.getCmp('settings-win').getEl().unmask();
				alert('failure')
			},
			params: {
				action: 'settings_item_move',
				src: w.join(','),
				dst: a
			}
		});
	}
	else	{
		Ext.Ajax.request({
			url: settingsModulePath + '/category.cgi',
			success: function() {
				if (e.point == 'append') {
					e.target.reload();
				} else if( e.target.parentNode ) {
					e.target.parentNode.reload();
				}
				Ext.getCmp('settings-win').getEl().unmask();
			},
			failure: function() {
				Ext.getCmp('settings-win').getEl().unmask();
				alert('failure')
			},
			params: {
				action: 'settings_category_move',
				src: e.dropNode.id,
				dst: e.target.id,
				point: e.point
			}
		});
	}
}




//function settingsTreeOnBeforeNodeDrop(e)    {
//    var s = e.data.selections;
//    var a = e.target.id;
//    var t = e.source;
//    if(s)   {
//	var w = new Array();
//	for( i = 0; i < s.length; i++ )	{
//	    w[i] = s[i].id;
//	}
//
//	Ext.Ajax.request({
//	    url: settingsModulePath + '/edit.cgi'
//	    ,success: function(){ s[0].store.reload() }
//	    ,failure: function(){ alert('failure') }
//	    ,params: { action: 'settings_item_move', src: w.join(','), dst: a }
//	});
//    }
//}

//function settingsTreeOnMoveNode( tree, node, oldParent, newParent, index )	{
//    Ext.Ajax.request({
//	url: settingsModulePath + '/edit_category.cgi'
//	,success: function(){ newParent.reload() }
//	,failure: function(){ alert('failure') }
//	,params: { action: 'settings_category_move', src: node.id, dst: newParent.id }
//    });
//}

//function settingsTreeOnClick( item, e )	{
//	var tabs = Ext.getCmp('tabs');
//	if( tabs.items.get('settings_'+item.id) )	{
//		tabs.setActiveTab('settings_'+item.id);
//	}	
//	else	{
//
//	 var grid;
//	    Ext.Ajax.request({
//		url: settingsModulePath+'/edit_field.cgi'
//		,success: function(t){ 
//			var obj = eval('('+t.responseText+')');
//			grid = settingsItemGridPanel( item.id, obj.rows ); 
//
//
//
//    tabs.add({
//	title: settingsLang['tabTitleFolder']+' : '+item.text
//	,id: 'settings_'+item.id
//	,tbar:[
//	{
//            text:settingsLang['tabButtonAddText']
//            ,tooltip: settingsLang['tabButtonAddToolTip']
//            ,iconCls:'add'
//	    ,handler: function() { settingsItemAdd( item.id, item.text, grid ) }
//        } 
//	,'-'
//	,{
//            text: settingsLang['tabButtonDelText']
//            ,tooltip: settingsLang['tabButtonDelToolTip']
//            ,iconCls:'remove'
//	    ,handler: function() { Ext.Msg.confirm(settingsLang['dlgTitleDeleteItem'],settingsLang['dlgMsgDeleteItem'],function(btn){ if(btn == 'yes'){settingsItemDelete( item.id, item.text, grid )} })}
//        }
//	,'-'
//	,{
//            text: settingsLang['tabButtonRefreshText']
//            ,tooltip:settingsLang['tabButtonRefreshToolTip']
//            ,iconCls:'reload'
//	    ,handler: function() { grid.getStore().reload() } 
//        }
//	,'-'
//	,{
//            text:'set property' 
//            ,iconCls:'add'
//	    ,handler: function() { 
//			var fname = prompt("field name",""); 
//			var fval = prompt("field val","");
//			var all = confirm('all?');
//			if( all )	{
//				all = 1;
//			}
//			else	{
//				all = 0;
//			}
// 
//			    var y = Ext.getCmp('settings_item_grid_'+item.id).getSelectionModel().getSelections(); 
//			    var a = [];
//			    for( var x = 0; x < y.length; x++ )	{
//				a[x] = y[x].id;
//			    }
//
//			if( fname.length > 0 )	{
//			    Ext.Ajax.request({
//				url: settingsModulePath+'/edit.cgi'
//				,success: function(){ grid.getStore().reload() }
//				,failure: function(){ alert('failure') }
//				,params: { action: 'settings_item_set_prop', id: a.toString(), fname:fname, pid:item.id, fval:fval, all:all }
//			    });
//			}
//		} 
//        }
//	,'-'
//	,{
//            text:'Заменить' 
//            ,iconCls:'add'
//	    ,handler: function() { 
//		    settingsFindReplaceForm( item.id, item.text, grid );
//		} 
//        }
//	]
//	,items: [grid]
//        ,closable:true
//	,height:'100%'
//	,autoHeigh:true
//	,autoScroll:true
//	,layout: 'fit'
//    }).show();
//
//    tabs.doLayout();
//	Ext.getCmp('viewport').fireEvent('resize');
//
//
//			//alert( obj.rows.length );
//		 }
//		,failure: function(){ alert('failure') }
//		,params: { action: 'settings_field_list', pid: item.id }
//	    });
//
//	}	
//}




function settingsFindReplaceForm( item_id, title, grid ){
	var settingsFindReplaceWhere = [
		[1,'обозначении'],
		[2,'названии'],
		[3,'поле']
	];

	var settingsFindReplaceStore = new Ext.data.SimpleStore({
		fields: [
		   {name: 'id'},
		   {name: 'text'}
		]
	});

	settingsFindReplaceStore.loadData(settingsFindReplaceWhere);

	var simple = new Ext.FormPanel({
	    labelWidth: 100, 
	    url:settingsModulePath+'/item.cgi',
	    border: false,
	    bodyStyle:'padding: 5px',
	    width: '100%',
	    defaults: {width: '100%'},
	    defaultType: 'textfield',
	    autoHeight: true,
	    items: [
		{
                xtype: 'combo'
		,store: settingsFindReplaceStore
                ,fieldLabel: 'Искать в'
                ,name: 'where_id_old'
                ,hiddenName: 'where_id'
                ,id: 'settings_where_id'
                ,displayField: 'text'
                ,valueField: 'id'
                ,allowBlank: false
                ,mode: 'local'
                }
		,{
		fieldLabel: 'Название поля'
		,name: 'field_name'
		}
		,{
		fieldLabel: 'Найти'
		,name: 'find'
                ,allowBlank: false
		}
		,{
		fieldLabel: 'Заменить на'
		,name: 'replace'
		}
		,{
                xtype: 'radiogroup',
                allowBlank: false,
                fieldLabel: 'Где',
                items: [
                    {boxLabel: 'в выбраном', name: 'area_id', inputValue: 1,  checked: true},
                    {boxLabel: 'в разделе', name: 'area_id', inputValue: 2 },
                ]
            	}
		,{
                xtype: 'checkboxgroup',
                fieldLabel: 'Опции',
                items: [
                    {boxLabel: 'Заменить все', name: 'replace_all', inputValue: 1 },
                    {boxLabel: 'RegEx', name: 'regexp', inputValue: 1, checked: true },
                    {boxLabel: 'Регистр', name: 'case', inputValue: 1, checked: true },
                ]
            }
	    ]
        ,buttons: [
	{
            text: settingsLang['formButtonSave'],
		handler: function(){
		    var y = grid.getSelectionModel().getSelections(); 
		    var a = [];
		    for( var x = 0; x < y.length; x++ )	{
			a[x] = y[x].id;
		    }

		    simple.getForm().baseParams = { parent_id:item_id, id:a.toString(), action:'settings_item_find_replace' };
		    simple.getForm().submit({ waitMsg: settingsLang['dlgMsgSaving'],success:function(){ grid.getStore().reload() } });
        	}
        }
	,{
            text: settingsLang['formButtonCancel']
		,handler: function(){ win.destroy(); }
        }
	]
    		});


	var win = settingsTreeWindow( 'Find Replace '+title );
	win.setWidth(470);
	win.setHeight(250);
	win.add(simple);
	win.render();

}



function settingsTreeOnContextMenu( item, e){
    settings_context_item = item;
    var m = settingsTree.getSelectionModel();
    m.select(item);
    var menu = new Ext.menu.Menu([
    {	
	id: 'properties'
	,text: settingsLang['labelProperties']
	,handler : settingsHandlerCategoryProperties
    },
    {	
	id: 'add_new'
	,text: settingsLang['labelAdd']
	,handler : settingsHandlerCategoryProperties
    },
    {	
	id: 'fields'
	,text: settingsLang['labelFields']
	,handler : function( menu ) { settingsFieldContext( item ) }
    },
    {
	id: 'refresh'
	,text: settingsLang['labelRefresh']
	,handler : function( ){
	    var i = m.getSelectedNode();
	    item.reload();				
	}
    },
    {
	id: 'delete'
	,text: settingsLang['labelDelete'] 
	,handler : function( ){
	    if( confirm(settingsLang['labelDelete']+'?') )	{
		var opt = {
		    method: 'post',
		    postBody: 'id='+item.id+'&action=settings_category_delete',
		    onSuccess: function() { settingsTree.root.reload() }
		}
		new Ajax.Request( settingsModulePath+ '/category.cgi', opt );
	    }
	}
    }
    ]);
    menu.showAt(e.getPoint());
}

function settingsHandlerCategoryProperties( e )	{
	var m = settingsTree.getSelectionModel();
	m.select(settings_context_item);
	var item = settings_context_item;
	
	var addnew = 0;
	if( e.id == 'add_new' ){ addnew = 1 }

	var i = m.getSelectedNode();
	var json;
	var opt = {
		method: 'post',
		postBody: 'id='+item.id+'&action=settings_category_properties_view&add='+addnew,
		asynchronous:false,
		onSuccess: function(req){
			var tt = 'json = '+req.responseText ;
			eval( tt );
		}
	}
	new Ajax.Request( settingsModulePath+'/category.cgi', opt );

	var simple = new Ext.FormPanel({
	    labelWidth: 85, 
	    url:settingsModulePath+'/category.cgi',
	    border: false,
	    bodyStyle:'padding: 0',
	    width: '100%',
	    defaults: {width: '100%'},
	    defaultType: 'textfield',
	    autoHeight: true,
	    items: {
		xtype:'tabpanel',
		activeTab: 0,
		defaults:{autoHeight:true, bodyStyle:'padding:10px', width:'100%'}, 
		items:[
		    {
		    title: settingsLang['tabTitleGeneral'],
		    layout:'form',
		    border: false,
		    defaults: {width: '100%'},
		    defaultType: 'textfield',

		    items: [
                        {
                        fieldLabel: settingsLang['labelID'],
                        name: 'id',
                        value:  json.id,
                        readOnly: 'true'
                        }
                        ,{
                        fieldLabel: settingsLang['labelParent'],
                        value: json.parent_name + ' ['+json.parent_id+']',
                        readOnly: 'true'
                        },
                        {
                        fieldLabel: settingsLang['labelInserted'],
                        name: 'inserted',
                        value: json.inserted,
                        disabled: 'true'
                        },
                        {
                        fieldLabel: settingsLang['labelName'],
                        name: 'name',
                        allowBlank: 'false',
                        value: json.name
                        },
                         {
                        fieldLabel: settingsLang['labelOrdering'],
                        name: 'ordering',
                        value: json.ordering
                        }
		    ]
		    

	    },
		    {
		    title: settingsLang['tabTitleLocalization'],
		    layout:'form',
		    border: false,
		    defaults: {width: 230},
		    defaultType: 'textfield',
		    id: 'aliases',
		    items: json.items_l10n
		    },
		 {
                    title: settingsLang['tabTitleAccess']
                    ,layout:'form'
                    ,border: false
                    ,defaultType: 'textfield'
                    ,items:[ settingsCategoryAccessGrid( item.id, json.items_actions) 
 			,{
                                fieldLabel: 'Рекурсивно для каталогов',
                                width: 300,
                                inputType: 'checkbox',
                                name: 'raccess_category',
                                value: '1',
                                checked: true
                        }
                        ,{
                                fieldLabel: 'Рекурсивно для полей',
                                labelWidth: 200,
                                inputType: 'checkbox',
                                name: 'raccess_field',
                                value: '1',
                                checked: true
                        }
                        ,{
                                fieldLabel: 'Рекурсивно для элементов',
                                labelWidth: 200,
                                inputType: 'checkbox',
                                name: 'raccess_item',
                                value: '1',
                                checked: true
                        }
			]
                }
	    ,{
		    title: settingsLang['tabTitleOptions'],
		    layout:'form',
		    defaults: {width: 230},
		    defaultType: 'textfield',
		    id: 'flags',
		    items: json.items_flags
	    }

//		    {
//		    title:'Реквизиты',
//		    layout:'form',
//		border: false,
  //              defaults: {width: 230},
    //            defaultType: 'textfield',
//		id: 'xoxoxo'
//		}
]
},
        buttons: [
	{
            text: settingsLang['formButtonSave'],
		handler: function(){
		    var gg = Ext.getCmp('settings_category_access_grid').getStore().getModifiedRecords();
		    var h = new Array();
		    for( i = 0; i < gg.length ; i++ )  {
			h[i] = gg[i].data;
		    }
		    simple.getForm().baseParams = {access:Ext.encode(h), parent_id:json.parent_id, action:'settings_category_update' };
		    simple.getForm().submit({ waitMsg: settingsLang['dlgMsgSaving'], success:function(){ win.destroy(); item.reload() }});
        	}
        }
	,{
            text: settingsLang['formButtonRefresh'],
		handler: function(){
		    var gg = Ext.getCmp('settings_category_access_grid').getStore().getModifiedRecords();
		    var h = new Array();
		    for( i = 0; i < gg.length ; i++ )  {
			h[i] = gg[i].data;
		    }
		    simple.getForm().baseParams = {access:Ext.encode(h), parent_id:json.parent_id, action:'settings_category_update' };
		    simple.getForm().submit({ waitMsg: settingsLang['dlgMsgSaving'], success:function(){ Ext.getCmp('settings_category_access_grid').getStore().commitChanges(); item.reload() }});
        	}
        }
	,{
            text: settingsLang['formButtonCancel']
		,handler: function(){ win.destroy(); }
        }
	]
    });

    var title;
    if( addnew )	{
	    title = settingsLang['tabTitleAddToDir']+' "'+i.text+'"';
    }
    else	{
	    title = settingsLang['tabTitleDirProperties']+ ' "'+i.text+'"';
    }

	var win = settingsTreeWindow( title );
	win.add(simple);
	win.render();
}

//function settingsTreeWindow( title )	{
//	var win = new Ext.Window({
//            title: title
//            ,closable:true
//            ,width:600
//            ,height:350
//            ,plain:false
//	    ,autoScroll: true
//        });
//
//        win.show();
//	return( win );	
//}


//-------------------------------------------------------------
//    settings ITEM
//-------------------------------------------------------------

function settingsItemAdd( pid, alias, grid )	{
    var form = new Ext.FormPanel({
	labelWidth: 85 
	,url:settingsModulePath+'/item.cgi'
	,border: false
	,bodyStyle:'padding: 10'
	,width: '100%'
	,defaults: {width: '100%'}
	,defaultType: 'textfield'
	,autoHeight: true
	,items: [
	{
		inputType: 'hidden'
		,name: 'action'
		,value: 'settings_item_add'
	}
	,{
		inputType: 'hidden'
		,name: 'parent_id'
		,value: pid
	}
	,{
		fieldLabel: 'Имя'
		,name: 'name'
		,allowBlank:false
	}
	//,{
	//	fieldLabel: 'Обозначение'
	//	,name: 'alias'
	//	,allowBlank:false
	//}
	]
	,buttons: [
	{
	    text: 'Сохранить'
	    ,handler: function(){
		form.getForm().submit({ waitMsg:'Сохранение...', success:function(){ win.destroy(); grid.getStore().reload()  }});
	    }
	}
	,{
	    text: 'Отменить'
	    ,handler: function(){
		win.destroy(); 
	    }
	}
	]
    });

    form.doLayout();

    var win = new Ext.Window({
	    title: 'Добавить элемент в "'+alias+'"'
	    ,closable:true
	    ,width:400
	    ,height:140
	    ,items: [form]
    });

    win.show();
}

function settingsItemDelete( pid, alias, grid )	{
    var y = grid.getSelectionModel().getSelections(); 
    var a = [];
    for( var x = 0; x < y.length; x++ )	{
	a[x] = y[x].id;
    }

    Ext.Ajax.request({
	url: settingsModulePath+'/item.cgi'
	,success: function(){ grid.getStore().reload() }
	,failure: function(){ alert('failure') }
	,params: { action: 'settings_item_delete', id: a.toString() }
    });

}

function settingsItemGridColumnModel() {
	var cm = new Ext.grid.ColumnModel([{
		header: settingsl('labelID'),
		dataIndex: 'id',
		width: 50
	}]);

	cm.defaultSortable = true;
	return (cm);
}

function settingsItemGridStore(pid, grid) {
	var store = new Ext.data.Store({
		proxy: new Ext.data.HttpProxy({
			url: settingsModulePath + '/item.cgi'
		}),
		reader: new Ext.data.JsonReader(),
		baseParams: {
			action: 'settings_items_list'
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
				column.header = settingsl(column.header);
				columns.push(column);
			});
			if (grid) grid.getColumnModel().setConfig(columns);
		}
		//this.el.unmask();
	});

	store.load({
		params: {
			start: 0,
			limit: settingsPerPage,
			pid: pid
		}
	});
	return (store);
}

function settingsItemGridPanel(pid) {
	var grid = new Ext.grid.GridPanel({
		width: '100%',
		cm: settingsItemGridColumnModel(),
		ddGroup: 'settingsGridDD',
		autoScroll: true,
		enableDragDrop: true,
		loadMask: true,
		id: 'settings_item_grid_panel' + pid,
		viewConfig: {
			forceFit: true
		}
	});
	
	var store = settingsItemGridStore(pid, grid);

	grid.store = store;
	grid.on('rowdblclick', settingsItemGridOnRowDblClick);
	return (grid);
}


function settingsItemGridOnRowDblClick_new(grid, rowIndex, e) {
	var tabs = Ext.getCmp('settings-tabs');
	var record = grid.getStore().getAt(rowIndex);
	
	if (tabs.items.get('settings_item_tab_' + record.id) ) {
		tabs.setActiveTab('settings_item_tab_' + record.id);
	} else {
		new Ext.LoadMask(Ext.getCmp('settings-win').getEl(), {
			msg: settingsl('dlgMsgLoading')
		}).show();

		Ext.Ajax.request({
			url: settingsModulePath + '/item.cgi',
			success: function(req) {
				Ext.getCmp('settings-win').getEl().unmask();
				var obj;
				var tt = 'obj = ' + req.responseText;
				eval(tt);
				
				for( var i = 0; i < obj.l10n.items.length; i++ )	{
					for( var j = 0; j < obj.l10n.items[i].items.length; j++ )	{
						obj.l10n.items[i].items[j].fieldLabel = settingsl( obj.l10n.items[i].items[j].fieldLabel );
					}
				}
				
				for( var i = 0; i < obj.flags.length; i++ )	{
						obj.flags[i].fieldLabel = settingsl( obj.flags[i].fieldLabel);
				}
				settingsItemTab(record, obj);
			},
			failure: function() {
				Ext.getCmp('settings-win').getEl().unmask();
				alert('failure');
			},
			params: {
				action: 'settings_item_view',
				id: record.id
			}
		});
	}
}


// cut this to fuck
function settingsItemGridOnRowDblClick(grid,rowIndex,e)	{
    var tabs = Ext.getCmp('settings-tabs');
    var record = grid.getStore().getAt(rowIndex); 
    var title = record.get('alias');
    if( record.get('alias').length > 0 )    {
	title = record.get('alias');
    }
    else    {
	title = record.get('id');
    }

    tabs.add({
	title: 'Элемент: '+title 
	,id: 'settings_item_'+record.id
	,html: '<iframe src="'+settingsModulePath+'/item.cgi?id='+record.id+'" width="100%" height="100%" frameborder=0></iframe>'
	,closable:true
    }).show();
    tabs.doLayout();
}










//---------------------------------------------------------
//     settings FIELD
//---------------------------------------------------------

function settingsFieldDelete( pid, alias, grid )	{
    var y = grid.getSelectionModel().getSelections(); 
    var a = [];
    for( var x = 0; x < y.length; x++ )	{
	a[x] = y[x].id;
    }

    Ext.Ajax.request({
	url: settingsModulePath+'/field.cgi'
	,success: function(){ grid.getStore().reload() }
	,failure: function(){ alert('failure') }
	,params: { action: 'settings_field_delete', id: a.toString() }
    });

}


function settingsFieldGridStore( pid )	{
    var store = new Ext.data.Store({
        proxy: new Ext.data.HttpProxy({
            url: settingsModulePath+'/field.cgi'
        })
        ,reader: new Ext.data.JsonReader({
                    totalProperty: 'totalCount'
                    ,root: 'rows'
                    ,id: 'id'
                    ,fields:['id','name','alias','inherit','type_alias']
                })
        ,remoteSort: true
	,baseParams: { action:'settings_field_list' }
    });

    //store.setDefaultSort('ordering', 'desc');
    store.load({params:{start:0, limit:settingsPerPage, pid:pid }});
    return( store );
}

function settingsFieldGridColumnModel ()	{
    var cm = new Ext.grid.ColumnModel([
	{
           header: settingsl('labelID')
           ,dataIndex: 'id'
           ,width: 20
        }
	,{
           header: settingsl('labelName')
           ,dataIndex: 'name'
           ,width: 200
        }
	,{
           header: settingsl('labelAlias')
           ,dataIndex: 'alias'
           ,width: 200
        }
	,{
           header: settingsl('labelType')
           ,dataIndex: 'type_alias'
           ,width: 100
        }
        ]);

    	//cm.defaultSortable = true;
	return( cm );
}

function settingsFieldGridPanel( pid )	{
    var grid = new Ext.grid.GridPanel({
	width:'100%'
        ,store: settingsFieldGridStore( pid )
	,cm: settingsFieldGridColumnModel()
	//,autoHeight: true
	//,height:'100%'
	,autoScroll: true
	,enableDragDrop: true
        ,loadMask: true
        ,viewConfig: {
            forceFit:true
        }
    });
	grid.getView().getRowClass = function(row, index) {
		if (row.data.inherit == 1) {
			return 'vasia-pupkin';
		}
	}
    grid.on('rowdblclick',function(grid,rowIndex,item) { settingsFieldEdit(grid,rowIndex,item,0) } );
    return( grid );
}

function settingsFieldEdit(grid,rowIndex,e,add) 	{
    var item = grid.getStore().getAt(rowIndex);
    var item_id;
    item_id = (item) ? item.id : 0;
    if( add )	{
	item_id = 0;
	item = null;
    }

    Ext.Ajax.request({
	url: settingsModulePath+'/field.cgi'
	,success: function(req){ 
	    var tt = 'json = '+req.responseText;
	    eval( tt );
	    settingsFieldEditWindow( item, json, grid );
	}
	,failure: function(){ alert('failure') }
	,params: { action: 'settings_field_view', id: item_id, pid:rowIndex  }
    });
}

function settingsFieldEditWindow( item, json, grid )   {
    //Ext.form.Field.prototype.msgTarget = 'side';
    var item_id;
    item_id = (item) ? item.id : 0;
    var form = new Ext.FormPanel({
	labelWidth: 85 
	,url:settingsModulePath+'/field.cgi'
	,border: false
	,bodyStyle:'padding: 0'
	,width: '100%'
	,defaults: {width: '100%'}
	,defaultType: 'textfield'
	,autoHeight: true
	,id: 'settings_field_edit_form'
	,items: 
	{
	    xtype:'tabpanel'
	    ,activeTab: 0
	    ,id:'settings_field_tabs_'+item_id
	    ,defaults:{ autoHeight:true, bodyStyle:'padding:5px', width:'500'}
	    ,items:[
	    {
		title:'Общие'
		,layout:'form'
		,border: false
		,defaults: { width: '100%' }
		,defaultType: 'textfield'
		,id:'settings_field_common_'+item_id
		,items: [
/*		{
		    inputType: 'hidden'
		    ,name: 'parent_id'
		    ,value: json.parent_id
		}
		,*/{
		    inputType: 'hidden'
		    ,name: 'id'
		    ,value: json.id
		}
		,{
		    fieldLabel: 'ID'
		    ,value: json.id
		    ,disabled: 'true'
		}
		,{
		    fieldLabel: 'Справочник'
		    ,value: json.parent_alias
		    ,disabled: 'true'
		}
		,{
		    fieldLabel: 'Создан'
		    ,value: json.inserted
		    ,disabled: 'true'
		}
		,{
		    fieldLabel: 'Имя'
		    ,name: 'name'
		    ,allowBlank: 'false'
		    ,value: json.name
		}
		,{
		    fieldLabel: 'Сортировка'
		    ,name: 'ordering'
		    ,value: json.ordering
		}
		,{
                xtype: 'combo'
		,height: '1px'
		,hideLabel: true
		,disabled:true
		,hidden:true
                }
		,{
                xtype: 'combo'
		,store: settingsFieldDataTypeStore()
                ,fieldLabel: 'Тип'
                ,name: 'type_id_old'
                ,hiddenName: 'type_id'
                ,id: 'settings_type_id'
                ,displayField: 'alias'
                ,valueField: 'id'
                ,allowBlank: 'false'
                ,mode: 'local'
		,disabled: true
                }
		,{
                xtype: 'combo'
		,store: settingsFieldConfigurationStore()
                ,fieldLabel: 'Группа'
                ,name: 'source_group_id_old'
                ,hiddenName: 'source_group_id'
                ,id: 'settings_source_group_id'
                ,displayField: 'alias'
                ,valueField: 'id'
                ,allowBlank: 'false'
                ,mode: 'local'
		,disabled: true
                }
		,{
                xtype: 'combo'
		//,store: settingsFieldCategoryStore(json.group_name)
                ,fieldLabel: 'Категория'
                ,name: 'source_id_old'
                ,hiddenName: 'source_id'
                ,id: 'settings_source_category_id'
                ,displayField: 'alias'
                ,valueField: 'id'
                ,allowBlank: 'false'
                ,mode: 'local'
		,disabled: true
                }

		]
	    }
	    ,{
                title:'Локализация'
                ,layout:'form'
		,border: false
                ,defaults: {width: '100%'}
                ,defaultType: 'textfield'
		,id: 'settings_field_aliases_'+item_id
		,items: json.items_l10n
	    }
		, {
                    title: settingsLang['tabTitleAccess']
                    ,layout:'form'
                    ,border: false
                    ,defaultType: 'textfield'
                    ,items:[ settingsFieldAccessGrid( item_id, json.items_actions) ]
                }
	    ,{
                title:settingsLang['tabTitleOptions']
                ,layout:'form'
                ,defaults: {width: 230}
                ,defaultType: 'textfield'
                ,id: 'settings_field_flags_'+item_id
		,items: json.items_flags
	    }

	    ]
	}
        ,buttons: [
	{
            text: settingsLang['formButtonSave'],
		handler: function(){
		    var gg = Ext.getCmp('settings_field_access_grid').getStore().getModifiedRecords();
		    var h = new Array();
		    for( i = 0; i < gg.length ; i++ )  {
			h[i] = gg[i].data;
		    }
		    form.getForm().baseParams = {access:Ext.encode(h), parent_id:json.parent_id, action:'settings_field_update' };
		    form.getForm().submit({ waitMsg: settingsLang['dlgMsgSaving'], success:function(){ win.destroy(); grid.getStore().reload() }});
        	}
        }
	,{
            text: settingsLang['formButtonRefresh'],
		handler: function(){
		    var gg = Ext.getCmp('settings_field_access_grid').getStore().getModifiedRecords();
		    var h = new Array();
		    for( i = 0; i < gg.length ; i++ )  {
			h[i] = gg[i].data;
		    }
		    form.getForm().baseParams = {access:Ext.encode(h), parent_id:json.parent_id, action:'settings_field_update' };
		    form.getForm().submit({ waitMsg: settingsLang['dlgMsgSaving'], success:function(){ Ext.getCmp('settings_field_access_grid').getStore().commitChanges(); grid.getStore().reload() }});
        	}
        }
	,{
            text: settingsLang['formButtonCancel']
		,handler: function(){ win.destroy(); }
        }
	]
    });

    Ext.getCmp('settings_type_id').on('select', settingsFieldConfiguration  );
    Ext.getCmp('settings_source_group_id').on('select', settingsFieldCategory  );

    if( item_id )  {
	Ext.getCmp('settings_type_id').setValue(json.type_alias);	
	Ext.getCmp('settings_source_group_id').setValue(json.group_alias);	
	Ext.getCmp('settings_source_category_id').store = settingsFieldCategoryStore(json.group_name);
	Ext.getCmp('settings_source_category_id').setValue(json.category_name);	
    }
    else    {
	Ext.getCmp('settings_type_id').disabled = false;
	Ext.getCmp('settings_source_group_id').disabled = false;
	Ext.getCmp('settings_source_category_id').disabled = false;
    }

    var title = 'Без имени';
    if( item_id )   {
	title = item.get('alias');
	if( item.get('alias').length > 0 )    {
	    title = item.get('alias');
	}
	else    {
	    title = item.get('id');
	}
    }

    var win = new Ext.Window({
	title: 'Поле "' + title+'"'
        ,closable:true
        ,width:700
        ,height:350
	//,autoScroll: true
        ,items: [form]
    });

    win.show();
} 

function settingsFieldConfiguration( combo, record, index ){
    var name = record.get('name');

    if( name == 'settings' )	{
	//Ext.getCmp('settings_source_group_id').hide();
	Ext.getCmp('settings_source_group_id').disabled = false;
	//Ext.getCmp('settings_source_group_id').show();
    }
    else    {
	//Ext.getCmp('settings_source_group_id').disabled = true;
    }
    //Ext.getCmp('settings_field_edit_form').doLayout();
}

function settingsFieldConfigurationStore()	{
    var store = new Ext.data.JsonStore({
	url: '/cgi-bin/wg/modules/configuration/category.cgi'
	,baseParams: { action:'configuration_store_list' }
	,fields: ['id', 'name','alias']
    });

    store.load();
    return( store );
}

function settingsFieldCategory( combo, record, index ){
    var name = record.get('name');
    Ext.getCmp('settings_source_category_id').store = settingsFieldCategoryStore( name );
}

function settingsFieldCategoryStore( name )	{
    var store = new Ext.data.JsonStore({
	url: '/cgi-bin/wg/modules/'+name+'/category.cgi'
	,baseParams: { action: name+'_category_flat' }
	,fields: ['id', 'alias']
    });

    if( name )   {
	store.load();
    }

    return( store );
}

function settingsFieldDataTypeStore()	{
    var store = new Ext.data.JsonStore({
	url: settingsModulePath+'/field.cgi'
	,baseParams: { action:'settings_datatypes' }
	,fields: ['id', 'alias']
    });
    
    store.load();
    return( store );
}


function settingsFieldContext( item )    {
    var grid = settingsFieldGridPanel( item.id );
    var win = new Ext.Window({
	title: 'Поля справочника "'+item.text+'"'
	,closable:true
	//,autoHeight:true
	,defaults : { height:300 }
	,width:700
	,height:'100%'
	//,layout:'fit'
	,items: [grid]
	,tbar:[
		{
            text:settingsl('labelRefresh')
            //,tooltip:'Обновить список'
            ,iconCls:'wg-toolbar-reload'
	    ,handler: function() { grid.getStore().reload() } 
        },'-',
	{
            text:settingsl('labelAdd')
            //,tooltip:'Добавить поле'
            ,iconCls:'wg-toolbar-add'
	    ,handler: function(){ settingsFieldEdit( grid, item.id, null, 1  )  }       
	},'-'
	,{
            text:settingsl('labelDelete')
            //,tooltip:'Удалить элементы'
            ,iconCls:'wg-toolbar-del'
	    ,handler: function() { Ext.Msg.confirm('Удаление элементов справочника','Удалить выбраные элементы?',function(btn){ if(btn == 'yes'){settingsFieldDelete( item.id, item.text, grid )} })}
        }	
	]
	,autoScroll: true
    });
    win.show();
}


//---------------------------------------------------------
//  CATEGORY PROPERTIES
//---------------------------------------------------------

var settingsFieldCM = new Array();
function settingsFieldAccessGridColumnModel ( actions )	{
    var cm;
    var cols = new Array( { header:"Group", dataIndex: 'name'} );
	    for( i = 0; i < actions.length; i++ )   {
		var checkColumn = new Ext.grid.CheckColumn({
		   header: settingsLang[actions[i].name],
		   tooltip: settingsLang[actions[i].name],
		   dataIndex: 'field_'+actions[i].id,
		   width: 75
		});
		cols[i+1] = checkColumn;
		settingsFieldCM[i] = checkColumn;
	    }
     cm = new Ext.grid.ColumnModel(
	cols	
        );

	return( cm );
}

function settingsFieldAccessGridStore( pid )	{
    var store = new Ext.data.JsonStore({
	url: settingsModulePath+'/field.cgi'
	,baseParams: { action:'settings_access_list', pid:pid }
    });

    store.load();
    return( store );
}

function settingsFieldAccessGrid( pid, actions )   {
    var grid = new Ext.grid.EditorGridPanel({
	width:'100%'
        ,store: settingsFieldAccessGridStore( pid )
	,cm: settingsFieldAccessGridColumnModel( actions ) 
	,id: 'settings_field_access_grid'
	,autoHeight: true
	,autoScroll: true
        ,loadMask: true
	,plugins: settingsFieldCM 
	,clicksToEdit:1
        ,viewConfig: {
            forceFit:true
        }
    });
    return( grid );
}


var settingsCM = new Array();
function settingsCategoryAccessGridColumnModel ( actions )	{
    var cm;
    var cols = new Array( { header:"Group", dataIndex: 'name'} );
	    for( i = 0; i < actions.length; i++ )   {
		var checkColumn = new Ext.grid.CheckColumn({
		   header: settingsLang[actions[i].name],
		   dataIndex: 'field_'+actions[i].id,
		    tooltip : settingsLang[actions[i].name],
		   width: 75
		});
		cols[i+1] = checkColumn;
		settingsCM[i] = checkColumn;
	    }
     cm = new Ext.grid.ColumnModel(
	cols	
        );

	return( cm );
}

function settingsCategoryAccessGridStore( pid )	{
    var store = new Ext.data.JsonStore({
	url: settingsModulePath+'/category.cgi'
	,baseParams: { action:'settings_access_list', pid:pid }
    });

    store.load();
    return( store );
}

function settingsCategoryAccessGrid( pid, actions )   {
    var grid = new Ext.grid.EditorGridPanel({
	width:'100%'
        ,store: settingsCategoryAccessGridStore( pid )
	,cm: settingsCategoryAccessGridColumnModel( actions ) 
	,id: 'settings_category_access_grid'
	,autoHeight: true
	,autoScroll: true
        ,loadMask: true
	,plugins: settingsCM 
	,clicksToEdit:1
        ,viewConfig: {
            forceFit:true
        }
    });
    return( grid );
}


//=========================================

//Ext.grid.CheckColumn = function(config){
//    Ext.apply(this, config);
//    if(!this.id){
//        this.id = Ext.id();
//    }
//    this.renderer = this.renderer.createDelegate(this);
//};
//
//Ext.grid.CheckColumn.prototype ={
//    init : function(grid){
//        this.grid = grid;
//        this.grid.on('render', function(){
//            var view = this.grid.getView();
//            view.mainBody.on('mousedown', this.onMouseDown, this);
//        }, this);
//    },
//
//    onMouseDown : function(e, t){
//        if(t.className && t.className.indexOf('x-grid3-cc-'+this.id) != -1){
//            e.stopEvent();
//            var index = this.grid.getView().findRowIndex(t);
//            var record = this.grid.store.getAt(index);
//            record.set(this.dataIndex, !record.data[this.dataIndex]);
//        }
//    },
//
//    renderer : function(v, p, record){
//        p.css += ' x-grid3-check-col-td'; 
//        return '<div class="x-grid3-check-col'+(v?'-on':'')+' x-grid3-cc-'+this.id+'">&#160;</div>';
//    }
//};


//-->
