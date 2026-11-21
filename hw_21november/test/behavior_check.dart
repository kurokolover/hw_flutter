// flutter test test/behavior_check.dart — после реализации TODO 1–3.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:todo_storage_testing_task/main.dart';
import 'package:todo_storage_testing_task/preferences_store.dart';
import 'package:todo_storage_testing_task/storage.dart';

import 'fakes.dart';
import 'font_setup.dart';

const fixedJson = '[{"id":7,"title":"Купить чай"}]';
const duplicateTitles = '[{"id":7,"title":"Чай"},{"id":2,"title":"Чай"}]';

class PendingWriteStore extends MemoryStore {
  PendingWriteStore(super.value);

  final pending = Completer<void>();
  int writes = 0;

  @override
  Future<void> write(String value) async {
    writes++;
    await pending.future;
    await super.write(value);
  }
}

List<(int, String)> fields(List<Todo> items) =>
    items.map((todo) => (todo.id, todo.title)).toList();

void main() {
  setUpAll(loadTestFonts);

  final addButton = find.byKey(const Key('add_todo_button'));
  final retryButton = find.byKey(const Key('retry_button'));
  final titleField = find.byKey(const Key('todo_title_field'));
  final saveButton = find.byKey(const Key('save_todo_button'));
  final readError = find.text('Не удалось прочитать задачи');
  final saveError = find.text('Не удалось сохранить');

  bool canAdd(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(addButton).onPressed != null;

  Future<void> launch(WidgetTester tester, TextStore store) async {
    await tester.pumpWidget(TodoApp(repository: TodoRepository(store)));
    await tester.pump();
  }

  Future<void> openForm(WidgetTester tester) async {
    expect(canAdd(tester), isTrue);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoPage), findsOneWidget);
  }

  Future<void> submit(WidgetTester tester, String title) async {
    await tester.enterText(titleField, title);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  Future<void> askDelete(WidgetTester tester, int id) async {
    final row = find.byKey(ValueKey(id));
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Удалить')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  test('JSON-массив сохраняет точные поля и порядок', () {
    const items = [Todo(7, 'Чай'), Todo(2, 'Хлеб')];
    final raw = encodeTodos(items);
    expect(jsonDecode(raw), [
      {'id': 7, 'title': 'Чай'},
      {'id': 2, 'title': 'Хлеб'},
    ]);
    expect(fields(decodeTodos(raw)), [(7, 'Чай'), (2, 'Хлеб')]);
    expect(fields(decodeTodos(fixedJson)), [(7, 'Купить чай')]);
  });

  test('сломанный JSON и неверная структура дают FormatException', () {
    for (final raw in [
      '[{"id":7',
      '',
      'null',
      '{}',
      '[42]',
      '[null]',
      '[{"id":"7","title":"Чай"}]',
      '[{"id":7,"title":null}]',
      '[{"id":7}]',
    ]) {
      expect(
        () => decodeTodos(raw),
        throwsFormatException,
        reason: 'JSON: $raw',
      );
    }
  });

  test('пустой список хранится как пустой JSON-массив', () {
    expect(encodeTodos([]), '[]');
    expect(decodeTodos('[]'), isEmpty);
  });

  test(
    'репозиторий читает отсутствие данных и восстанавливает запись',
    () async {
      final store = MemoryStore();
      final repository = TodoRepository(store);
      expect(await repository.load(), isEmpty);
      expect(store.value, isNull);
      await repository.save(const [Todo(7, 'Чай'), Todo(2, 'Хлеб')]);
      expect(fields(await TodoRepository(store).load()), [
        (7, 'Чай'),
        (2, 'Хлеб'),
      ]);
    },
  );

  test('репозиторий пробрасывает сбои чтения и записи', () async {
    final failure = StateError('хранилище недоступно');
    final store = MemoryStore(fixedJson)..readError = failure;
    final repository = TodoRepository(store);
    await expectLater(repository.load(), throwsA(same(failure)));
    store.readError = null;
    store.writeError = failure;
    await expectLater(
      repository.save(const [Todo(2, 'Хлеб')]),
      throwsA(same(failure)),
    );
    expect(store.value, fixedJson);
    expect(fields(await repository.load()), [(7, 'Купить чай')]);
  });

  test('PreferencesStore читает и пишет строку по заданному ключу', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);

    final prefs = SharedPreferencesAsync();
    final standard = PreferencesStore(prefs);
    final other = PreferencesStore(prefs, key: 'practice.other');
    expect(await standard.read(), isNull);
    await standard.write(fixedJson);
    expect(await prefs.getString('practice.todos'), fixedJson);
    expect(await other.read(), isNull);
    await prefs.setString('practice.other', duplicateTitles);
    expect(await other.read(), duplicateTitles);
    await other.write(fixedJson);
    expect(await prefs.getString('practice.other'), fixedJson);
  });

  testWidgets('индикатор виден до завершения чтения', (tester) async {
    final store = PendingStore();
    await launch(tester, store);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(canAdd(tester), isFalse);

    store.pending.complete(fixedJson);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Купить чай'), findsOneWidget);
    expect(canAdd(tester), isTrue);
  });

  testWidgets('первый запуск показывает пустой список', (tester) async {
    final store = MemoryStore();
    await launch(tester, store);
    expect(find.text('Пока нет задач'), findsOneWidget);
    expect(canAdd(tester), isTrue);
    expect(store.value, isNull);
  });

  testWidgets('форма добавляет задачу и сохраняет её с новым id', (
    tester,
  ) async {
    final store = MemoryStore(duplicateTitles);
    await launch(tester, store);
    await openForm(tester);
    await submit(tester, '  Добавить молоко  ');

    expect(find.byType(AddTodoPage), findsNothing);
    expect(find.text('Добавить молоко'), findsOneWidget);
    expect(fields(decodeTodos(store.value!)), [
      (7, 'Чай'),
      (2, 'Чай'),
      (8, 'Добавить молоко'),
    ]);
  });

  testWidgets('отмена оставляет список, подтверждение удаляет по id', (
    tester,
  ) async {
    final store = MemoryStore(duplicateTitles);
    await launch(tester, store);
    await askDelete(tester, 2);
    expect(find.text('Удалить задачу?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(store.value, duplicateTitles);

    await askDelete(tester, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(2)), findsNothing);
    expect(find.byKey(const ValueKey(7)), findsOneWidget);
    expect(fields(decodeTodos(store.value!)), [(7, 'Чай')]);
  });

  testWidgets('ошибка чтения блокирует добавление и даёт повторить', (
    tester,
  ) async {
    final store = MemoryStore('повреждённые данные');
    await launch(tester, store);
    expect(readError, findsOneWidget);
    expect(canAdd(tester), isFalse);
    expect(find.text('Пока нет задач'), findsNothing);
    expect(store.value, 'повреждённые данные');
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoPage), findsNothing);

    store.value = fixedJson;
    await tester.tap(retryButton);
    await tester.pumpAndSettle();
    expect(readError, findsNothing);
    expect(find.text('Купить чай'), findsOneWidget);
    expect(canAdd(tester), isTrue);
    expect(store.value, fixedJson);
  });

  testWidgets('сбой записи оставляет прежний список и снимает блокировку', (
    tester,
  ) async {
    final store = MemoryStore(fixedJson)..writeError = StateError('нет записи');
    await launch(tester, store);
    await openForm(tester);
    await submit(tester, 'Должна исчезнуть');
    expect(saveError, findsOneWidget);
    expect(find.text('Купить чай'), findsOneWidget);
    expect(find.text('Должна исчезнуть'), findsNothing);
    expect(store.value, fixedJson);
    expect(canAdd(tester), isTrue);

    store.writeError = null;
    await openForm(tester);
    await submit(tester, 'Повторная попытка');
    expect(find.text('Повторная попытка'), findsOneWidget);
    expect(fields(decodeTodos(store.value!)), [
      (7, 'Купить чай'),
      (8, 'Повторная попытка'),
    ]);
  });

  testWidgets('список меняется только после завершения записи', (tester) async {
    final store = PendingWriteStore(fixedJson);
    await launch(tester, store);
    await openForm(tester);
    await submit(tester, 'Новая задача');
    expect(store.writes, 1);
    expect(find.text('Новая задача'), findsNothing);
    expect(find.text('Купить чай'), findsOneWidget);
    expect(canAdd(tester), isFalse);
    final delete = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Удалить',
    );
    expect(tester.widget<IconButton>(delete).onPressed, isNull);
    expect(store.value, fixedJson);

    store.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Новая задача'), findsOneWidget);
    expect(fields(decodeTodos(store.value!)), [
      (7, 'Купить чай'),
      (8, 'Новая задача'),
    ]);
    expect(canAdd(tester), isTrue);
  });

  testWidgets('можно закрыть экран до завершения чтения', (tester) async {
    final store = PendingStore();
    await launch(tester, store);
    await tester.pumpWidget(const SizedBox.shrink());
    store.pending.complete(fixedJson);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(store.value, isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('можно закрыть экран до завершения записи (сбой: $fails)', (
      tester,
    ) async {
      final store = PendingWriteStore(fixedJson);
      await launch(tester, store);
      await openForm(tester);
      await submit(tester, 'Новая задача');
      expect(store.writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      if (fails) {
        store.pending.completeError(StateError('нет записи'));
      } else {
        store.pending.complete();
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('длинная задача, форма и диалог помещаются в 320×600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester, MemoryStore());
    await openForm(tester);
    await submit(tester, '   ');
    expect(find.text('Введите название'), findsOneWidget);
    final title = 'Длинное название задачи ' * 6;
    await submit(tester, title);
    expect(find.text(title.trim()), findsOneWidget);
    await askDelete(tester, 1);
    expect(find.text('Отмена').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
