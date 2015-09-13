
CKEDITOR.editorConfig = function( config )  {
    config.skin = 'v2';
    //config.protectedSource.push( /<TMPL_[\s\S]*?>/g );
	//config.protectedSource.push( /<\/TMPL_[\s\S]*?>/g );
    config.tabSpaces = 4;
	config.scayt_autoStartup = false;
	CKEDITOR.config.browserContextMenuOnCtrl = true;
    CKEDITOR.config.toolbar_ArticleContent =
    [
	    ['Source','-','NewPage','Templates'],
	    ['Cut','Copy','Paste','PasteText','PasteFromWord'],
	    ['Undo','Redo','-','Find','Replace','-','SelectAll','RemoveFormat'],
		['Maximize', 'ShowBlocks'],
		['TextColor','BGColor'],
	    '/',
	    ['Bold','Italic','Underline','Strike','-','Subscript','Superscript'],
	    ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote'],
	    ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
	    ['Link','Unlink','Anchor'],
	    ['Image','Flash','Table','HorizontalRule','Smiley','SpecialChar','PageBreak'],
	    '/',
	    ['Styles','Format','Font','FontSize']
    ];
    CKEDITOR.config.toolbar_ArticleField =
    [
	    ['Paste','PasteText','PasteFromWord'],
	    ['Bold','Italic','Underline','Strike','-','Subscript','Superscript'],
	    ['NumberedList','BulletedList','-','Outdent','Indent'],
	    ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
	    ['Link','Unlink','Anchor'],
	    '/',
	    ['Source'],
	    ['Font','FontSize'],
	    ['TextColor','BGColor'],
	    ['Image','Flash','Table'],
	    ['Maximize' ]
    ];
    config.toolbar = 'ArticleContent'; 

};
/*
FCKConfig.IgnoreEmptyParagraphValue = true;

FCKConfig.LinkUpload = false;
FCKConfig.FlashUpload = false;
FCKConfig.ImageUpload = false;
FCKConfig.ImageBrowser = false;
FCKConfig.LinkBrowser = false;
FCKConfig.FlashBrowser = false;

FCKConfig.TemplatesXmlPath = '/cgi-bin/wg/modules/article/template/fcktemplates.xml' ;
*/
