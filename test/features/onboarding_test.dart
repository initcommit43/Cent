import 'package:cent/app.dart';
import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/backup_service.dart';
import 'package:cent/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

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

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh start lands on Home with the new account', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CentApp()),
    );
    await tester.pumpAndSettle();

    await tap(tester, 'Get started');
    await tap(tester, 'Continue');
    await tester.enterText(find.byType(EditableText).last, '250');
    await tester.pumpAndSettle();
    await tap(tester, 'Continue');
    await tap(tester, 'Start fresh');
    await tap(tester, 'Continue');
    await tap(tester, 'Not now');

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('€250.00'), findsWidgets);
  });

  testWidgets('erasing everything returns to onboarding', (tester) async {
    await container
        .read(onboardingServiceProvider)
        .startWithDemo(now: DateTime(2026, 10, 4), appLock: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CentApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total balance'), findsOneWidget);

    await BackupService(db).eraseAll();
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });
}
