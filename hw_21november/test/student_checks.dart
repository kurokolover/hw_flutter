// flutter test test/student_checks.dart — после реализации TODO 4.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_storage_testing_task/main.dart';
import 'package:todo_storage_testing_task/storage.dart';

import 'fakes.dart';

const fixedJson = '[{"id":7,"title":"Купить чай"}]';
const brokenJson = '[{"id":7';
const wrongFieldType = '[{"id":"7","title":"Чай"}]';

List<(int, String)> fields(List<Todo> items) =>
    items.map((todo) => (todo.id, todo.title)).toList();

Future<void> launch(WidgetTester tester, TextStore store) =>
    tester.pumpWidget(TodoApp(repository: TodoRepository(store)));

Future<void> addThroughForm(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(const Key('add_todo_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('todo_title_field')), title);
  await tester.tap(find.byKey(const Key('save_todo_button')));
  await tester.pumpAndSettle();
}

Future<void> launchFresh(WidgetTester tester, TextStore store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await launch(tester, store);
  await tester.pump();
}

void main() {
  test('новый репозиторий восстанавливает задачи по порядку', () async {
    final store = MemoryStore();
    await TodoRepository(store).save(const [Todo(7, 'Чай'), Todo(2, 'Хлеб')]);

    expect(fields(await TodoRepository(store).load()), [
      (7, 'Чай'),
      (2, 'Хлеб'),
    ]);
  });

  test('первый запуск, готовый JSON и повреждённые данные', () async {
    final store = MemoryStore();
    final repository = TodoRepository(store);
    expect(await repository.load(), isEmpty);

    store.value = fixedJson;
    expect(fields(await repository.load()), [(7, 'Купить чай')]);

    store.value = brokenJson;
    await expectLater(repository.load(), throwsFormatException);
    store.value = wrongFieldType;
    await expectLater(repository.load(), throwsFormatException);
  });

  test('сбой записи не затирает ранее сохранённую задачу', () async {
    final failure = StateError('Запись недоступна');
    final store = MemoryStore(fixedJson)..writeError = failure;
    final repository = TodoRepository(store);

    await expectLater(
      repository.save(const [Todo(2, 'Хлеб')]),
      throwsA(same(failure)),
    );
    expect(fields(await repository.load()), [(7, 'Купить чай')]);
  });

  testWidgets('показывает загрузку, восстанавливает и добавляет задачу', (
    tester,
  ) async {
    final pending = PendingStore();
    await launch(tester, pending);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.pending.complete(fixedJson);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Купить чай'), findsOneWidget);

    final store = MemoryStore();
    await launchFresh(tester, store);
    await addThroughForm(tester, 'Купить хлеб');
    expect(find.text('Купить хлеб'), findsOneWidget);
    expect(fields(await TodoRepository(store).load()), [(1, 'Купить хлеб')]);
  });
}
