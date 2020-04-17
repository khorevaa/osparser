﻿
// Проверка комментариев в окончаниях инструкций

Перем Узлы;
Перем Токены;
Перем Исходник;
Перем ТаблицаТокенов;
Перем ТаблицаОшибок;

Перем УровеньОбласти;
Перем СтекОбластей;

Процедура Инициализировать(Парсер, Параметры) Экспорт

	Узлы = Парсер.Узлы();
	Токены = Парсер.Токены();
	Исходник = Парсер.Исходник();
	ТаблицаТокенов = Парсер.ТаблицаТокенов();
	ТаблицаОшибок = Парсер.ТаблицаОшибок();

	УровеньОбласти = 0;
	СтекОбластей = Новый Соответствие;

КонецПроцедуры

Функция Закрыть() Экспорт
	Возврат Неопределено;
КонецФункции

Функция Подписки() Экспорт
	Перем Подписки;
	Подписки = Новый Массив;
	Подписки.Добавить("ПосетитьОбъявлениеМетода");
	Подписки.Добавить("ПосетитьИнструкциюПрепроцессора");
	Возврат Подписки;
КонецФункции

Процедура ПосетитьОбъявлениеМетода(ОбъявлениеМетода) Экспорт

	СледующийТокен = ТаблицаТокенов[ОбъявлениеМетода.Конец + 1];

	Если СледующийТокен.Токен = Токены.Комментарий
		И СледующийТокен.НомерСтроки = ТаблицаТокенов[ОбъявлениеМетода.Конец].НомерСтроки Тогда

		Комментарий = СокрП(Сред(Исходник, СледующийТокен.Начало, СледующийТокен.Конец - СледующийТокен.Начало));

		Если Комментарий <> СтрШаблон(" %1%2", ОбъявлениеМетода.Сигнатура.Имя, "()") Тогда
			Сообщение = СтрШаблон(
				"Метод `%1()` имеет неправильный замыкающий комментарий в строке %2",
				ОбъявлениеМетода.Сигнатура.Имя,
				СледующийТокен.НомерСтроки
			);
			Ошибка(Сообщение, ОбъявлениеМетода.Конец + 1);
		КонецЕсли;

	КонецЕсли;

КонецПроцедуры

Процедура ПосетитьИнструкциюПрепроцессора(ИнструкцияПрепроцессора) Экспорт

	Если ИнструкцияПрепроцессора.Тип = Узлы.ИнструкцияПрепроцессораОбласть Тогда

		УровеньОбласти = УровеньОбласти + 1;
		СтекОбластей[УровеньОбласти] = ИнструкцияПрепроцессора.Имя;

	ИначеЕсли ИнструкцияПрепроцессора.Тип = Узлы.ИнструкцияПрепроцессораКонецОбласти Тогда
		СледующийТокен = ТаблицаТокенов[ИнструкцияПрепроцессора.Конец + 1];

		Если СледующийТокен.Токен = Токены.Комментарий
			И СледующийТокен.НомерСтроки = ТаблицаТокенов[ИнструкцияПрепроцессора.Конец].НомерСтроки Тогда

			Комментарий = СокрП(Сред(Исходник, СледующийТокен.Начало, СледующийТокен.Конец - СледующийТокен.Начало));
			ИмяОбласти = СтекОбластей[УровеньОбласти];

			Если Комментарий <> СтрШаблон(" %1", ИмяОбласти) Тогда
				Сообщение = СтрШаблон(
					"Область `%1` имеет неправильный замыкающий комментарий в строке %2:",
					ИмяОбласти,
					СледующийТокен.НомерСтроки
				);
				Ошибка(Сообщение, ИнструкцияПрепроцессора.Конец + 1);
			КонецЕсли;

		КонецЕсли;

		УровеньОбласти = УровеньОбласти - 1;

	КонецЕсли;

КонецПроцедуры

Процедура Ошибка(Текст, Начало, Конец = Неопределено)
	Если Конец = Неопределено Тогда
		Конец = Начало;
	КонецЕсли;
	ТокенНачала = ТаблицаТокенов[Начало];
	ТокенКонца = ТаблицаТокенов[Конец];
	Ошибка = ТаблицаОшибок.Добавить();
	Ошибка.Источник = "ДетекторОшибочныхЗамыкающихКомментариев";
	Ошибка.ТекстОшибки = Текст;
	Ошибка.ПозицияНачала = ТокенНачала.Начало;
	Ошибка.НомерСтрокиНачала = ТокенНачала.НомерСтроки;
	Ошибка.НомерКолонкиНачала = ТокенНачала.НомерКолонки;
	Ошибка.ПозицияКонца = ТокенКонца.Конец;
	Ошибка.НомерСтрокиКонца = ТокенКонца.НомерСтроки;
	Ошибка.НомерКолонкиКонца = ТокенКонца.НомерКолонки;
КонецПроцедуры