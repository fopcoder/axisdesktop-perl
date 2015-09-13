//<!--

var baseLang = {
    textSignUp : 'Зарегистрироваться'
    ,textForgotPassword : 'Забыли пароль?'
    ,baseStartButtonText : 'Старт'
    
    // ------------
    ,labelEmail : 'Email'
    ,labelPassword : 'Пароль'
    ,labelLogin : 'Войти'
    ,labelSelectFileType: 'Выберите тип файла'
    ,labelOverwrite: 'Перезаписать'
    ,labelCloseAll : 'Закрыть все'
    ,labelMinimizeAll: 'Свернуть все'
    ,labelTile: 'Плитка'
    ,labelCascade: 'Каскадом'
    ,labelCheckerboard: 'Экраны'
    ,labelSnapFit: 'Горзонтально'
    ,labelSnapFitVertical: 'Вертикально'
    ,labelLogout: 'Выход'
    ,labelMinimize: 'Свернуть'
    ,labelClose: 'Закрыть'
    ,labelMaximize: 'Развернуть'
    ,labelRestore: 'Восстановить'
    // ------------------

    // labels
    ,labelAction : 'Действие'
    ,labelAdd : 'Добавить'
    ,labelAlias : 'Обозначение'
    ,labelCopy : 'Копировать'
    ,labelDelete : 'Удалить'
    ,labelDescription : 'Описание'
    ,labelGroup : 'Группа'
    ,labelID: 'ID'
    ,labelImg : 'Картинка'
    ,labelInserted: 'Добавлено'
    ,labelKeywords : 'Ключевые слова'
    ,labelName: 'Имя'
    ,labelOwner : 'Владелец'
    ,labelParent: 'В каталоге'
    ,labelProperties : 'Свойства'
    ,labelRefresh : 'Обновить'
    ,labelSize : 'Размер'
    ,labelTitle : 'Заголовок'
    ,labelType : 'Тип'
    ,labelUpdated: 'Обновлено'
    ,labelURL: 'URL'
    
    
    // tabs
    ,tabAccessTitle: 'Доступ'
    ,tabGeneralTitle: 'Общие'
    ,tabL10nTitle: 'Локализация'
    ,tabNoNameTitle: 'Без имени'
    ,tabOptionsTitle: 'Опции'
    ,tabParamsTitle: 'Параметры'
    
    
    
    // flags
    ,FLAG_HIDDEN : 'Скрыт'
    ,FLAG_INHERIT : 'Наследовать'
    ,FLAG_PUBLISH : 'Опубликовать'
    ,FLAG_CACHE : 'Кешировать'
    ,FLAG_LOCKED : 'Фиксировать'
    ,FLAG_LOG : 'Вести журнал'
    ,FLAG_SYSTEM : 'Системный'
    ,FLAG_UPDATED : 'Обновлен'
    
    
    
    // buttons
    ,buttonAdd : 'Добавить'
    ,buttonAddFileToolTip : 'Добавить файлы'
    ,buttonAddToolTip : 'Добавить элементы'
    ,buttonCollapseAllToolTip : 'Свернуть все'
    ,buttonCopy : 'Копировать'
    ,buttonCopyToolTip : 'Копировать выбраные элементы'
    ,buttonDel : 'Удалить'
    ,buttonDelFileToolTip : 'Удалить выбраные файлы'
    ,buttonDelToolTip : 'Удалить выбраные элементы'
    ,buttonExpandAllToolTip : 'Развернуть все'
    ,buttonRefresh: 'Обновить'
    ,buttonRefreshAllToolTip : 'Обновить дерево'
    ,buttonRefreshToolTip : 'Обновить список'
    ,buttonSave: 'Сохранить'
    
    

    // dialogs
    ,dlgMsgCopySelected: 'Копировать выбраное'
    ,dlgMsgDeleteSelected: 'Удалить выбраное'
    ,dlgMsgFailure : 'Ошибка!'
    ,dlgMsgLoading : 'Загрузка...'
    ,dlgMsgMessage : 'Сообщение'
    ,dlgMsgNoSelection: 'Ничего не выбрано'
    ,dlgMsgSaving : 'Сохранение...'
    
    // dialogs grid
    ,dlgMsgNoTopics : 'Нет записей'
    ,dlgMsgNoFileType : 'Невыбран тип файла'
    ,dlgMsgNoFile : 'Невыбран тип файла'
    ,dlgMsgTopics : 'Записи {0} - {1} из {2}'
    ,dlgMsgAfterPage : 'из {0}'
    ,dlgMsgBeforePage: 'Страница'
    ,dlgMsgFirstText: 'Первая страница'
    ,dlgMsgLastText: 'Последняя страница'
    ,dlgMsgNextText: 'Следующая страница'
    ,dlgMsgPrevText: 'Предыдущая страница'
    ,dlgMsgRefreshText: 'Обновить'
    
    // upload files dialog
    ,uploadDialogI18n: {
        title: 'Загрузка файлов',
        state_col_title: 'Состояние',
        state_col_width: 70,
        filename_col_title: 'Имя файла',
        filename_col_width: 230,
        note_col_title: 'Примечание',
        note_col_width: 150,
        add_btn_text: 'Добавить',
        add_btn_tip: 'Добавить файл в очередь загрузки.',
        remove_btn_text: 'Удалить',
        remove_btn_tip: 'Удалить файл из очереди загрузки.',
        reset_btn_text: 'Очистить',
        reset_btn_tip: 'Очистить очередь.',
        upload_btn_start_text: 'Загрузить',
        upload_btn_stop_text: 'Остановить',
        upload_btn_start_tip: 'Загрузить файлы в очереди.',
        upload_btn_stop_tip: 'Остановить загрузку.',
        close_btn_text: 'Закрыть',
        close_btn_tip: 'Закрыть',
        progress_waiting_text: 'Ожидание...',
        progress_uploading_text: 'Файлы: {0} из {1} файлов.',
        error_msgbox_title: 'Ошибка',
        permitted_extensions_join_str: ',',
        err_file_type_not_permitted: 'Selected file extension isn\'t permitted.<br/>Please select files with following extensions: {1}',
        note_queued_to_upload: 'Поставлено в очередь на загрузку.',
        note_processing: 'Загружается...',
        note_upload_failed: 'Server is unavailable or internal server error occured.',
        note_upload_success: 'OK.',
        note_upload_error: 'Ошибка загрузки.',
        note_aborted: 'Сброшено пользователем.'
    }
}

//-->