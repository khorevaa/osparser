# bsparser (built-in script parser)

bsparser - это парсер встроенного языка платформы 1С:Предприятие 8 (далее "язык 1С")

Данный проект представляет из себя набор внешних обработок для платформы 1С:Предприятие версии 8.3.13

Обработки совместимы с интерпретатором [OneScript](https://github.com/EvilBeaver/OneScript)

## Содержание
1. [Введение](#введение)
2. [Интеграция с SonarQube](#интеграция-с-sonarqube)
3. [Цели проекта](#цели-проекта)
4. [Мотивация](#мотивация)
5. [Философия](#философия)
6. [Структура репозитория](#структура-репозитория)
7. [Системные требования](#системные-требования)
8. [Сборка проекта](#сборка-проекта)
9. [Быстрый старт](#быстрый-старт)
10. [Принцип работы](#принцип-работы)

## Введение

Перед тем как разбираться с этим проектом, убедитесь что вы хорошо понимаете что такое AST и Visitor и что можно с их помощью делать.
Это важно, так как данная разработка предоставляет именно эти возможности. Не больше не меньше.
Вы можете писать проверки кода, компиляторы, интерпретаторы и любые другие вещи, которые можно реализовать путем обработки AST.
Сколько информации содержит AST можно увидеть тут: https://lead-tools.github.io/bsparser

Общее представление можно получить в этой статье: [Зачем нужен AST](https://ps-group.github.io/compilers/ast)

Данная разработка устроена похожим образом. С поправкой на то, что это реализация без ООП на языке 1С.
После ознакомления со статьей можно сразу посмотреть [Принцип работы](#принцип-работы) внизу этой страницы.

По сути это фронтенд компилятора, а вы можете к нему писать бакенды (плагины).

Пример плагина проверяющего наличие возврата в конце функций: [ReturnCheck](https://github.com/lead-tools/bsparser/blob/master/plugins/ReturnCheck/src/ReturnCheck/Ext/ObjectModule.bsl)
Конкретно весь код проверки выглядит так (остальное там просто интерфейс плагина):
```bsl
Procedure VisitMethodDecl(MethodDecl, Stack, Counters) Export
	Var StmtCount;
	If MethodDecl.Sign.Type <> Nodes.FuncSign Then
		Return;
	EndIf;
	StmtCount = MethodDecl.Body.Count();
	If StmtCount = 0 Or MethodDecl.Body[StmtCount - 1].Type <> "ReturnStmt" Then
		Result.Add(StrTemplate("Последней инструкцией функции `%1()` должен быть `Возврат`" "", MethodDecl.Sign.Name));
	EndIf;
EndProcedure // VisitMethodDecl()
```
Эта процедура вызывается визитером (Visitor) во время обхода AST для каждой встреченной процедуры или функции.
Суть реализации проверки: Сначала проверяется что это функция. Затем берется количество операторов в теле функции.
Если 0 или последний оператор не `Возврат`, то регистрируется ошибка.
В данном плагине ошибки просто собираются в массив. Список ошибок можно получить вызовом Result() у обработки плагина после того как визитер закончит обход.

Пример плагина средней сложности: [TestVars](https://github.com/lead-tools/bsparser/blob/master/plugins/TestVars/src/TestVars/Ext/ObjectModule.bsl)
Этот код находит неиспользуемые переменные и параметры.

Пример сложного плагина: [onesick](https://github.com/lead-tools/onesick/blob/master/Compiler/src/Compiler/Ext/ObjectModule.bsl)
Это генератор кода для интерпретации языка 1С на языке 1С.

Пример на OneScript, демонстрирующий прогон проверок исходного кода: [test.os](https://github.com/lead-tools/bsparser/blob/master/oscript/test.os)

## Интеграция с SonarQube

Если вы хотите результаты проверок видеть в SonarQube, то можете просто выгрузить их в формате [Generic Issue](https://docs.sonarqube.org/latest/analysis/generic-issue/)

Вам понадобится только установленный сонар и созданный проект в нем.

Например проект у вас в папке `c:\sonarqube-7.7\myprj\`
Исходный код, который нужно анализировать в папке `c:\sonarqube-7.7\myprj\src\`

Настройки проекта (`"c:\sonarqube-7.7\myprj\conf\sonar-project.properties"`):
```json
sonar.host.url=http://localhost:9000
sonar.projectKey=myprj
sonar.projectVersion=1.0
sonar.sources=myprj/src
sonar.sourceEncoding=UTF-8
sonar.inclusions=**/*.bsl
sonar.externalIssuesReportPaths=myprj/bsl-generic-json.json
```

Выгружаете результаты проверок в файл: `"c:\sonarqube-7.7\myprj\bsl-generic-json.json"`

Примерный код для формирования json (если например предварительно ошибки были сохранены для отчетов в регистре в 1С):
```bsl
&AtClient
Procedure GenerateJSON(Command)

	Data = GenerateJSONAtServer();

	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.Unix));
	WriteJSON(JSONWriter, Data);
	Report = JSONWriter.Close();

	TextDoc = New TextDocument;
	TextDoc.SetText(Report);
	TextDoc.Show("Generic Issue Data");

EndProcedure

&AtServerNoContext
Function GenerateJSONAtServer()

	Query = New Query;
	Query.Text =
	"SELECT
	|	Errors.Period AS Period,
	|	Errors.FileName AS FileName,
	|	Errors.Pos AS Pos,
	|	Errors.Line AS Line,
	|	Errors.Text AS Text
	|FROM
	|	InformationRegister.Errors AS Errors";

	Issues = New Array;

	For Each Item In Query.Execute().Unload() Do

		textRange = New Structure;
		textRange.Insert("startLine", Item.Line);

		primaryLocation = New Structure;
		primaryLocation.Insert("message", Item.Text);
		primaryLocation.Insert("filePath", Item.FileName);
		primaryLocation.Insert("textRange", textRange);

		Issue = New Structure;
		Issue.Insert("engineId", "test");
		Issue.Insert("ruleId", "rule42");
		Issue.Insert("severity", "INFO");
		Issue.Insert("type", "CODE_SMELL");
		Issue.Insert("primaryLocation", primaryLocation);

		Issues.Add(Issue);

	EndDo;

	Return New Structure("issues", Issues);

EndFunction
```

Открываете консоль повершела в папке `C:\sonarqube-7.7\`

Запускаете сонар:
```powershell
.\bin\windows-x86-64\StartSonar.bat
```

Запускаете загрузку проверок в сонар:
```powershell
.\sonar-scanner\bin\sonar-scanner.bat -D project.settings=./myprj/conf/sonar-project.properties
```

Все. Можно смотреть отчет в сонаре.

## Цели проекта

* Создать удобный инструмент для работы с исходным кодом на языке 1С как с данными
* Выработать методы анализа и преобразования программ на языке 1С
* Выработать методы ограничения семантики языка под конкретную задачу или проект
* Получить новые знания и умения

## Мотивация

Разработка ПО практически никогда не ограничивается одними лишь правилами языка реализации. Многие команды следуют определенным общепринятым стандартам и правилам разработки, а каждый конкретный проект имеет еще и свою собственную специфику. Проверка проекта на соответствие всем требованиям - это довольно сложный и затратный процесс. А сократить затраты (кажется) можно с помощью автоматизации проверок. Эта мысль была толчком к началу работы над данным проектом.

## Философия

* Make it as simple as possible, but not simpler
* Не привлекай сторонних технологий без необходимости
* Не ведись на модные течения
* Не сцы

## Структура репозитория

* /docs - файлы веб-страницы проекта <https://lead-tools.github.io/bsparser>
* /gui - исходники обработки, предоставляющей графический пользовательский интерфейс к парсеру (в целях отладки)
* /img - картинки для документации
* /oscript - скрипты для проверки работы парсера на интерпретаторе [OneScript](https://github.com/EvilBeaver/OneScript)
* /plugins - исходники обработок-плагинов
* /src - исходники обработки парсера
* /prepare.ps1 - скрипт подготовки окружения для использования скриптов сборки/разборки обработок
* /common.ps1 - скрипт с общими алгоритмами
* /build.ps1 - скрипт сборки обработок с помощью конфигуратора в режиме агента
* /explode.ps1 - скрипт разборки обработок с помощью конфигуратора в режиме агента
* /temp.dt - выгрузка пустой базы, которая необходима для работы конфигуратора в режиме агента

## Системные требования

Для использования обработок необходима либо установленная платформа 1С:Предприятие версии 8.3.13, либо интерпретатор [OneScript](https://github.com/EvilBeaver/OneScript)

Операционная система значения не имеет. Но сборочные скрипты в текущей реализации будут работать только в Windows (эти скрипты не обязательны).

Если вы хотите [принять участие](https://github.com/lead-tools/bsparser/blob/master/CONTRIBUTING.md) в проекте, то вероятно потребуется [git](https://git-scm.com/) и аккаунт на github.

## Сборка проекта

Вы можете либо клонировать репозиторий с помощью [git](https://git-scm.com/):
```ps
git clone https://github.com/lead-tools/bsparser
```
либо просто скачать и распаковать zip-архив: https://github.com/lead-tools/bsparser/archive/master.zip

Исходники обработок в данном проекте выгружены стандартными средствами конфигуратора платформы 1С:Предприятие версии 8.3. Для сборки вы можете просто открыть файл `xml` в конфигураторе как есть и пересохранить в формате `epf`

Также можно воспользоваться скриптами на **powershell**, которые находятся в корне. Сначала нужно запустить скрипт `prepare.ps1`, который установит модуль для работы с протоколом SSH (нужен для агента конфигуратора) и развернет пустую базу в папке `/temp`. Если ошибок не возникло, то запуск скрипта больше не потребуется. После этого вы можете запустить скрипт `build.ps1`, который соберет обработки в папке `/build`. Обратную операцию можно выполнить, запустив скрипт `explode.ps1`

Скрипты могут иногда не срабатывать, но повторный запуск обычно помогает :)
Пользоваться скриптами нужно **осторожно**, чтобы не потерять свои правки.

Если вы будете использовать парсер в среде [OneScript](https://github.com/EvilBeaver/OneScript), то сборка вообще не требуется.

## Быстрый старт

1. Клонировать репозиторий и собрать обработки (см. выше "Сборка проекта")
2. Открыть обработку build/gui.epf в управляемом приложении любой файловой базы (обработка BSLParser.epf должна лежать рядом с gui.epf)
3. Вставить исходный код на языке 1С в поле `Source`
4. В поле `Output` выбрать `AST (tree)`
5. Нажать кнопку `Translate`
6. В поле `Result` будет выведено [AST](https://ru.wikipedia.org/wiki/%D0%90%D0%B1%D1%81%D1%82%D1%80%D0%B0%D0%BA%D1%82%D0%BD%D0%BE%D0%B5_%D1%81%D0%B8%D0%BD%D1%82%D0%B0%D0%BA%D1%81%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5_%D0%B4%D0%B5%D1%80%D0%B5%D0%B2%D0%BE) вашего исходного кода. Если предварительно был выставлен флаг `Location`, то двойной клик на узле в дереве будет выделять соответствующий этому узлу участок исходного кода.
7. Для запуска плагина нужно в поле `Output` выбрать `Plugin` и указать файл обработки-плагина. Затем нажать `Translate`. В поле `Result` будет выведен результат работы плагина.

**Внимание!** Режим отладки существенно снижает скорость работы парсера.

![bsparser](img/1SH.png)

## Принцип работы

Решение на базе данного проекта в простейшем случае включает:
* Парсер - обработка BSLParser из этого репозитория
* Плагин к парсеру - любая обработка, имеющая определенный программный интерфейс

Парсер разбирает переданный ему исходный код и возвращает модель этого кода в виде [абстрактного синтаксического дерева](https://ru.wikipedia.org/wiki/%D0%90%D0%B1%D1%81%D1%82%D1%80%D0%B0%D0%BA%D1%82%D0%BD%D0%BE%D0%B5_%D1%81%D0%B8%D0%BD%D1%82%D0%B0%D0%BA%D1%81%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5_%D0%B4%D0%B5%D1%80%D0%B5%D0%B2%D0%BE). Узлы этого дерева соответствуют синтаксическим конструкциям и операторам языка. Например, конструкция `Пока <условие> Цикл <тело> КонецЦикла` представлена в дереве узлами типа `WhileStmt`, в которых условие представлено в подчиненном узле-выражении `Cond`, а тело хранится в массиве узлов-операторов `Body`. Данных в дереве достаточно для полного восстановления по нему исходного кода вместе с комментариями, за исключением некоторых деталей форматирования. Порядок и подчиненность узлов в дереве в точности соответствует исходному коду. Каждый узел хранит номер строки, позицию начала и длину участка кода, который он представляет. Описание узлов и элементов дерева вы можете найти на веб-странице проекта: https://lead-tools.github.io/bsparser

После формирования дерева запускается общий механизм обхода дерева, который при посещении узла вызывает обработчики подписанных на этот узел плагинов. Полезная (прикладная) работа выполняется именно плагином. Это может быть сбор статистики, поиск ошибок, анализ цикломатической сложности, построение документации по коду и т.д. и т.п. Кроме того, плагин может построить модификацию исходного дерева путем замены одних узлов на другие (например, в целях оптимизации).

Состояние плагина (в переменных модуля обработки) сохраняется между вызовами до самого конца обхода дерева, а подписки на каждый узел возможны две: перед обходом узла и после обхода. Это существенно упрощает реализацию многих алгоритмов анализа. Плюс к этому, некоторую информацию предоставляет сам механизм обхода. Например, плагинам доступна статистика по родительским узлам (количество каждого вида).

Пример работы через [OneScript](https://github.com/EvilBeaver/OneScript) можно посмотреть здесь: https://github.com/lead-tools/bsparser/blob/master/oscript/test.os

## Благодарности

Спасибо жене, что терпит мои увлечения и приносит еду прям к компу, когда я на форсаже вечерами кодирую тонны никому не нужного кода.
