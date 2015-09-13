
Ext.ns('Ext.ux.panel.CodeMirrorConfig');
Ext.apply(Ext.ux.panel.CodeMirrorConfig, {
    cssPath: "/res/codemirror/css/",
    jsPath: "/res/codemirror/js/"
});

Ext.apply(Ext.ux.panel.CodeMirrorConfig, {
    parser: {
		txt: {
			parserfile: ["parsedummy.js"],
            stylesheet: ''
		},
        css: {
            parserfile: ["parsecss.js"],
            stylesheet: Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"
        },
        js: {
            parserfile: ["tokenizejavascript.js", "parsejavascript.js"],
            stylesheet: Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css"
        },
        php: {
            parserfile: ["parsexml.js",	"parsecss.js", "tokenizejavascript.js",	"parsejavascript.js", "../contrib/php/js/tokenizephp.js", "../contrib/php/js/parsephp.js", "../contrib/php/js/parsephphtmlmixed.js"],
            stylesheet: [ Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css",  Ext.ux.panel.CodeMirrorConfig.cssPath + "../contrib/php/css/phpcolors.css"	 ]
        },
        htm: {
            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
            stylesheet: [Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"]
            
        },
        html: {
            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
            stylesheet: [Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"]
            
        },
        xml: {
            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
            stylesheet: [Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"]
            
        }
		,tpl: {
            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
            stylesheet: [Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"]
        }
		,ax: {
            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
            stylesheet: [Ext.ux.panel.CodeMirrorConfig.cssPath + "xmlcolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "jscolors.css", Ext.ux.panel.CodeMirrorConfig.cssPath + "csscolors.css"]
        }
    }
});

Ext.ns('Ext.ux.panel.CodeMirror');
Ext.ux.panel.CodeMirror = Ext.extend(Ext.Panel, {
    sourceCode: '',
    initComponent: function() {
        this.contentChanged = false;
        var oThis = this;
        Ext.apply(this, {
            items: [{
                xtype: 'textarea',
                readOnly: false,
                hidden: true,
				value: this.value,
				name: this.name,
				itemId: this.itemId
            }]
        });
        
        Ext.ux.panel.CodeMirror.superclass.initComponent.apply(this, arguments);
    },
    
    onRender: function() {
        Ext.ux.panel.CodeMirror.superclass.onRender.apply(this, arguments);
        this.on('afterlayout', this.triggerCodeEditor, this, {
            single: true
        });
        
    },
    
	setValue: function( v )	{
		var oCmp = this.findByType('textarea')[0];
		oCmp.setValue( v );
		this.codeMirrorEditor.setCode( v )
	},
	
    triggerCodeEditor: function() {
        //this.codeMirrorEditor;
        var oThis = this;
        var oCmp = this.findByType('textarea')[0];
        var editorConfig = Ext.applyIf(this.codeMirror || {}, {
           height: "85%",
           width: "100%",
		   border: true,
           lineNumbers: false,
           textWrapping: true,
		   iframeClass: 'codemirror-iframe',
           content: oCmp.getValue(),
           indentUnit: 2,
           tabMode: 'shift',
		   enterMode: 'keep',
           readOnly: oCmp.readOnly,
           path: Ext.ux.panel.CodeMirrorConfig.jsPath,
           autoMatchParens: true,
           initCallback: function(editor) {
           },
		   //saveFunction: function() { alert(55) },
           onChange: function() {
               var sCode = oThis.codeMirrorEditor.getCode();
               oCmp.setValue(sCode);
           }
       });
        
        var sParserType = oThis.parser || 'txt';
        editorConfig = Ext.applyIf(editorConfig, Ext.ux.panel.CodeMirrorConfig.parser[sParserType]);
        
        this.codeMirrorEditor = new CodeMirror.fromTextArea( Ext.getDom(oCmp.id).id, editorConfig);
    }
});

Ext.reg('uxCodeMirrorPanel', Ext.ux.panel.CodeMirror);


// =================================================


Ext.namespace('Ext.ux.form');

Ext.ux.form.CodeMirror = Ext.extend(Ext.form.TextArea, {
	language: 'txt',
	codeMirrorHidden: false,
	codeMirrorPath: null,
	// should be path to code mirror on your server!
	initCallBackFn: null,
	value: '<b>fff</b>',
	// Executes right after the init from codemirror
	onResizeCallBackFn: null,
	// If we need our own resize function
	initComponent: function() {
		var self = this;
		if (this.codeMirrorPath === null) {
			throw 'Ext.ux.form.CodeMirror: codeMirrorPath required';
		}
		this.initialized = false;
		Ext.ux.form.CodeMirror.superclass.initComponent.apply(this, arguments);
		this.addEvents('initialize');
		this.on({
			resize: function(ta, width, height) {
				//this.codeEditor.setLineNumbers(false);
				if (this.onResizeCallBackFn) this.onResizeCallBackFn(this);
				else {
					var el = Ext.select('.' + this.id, true);
					var lineNumbersEl = Ext.select("." + this.id + " ~ div", true); // the lineNumbersEl is always the next div from the iframe
					// Sometimes it happens in air that width or height from the resize event is undefined...
					if (!width) width = ta.getWidth();
					if (!height) height = ta.getHeight();
					//...but we got it back from the container
					if (el) {
						// If we find the lineNumbersEl we subtract the width
						if (this.initialized && !this.codeMirrorHidden && count(lineNumbersEl.elements) > 0 && width) width = width - lineNumbersEl.elements[0].getWidth();

						for (var i = 0; i < el.elements.length; i++) {
							// It should not but it could be that the width or height is undefined.. i realy have no plan why this
							// happens in Air. However we set what isn't undefined
							if (width) el.elements[i].setWidth(width);
							if (height) el.elements[i].setHeight(height);

							// On resize we set the height for the line numbers element too
							lineNumbersEl.elements[i].setHeight(height);
						}
					}
				}

				//this.codeEditor.setLineNumbers(true);
			},
			afterrender: function() {
				var parser, stylesheet;
				switch (this.language.toLowerCase()) {
				case 'json':
					parser = ['tokenizejson.js', 'parsejson.js'];
					stylesheet = this.codeMirrorPath + '/css/jsoncolors.css';
					break;
				case 'css':
					parser = 'parsecss.js';
					stylesheet = this.codeMirrorPath + '/css/csscolors.css';
					break;
				case 'js':
					parser = ['tokenizejavascript.js', 'parsejavascript.js'];
					stylesheet = this.codeMirrorPath + '/css/jscolors.css';
					break;
				case 'php':
					parser = ["parsexml.js", "parsecss.js", "tokenizejavascript.js", "parsejavascript.js", "../contrib/php/js/tokenizephp.js", "../contrib/php/js/parsephp.js", "../contrib/php/js/parsephphtmlmixed.js"];
					stylesheet = [this.codeMirrorPath + '/css/xmlcolors.css', this.codeMirrorPath + '/css/jscolors.css', this.codeMirrorPath + '/css/csscolors.css', this.codeMirrorPath + '/contrib/php/css/phpcolors.css'];
					break;
				case 'htm':
				case 'html':
				case 'xml':
				case 'tpl':
					parser = 'parsexml.js';
					stylesheet = this.codeMirrorPath + '/css/xmlcolors.css';
					break;
					//		case 'tpl':
					//			
					//            parserfile: ['parsexml.js', 'parsecss.js', 'tokenizejavascript.js', 'parsejavascript.js', 'parsehtmlmixed.js'],
					//            stylesheet = [
					//				this.codeMirrorPath + "/css/xmlcolors.css",
					//				this.codeMirrorPath + "/css/jscolors.css",
					//				this.codeMirrorPath + "/css/csscolors.css"
					//			]
					//        break;
				default:
					parser = 'parsedummy.js';
					stylesheet = '';
					break;

				}
				var me = this;
				(function() {
					me.codeEditor = new CodeMirror.fromTextArea(me.id, {
						parserfile: parser,
						stylesheet: stylesheet,
						path: me.codeMirrorPath + '/js/',
						textWrapping: true,
						autoMatchParens: true,
						lineNumbers: false,
						//continuousScanning: true,
						passDelay: 100,
						passTime: 50,
						lineNumberDelay: 1000,
						lineNumberTime: 50,
						iframeClass: 'codemirror-iframe ' + me.id,
						content: self.value||'<b>nnn</b>',
						/*parserConfig: {
				json: true
			},*/
						lang: me.language.toLowerCase(),
						initCallback: function() {
							me.initialized = true;
							me.fireEvent('initialize', true);

							if (me.initCallBackFn != null) me.initCallBackFn(me);

							if (me.codeMirrorHidden) me.hideCodeMirror();

							//me.codeEditor.setLineNumbers(true);
						}
					});
				}).defer(50);
			}
		});
	},
	getValue: function() {
		if (this.initialized) {
			if (this.codeMirrorHidden) return this.getTextareaValue();
			else return this.codeEditor.getCode();
		}
		return this.value;
	},
	setValue: function(v) {
		if (this.initialized) {

			if (this.codeMirrorHidden) this.setTextareaValue(v)
			else this.codeEditor.setCode(v);
		}
	},
	getTextareaValue: function() {
		if (!this.rendered) {
			return this.value;
		}
		var v = this.el.getValue();
		if (v === this.emptyText || v === undefined) {
			v = '';
		}
		return v;
	},
	setTextareaValue: function(v) {
		if (this.emptyText && this.el && !Ext.isEmpty(v)) {
			this.el.removeClass(this.emptyClass);
		}
		Ext.form.TextField.superclass.setValue.apply(this, arguments);
		this.applyEmptyText();
		this.autoSize();
		return this;
	},
	hideCodeMirror: function() {
		var me = this;
		var iframeEl = Ext.select('textarea#' + this.id + " + .CodeMirror-wrapping", true);
		var textareaEl = Ext.select("textarea#" + me.id, true);

		textareaEl.setVisibilityMode(Ext.Element.DISPLAY);
		iframeEl.setVisibilityMode(Ext.Element.DISPLAY);

		me.setTextareaValue(me.getValue());

		iframeEl.setVisible(false);
		textareaEl.setVisible(true);

		me.codeMirrorHidden = true;
	},
	showCodeMirror: function() {
		var me = this;
		var iframeEl = Ext.select('textarea#' + this.id + " + .CodeMirror-wrapping", true);
		var textareaEl = Ext.select("textarea#" + me.id, true);

		textareaEl.setVisibilityMode(Ext.Element.DISPLAY);
		iframeEl.setVisibilityMode(Ext.Element.DISPLAY);

		textareaEl.setVisible(false);
		iframeEl.setVisible(true);

		me.codeMirrorHidden = false;

		me.setValue(this.getTextareaValue());
		me.setTextareaValue('');
	},
	validate: function() {
		this.getValue();
		Ext.ux.form.CodeMirror.superclass.validate.apply(this, arguments);
	}
});
Ext.reg('ux-codemirror', Ext.ux.form.CodeMirror);










