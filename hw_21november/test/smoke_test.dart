import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_storage_testing_task/main.dart';
import 'package:todo_storage_testing_task/storage.dart';

import 'fakes.dart';

void main() {
  testWidgets('шаблон запускается до заполнения TODO', (tester) async {
    await tester.pumpWidget(TodoApp(repository: TodoRepository(MemoryStore())));
    await tester.pump();
    expect(find.byType(TodoPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Задачи'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
