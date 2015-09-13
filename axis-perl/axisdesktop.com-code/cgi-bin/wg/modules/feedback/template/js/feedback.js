var feedbackModulePath = '/cgi-bin/wg/modules/feedback';
var feedbackPerPage = 50;

function feedbackl(msg) {
	return l('feedback', msg);
}

AxisDesktop.feedbackModule = Ext.extend(Ext.app.Module, {
	id:'tool-feedback',
    type: 'tool/feedback',

	init: function() {
		//this.locale = QoDesk.AccordionWindow.Locale;
	},

    createWindow : function(){
        var desktop = this.app.getDesktop();
        var win = desktop.getWindow('feedback-win');
        if(!win){
            //form = this.form();
            win = desktop.createWindow({
                id: 'feedback-win',
                title: feedbackl('titleMainWindow'),
                width: 500,
                height:400,
                minWidth: 300,
                minHeight: 300,
				tbar: [
					{
                text: feedbackl('labelSend'),
				iconCls: 'wg-toolbar-send',
                listeners: {
                    click: function() {
						var form = Ext.getCmp('feedback-form').getForm();
						form.baseParams = {
							action: 'feedback_send'
						};
						form.submit( {
							success: function(){ Ext.getCmp('feedback-win').close() },
							failure: function(){ alert('failure') }
						});
					}
                }
            },'-',{
                text: feedbackl('labelClose'),
				iconCls: 'wg-toolbar-close',
				listeners: {
                    click: function() {
						Ext.getCmp('feedback-win').close();
					}
                }
				
            }
				],
               // bodyStyle:'padding:5px;',
                iconCls: 'feedback-main-window',
                shim:false,
                animCollapse:false,
                border:false,
                constrainHeader:true,
                layout: 'fit',
                items:[ feedbackForm() ]                
            });
        }
        win.show();
        
        Ext.Ajax.request({
            url: feedbackModulePath + '/index.cgi',
            success: function( req ) {
                var obj;
                eval('obj = ' + req.responseText);
                Ext.getCmp('feedback-form-from').setValue( obj.email );
            },
            failure: function() {
                alert('failure')
            },
            params: {
                action: 'feedback_load'
            }
        });
    }
});

function feedbackForm()	{
	if( Ext.getCmp('feedback-form') )    {
		return Ext.getCmp('feedback-form');
	}
	else    {
	var form = new Ext.form.FormPanel({
		labelWidth: 130,
		id: 'feedback-form',
		url: feedbackModulePath + '/index.cgi',
		defaultType: 'textfield',
		bodyStyle:'padding:5px;',
		items: [
		{
			fieldLabel: feedbackl('labelTo'),
			name: 'to',
			allowBlank: false,
			readOnly: true,
			anchor:'100%',
			value: 'Anatoliy Podlesnuk <cms@axisdesktop.com>'
		},
		{
			fieldLabel: feedbackl('labelFrom'),
			name: 'from',
			readOnly: true,
			id: 'feedback-form-from',
			anchor:'100%'
		},
		{
			fieldLabel: feedbackl('labelSubject'),
			name: 'subject',
			allowBlank: false,
			blankText: feedbackl('msgRequiredField'),
			anchor:'100%'
		},
		{
			xtype: 'textarea',
			hideLabel: true,
			name: 'message',
			blankText: feedbackl('msgRequiredField'),
			allowBlank: false,
			anchor: '100% -53'
		}
		]
	});
	return form;
	}
}



