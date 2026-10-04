import 'package:cent/app.dart';
import 'package:cent/core/database/app_database.dart';
import 'package:cent/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 4, 19, 30)),
      ],
    );
    await container.read(appStartupProvider.future);
  });

  tearDown(() => container.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CentApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the balance and recent transactions', (tester) async {
    await pumpApp(tester);

    expect(find.text('Total balance'), findsOneWidget);
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
