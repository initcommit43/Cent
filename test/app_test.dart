import 'package:cent/app.dart';
import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: testOverrides(db, DateTime(2026, 10, 4, 19, 30)),
    );
    await container.read(appStartupProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CentApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the balance and recent transactions', (tester) async {
    await pumpApp(tester);

    expect(find.text('Total balance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RECENT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Main account'), findsWidgets);
  });

  testWidgets('activity groups the month by day', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
  });
}
