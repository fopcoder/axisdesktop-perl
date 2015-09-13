var profileModulePath = '/cgi-bin/wg/modules/profile';
var profilePerPage = 50;

function profilel(msg) {
	return l('profile', msg);
}

AxisDesktop.profileModule = Ext.extend(Ext.app.Module, {
	id:'tool-profile',
    type: 'tool/profile',

	init: function() {
		//this.locale = QoDesk.AccordionWindow.Locale;
	},

    createWindow : function(){
        this.profileLoad();
    },
    profileLoad: function ()  {
        var mod = this;
        Ext.Ajax.request({
            url: profileModulePath + '/index.cgi',
            success: function( req ) {
                var obj;
                eval('obj = ' + req.responseText);
                mod.profileShowWindow( obj );
            },
            failure: function() {
                alert('failure')
            },
            params: {
                action: 'profile_load'
            }
        });
    },
    profileShowWindow: function( obj )   {
        var desktop = this.app.getDesktop();
        var win = desktop.getWindow('profile-win');
        if(!win){
            form = this.profileForm( obj );
            win = desktop.createWindow({
                id: 'profile-win',
                title: profilel('titleMainWindow'),
                width: 500,
                height:400,
                minWidth: 300,
                minHeight: 300,
               // bodyStyle:'padding:5px;',
                iconCls: 'profile-main-window',
                shim:false,
                animCollapse:false,
                border:false,
                constrainHeader:true,
                layout: 'fit',
				tbar: [{
                text: profilel('labelSave'),
				iconCls: 'wg-toolbar-save',
                listeners: {
                    click: function() {
						if( profileValidateForm() )	{
							var form = Ext.getCmp('profile-form').getForm();
							form.baseParams = {
								action: 'profile_update'
							};
							form.submit( {
								success: function(){ Ext.getCmp('profile-win').close() },
								failure: function(){ alert('failure') }
							});
						}
					}
                }
            },'-',{
                text: profilel('labelClose'),
				iconCls: 'wg-toolbar-close',
				listeners: {
                    click: function() {
						Ext.getCmp('profile-win').close();
					}
                }
				
            }],
                items:[ form ]                
            });
        }
        win.show();
    },
    profileForm: function ( obj){
        if( Ext.getCmp('profile-form') )    {
            return Ext.getCmp('profile-form');
        }
        else    {
        var form = new Ext.form.FormPanel({
            labelWidth: 130,
            id: 'profile-form',
            url: profileModulePath + '/index.cgi',
            defaultType: 'textfield',
            bodyStyle:'padding:5px;',
            items: [
				{
					inputType: 'hidden',
					id: 'profile-valid-email',
					value: 1
				},
				{
					inputType: 'hidden',
					id: 'profile-valid-login',
					value: 1
				},
				{
					inputType: 'hidden',
					id: 'profile-valid-password',
					value: 1
				},
                {
            xtype:'fieldset',
            title: profilel('labelGeneral'),
            collapsible: true,
            autoHeight:true,
            defaults: {width: 210},
            defaultType: 'textfield',
            items :[
                    {
                fieldLabel: profilel('labelEmail'),
                name: 'email',
                id: 'profile-form-email',
                allowBlank: false,
                anchor:'100%',
                value: obj.email,
				enableKeyEvents: true,
				validationEvent: false,
                listeners: {
					keyup: function( o, e ) { profileValidateEmail( o )  }
                }
            },
            {
                fieldLabel: profilel('labelLogin'),
                name: 'name',
                id: 'profile-form-login',
                anchor:'100%',
                value: obj.login,
				enableKeyEvents: true,
				validationEvent: false,
                listeners: {
					keyup: function( o, e ) { profileValidateLogin( o )  }
                }
            }]},
            {
            xtype:'fieldset',
            title: profilel('labelChangePassword'),
            collapsible: true,
            autoHeight:true,
            defaults: {width: 210},
            defaultType: 'textfield',
            items :[
            {
                inputType:'password',
                fieldLabel: profilel('labelPassword'),
                name: 'password',
                id: 'profile-form-password',
                anchor: '100%'  // anchor width by percentage
            },
            {   
                inputType:'password',
                fieldLabel: profilel('labelRePassword'),
                name: 'repassword',
                id: 'profile-form-repassword',
                anchor: '100%'  // anchor width by percentage
            }
            ]},
            {
            xtype:'fieldset',
            title: profilel('labelLocalization'),
            collapsible: true,
            autoHeight:true,
            defaults: {width: 210},
            defaultType: 'textfield',
            items :[
            obj.l10n
            ]}
            ]
        });
        return form;
        }
    }
});

function profileValidateForm()  {
	profileValidatePassword();
	
	if( parseInt( Ext.getCmp('profile-valid-login').getValue() ) &&
		parseInt( Ext.getCmp('profile-valid-email').getValue() ) &&
		parseInt( Ext.getCmp('profile-valid-password').getValue() ) )	{
		return true;
	}

	return false;
}

function profileValidateEmail( obj ) {
	var hobj = Ext.getCmp('profile-valid-email');

    if( obj.getValue().length > 0  )  {
        Ext.Ajax.request({
            url: profileModulePath + '/index.cgi',
            success: function( req ) {
                var res;
                eval('res = ' + req.responseText);
                if( res.valid == 0 )    {
					obj.markInvalid( profilel('msgEmailExists') );
					hobj.setValue(0);
                }
                else    {
					hobj.setValue(1);
                    obj.clearInvalid();
                }
            },
            failure: function() {
                alert('failure');
                //obj.clearInvalid();
            },
            params: {
                action: 'profile_validate_email',
                email: obj.getValue()
            }
        });
    }
    else    {
        obj.markInvalid( profilel('msgZeroLength') );
		hobj.setValue(0);
    }
}

function profileValidateLogin( obj ) {
	var hobj = Ext.getCmp('profile-valid-login');
	
    if( obj.getValue().length > 0  )  {
        Ext.Ajax.request({
            url: profileModulePath + '/index.cgi',
            success: function( req ) {
                var res;
                eval('res = ' + req.responseText);
                if( res.valid == 0 )    {
                    obj.markInvalid( profilel('msgLoginExists') );
					hobj.setValue(0);
                }
                else    {
					hobj.setValue(1);
					obj.clearInvalid();
                }
            },
            failure: function() {
                alert('failure');
				//obj.clearInvalid();
				//hobj.setValue(1);
            },
            params: {
                action: 'profile_validate_login',
                login: obj.getValue()
            }
        });
    }
    else    {
        obj.markInvalid( profilel('msgZeroLength') );
		hobj.setValue(0);
    }
}

function profileValidatePassword() {
    var obj= Ext.getCmp('profile-form-password');
    var reobj= Ext.getCmp('profile-form-repassword');
	var hobj = Ext.getCmp('profile-valid-password');

	if( obj.getValue().length > 0 )	{
		if( obj.getValue().length < 6 && obj.getValue().length > 0 )	{
			obj.markInvalid( profilel('msgPasswordInvalid') );
			reobj.markInvalid( profilel('msgPasswordInvalid') );
			hobj.setValue(0);		
		}
		else if( obj.getValue() == reobj.getValue() )    {
			obj.clearInvalid();
			reobj.clearInvalid();
			hobj.setValue(1);
		}
		else    {
		    obj.markInvalid( profilel('msgPasswordNE') );
		    reobj.markInvalid( profilel('msgPasswordNE') );
			hobj.setValue(0);
		}
	}
}


