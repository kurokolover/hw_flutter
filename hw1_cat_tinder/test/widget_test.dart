import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hw1_cat_tinder/cat_api.dart';
import 'package:hw1_cat_tinder/main.dart';

void main() {
  const breed = {
    'name': 'Bengal',
    'description': 'Spotted cat',
    'origin': 'USA',
    'temperament': 'Active',
    'life_span': '12–15',
    'weight': {'metric': '4–7'},
  };
  final cat = [
    {
      'url': 'https://example.org/cat.jpg',
      'breeds': [breed],
    },
  ];
  http.Response response(Object value) =>
      http.Response.bytes(utf8.encode(jsonEncode(value)), 200);
  testWidgets(
    'Навигация, жесты, быстрый ввод и восстановление на узком экране',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final pending = Completer<http.Response>();
      final api = CatApi(
        MockClient((req) async {
          expect(req.headers['x-api-key'], 'test');
          if (req.url.path.endsWith('/breeds')) return response([breed]);
          expect(req.url.queryParameters['has_breeds'], '1');
          calls++;
          if (calls == 2) return pending.future;
          return response(cat);
        }),
        key: 'test',
      );
      await tester.pumpWidget(CatApp(api: api));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('cat_card'));
      await tester.tap(find.text('Bengal'));
      await tester.pumpAndSettle();
      expect(find.text('Spotted cat'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(calls, 1);
      final like = find.byKey(const ValueKey('like_button'));
      await tester.ensureVisible(like);
      await tester.tap(like);
      await tester.tap(like);
      await tester.pump();
      expect(calls, 2);
      expect(find.text('1'), findsOneWidget);
      pending.complete(response([]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('1'), findsOneWidget);
      await tester.drag(card, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(calls, 4);
      expect(find.text('1'), findsOneWidget);
      await tester.drag(card, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(calls, 5);
      expect(find.text('2'), findsOneWidget);
      final skip = find.byKey(const ValueKey('dislike_button'));
      await tester.ensureVisible(skip);
      await tester.tap(skip);
      await tester.pumpAndSettle();
      expect(calls, 6);
      await tester.tap(find.text('Породы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bengal'));
      await tester.pumpAndSettle();
      expect(find.text('Вес, кг'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Коты'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    },
  );
  testWidgets('Таймаут при запуске, повтор и уход с экрана', (tester) async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    var calls = 0;
    final api = CatApi(
      MockClient((_) => ++calls == 1 ? first.future : second.future),
      key: 'test',
    );
    await tester.pumpWidget(CatApp(api: api));
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('Сервис долго не отвечает.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retry_button')));
    await tester.pumpWidget(const SizedBox());
    first.complete(response(cat));
    second.complete(response(cat));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(calls, 2);
  });

  test('Ошибки сервиса преобразуются в сообщения приложения', () async {
    for (final reply in [
      response([]),
      response([
        {'breeds': []},
      ]),
      response([
        {
          'url': '',
          'breeds': [breed],
        },
      ]),
      http.Response('', 403),
      http.Response('', 500),
      http.Response('{', 200),
    ]) {
      final api = CatApi(MockClient((_) async => reply), key: 'test');
      await expectLater(api.next(), throwsA(isA<LoadFailure>()));
    }
    for (final failure in [
      TimeoutException('late'),
      http.ClientException('offline'),
    ]) {
      final api = CatApi(MockClient((_) async => throw failure), key: 'test');
      await expectLater(api.next(), throwsA(isA<LoadFailure>()));
    }
    await expectLater(
      CatApi(MockClient((_) async => fail('Запрос без ключа'))).breeds(),
      throwsA(isA<LoadFailure>()),
    );
  });
}
