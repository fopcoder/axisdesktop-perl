function basel(msg) {
	return l('base', msg);
}

function defined( v )	{
	return ( typeof(v) == "undefined" ) ? false: true;
}

function warn( m )	{
	window.console && console.log && console.log(m);
}

function failure_ajax( res, obj )	{
	var m = res.status +' '+res.statusText;
	failure( m );
}

function failure_form( f, a )	{
	failure( a.result.msg );
}

function failure( m )	{
	Ext.Msg.show({
		title: basel('dlgMsgFailure'),
		msg: m,
		minWidth: 250,
		modal: false,
		icon: Ext.MessageBox.ERROR,
		buttons: Ext.Msg.YES
	});
}

function msg( m )	{
	Ext.Msg.show({
		title: basel('dlgMsgMessage'),
		msg: m,
		minWidth: 250,
		modal: false,
		icon: Ext.MessageBox.WARNING,
		buttons: Ext.Msg.YES
	});
}

Ext.grid.CheckColumn = function(config) {
	Ext.apply(this, config);
	if (!this.id) {
		this.id = Ext.id();
	}
	this.renderer = this.renderer.createDelegate(this);
};

Ext.grid.CheckColumn.prototype = {
	init: function(grid) {
		this.grid = grid;
		this.grid.on('render',
		function() {
			var view = this.grid.getView();
			view.mainBody.on('mousedown', this.onMouseDown, this);
		},
		this);
	},

	onMouseDown: function(e, t) {
		if (t.className && t.className.indexOf('x-grid3-cc-' + this.id) != -1) {
			e.stopEvent();
			var index = this.grid.getView().findRowIndex(t);
			var record = this.grid.store.getAt(index);
			record.set(this.dataIndex, !record.data[this.dataIndex]);
		}
	},

	renderer: function(v, p, record) {
		p.css += ' x-grid3-check-col-td';
		return '<div class="x-grid3-check-col' + (v ? '-on': '') + ' x-grid3-cc-' + this.id + '">&#160;</div>';
	}
};