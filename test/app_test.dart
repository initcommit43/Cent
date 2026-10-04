import 'package:cent/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches tabs from the tab bar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CentApp()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
  });
}
