import 'package:flutter/material.dart';
import 'package:flutter_application_1/router.dart';
import 'package:flutter_application_1/widgets/adaptive_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ширина 360: одна колонка и нижняя навигация', (tester) async {
    await _pumpShell(tester, const Size(360, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('ширина 768: боковая навигация без подписей', (tester) async {
    await _pumpShell(tester, const Size(768, 900));
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('ширина 1280: развёрнутая навигация с подписями', (tester) async {
    await _pumpShell(tester, const Size(1280, 800));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('ЗооМаг'), findsOneWidget);
  });

  testWidgets('ширина 1920: содержимое ограничено по ширине', (tester) async {
    await _pumpShell(tester, const Size(1920, 1080));
    final box = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.maxWidth == 1440,
      ),
    );
    expect(box.constraints.maxWidth, 1440);
  });

  testWidgets('узкое окно показывает карточки, широкое — таблицу', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveEntityBody(
            cards: const [Text('карточка корма')],
            table: const Text('таблица товаров'),
          ),
        ),
      ),
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveEntityBody(
            cards: [Text('карточка корма')],
            table: Text('таблица товаров'),
          ),
        ),
      ),
    );
    expect(find.text('карточка корма'), findsOneWidget);
    expect(find.text('таблица товаров'), findsNothing);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveEntityBody(
            cards: [Text('карточка корма')],
            table: Text('таблица товаров'),
          ),
        ),
      ),
    );
    expect(find.text('таблица товаров'), findsOneWidget);
    expect(find.text('карточка корма'), findsNothing);
    tester.view.resetPhysicalSize();
  });
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const MaterialApp(
      home: AppShell(location: '/products', child: Text('каталог')),
    ),
  );
}
