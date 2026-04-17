import 'package:flutter_test/flutter_test.dart';
import 'package:hopefulme_flutter/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows auth welcome screen when there is no saved session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const HopefulMeApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to\nHopefulMe.'), findsOneWidget);
  });
}
