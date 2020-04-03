
ПодключитьСценарий("..\src\ПарсерВстроенногоЯзыка\Ext\ObjectModule.bsl", "ПарсерВстроенногоЯзыка");
ПодключитьСценарий("..\plugins\DocGen\src\DocGen\Ext\ObjectModule.bsl", "ГенераторДокументации");

ЧтениеТекста = Новый ЧтениеТекста("..\src\ПарсерВстроенногоЯзыка\Ext\ObjectModule.bsl");
Исходник = ЧтениеТекста.Прочитать();

ГенераторДокументации = Новый ГенераторДокументации;

ПарсерВстроенногоЯзыка = Новый ПарсерВстроенногоЯзыка;
ПарсерВстроенногоЯзыка.Пуск(Исходник, ГенераторДокументации);

ЗаписьТекста = Новый ЗаписьТекста("..\docs\index.html");
ЗаписьТекста.Записать(ГенераторДокументации.Закрыть());