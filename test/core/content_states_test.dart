import 'package:cent/core/theme/cent_theme.dart';
import 'package:cent/core/widgets/content_states.dart';
import 'package:cent/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ghost = SizedBox(key: Key('ghost'), height: 40);

  Future<void> pumpSlivers(WidgetTester tester, List<Widget> slivers) =>
      tester.pumpWidget(
        MaterialApp(
          theme: CentTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CustomScrollView(slivers: slivers)),
        ),
      );

  test('falls through once every value has data', () {
    final slivers = pendingSlivers(
      const [AsyncData(1), AsyncData('a')],
      ghost: ghost,
      onRetry: () {},
    );
    expect(slivers, isNull);
  });

  testWidgets('shows the ghost only after a short delay', (tester) async {
    await pumpSlivers(
      tester,
      pendingSlivers(
        const [AsyncData(1), AsyncLoading<int>()],
        ghost: ghost,
        onRetry: () {},
      )!,
    );

    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    expect(find.byKey(const Key('ghost')), findsOneWidget);
    expect(opacity(), 0);

    await tester.pump(LoadingState.delay);
    expect(opacity(), 1);

    // Unmount so the repeating pulse doesn't outlive the test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var retries = 0;
    await pumpSlivers(
      tester,
      pendingSlivers(
        [const AsyncData(1), AsyncError<int>(Exception(), StackTrace.empty)],
        ghost: ghost,
        onRetry: () => retries++,
      )!,
    );

    expect(find.byKey(const Key('ghost')), findsNothing);
    expect(find.text('Couldn’t load this'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
