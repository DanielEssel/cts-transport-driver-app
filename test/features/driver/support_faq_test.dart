// Support FAQ: the withdrawal answer states the minimum the backend enforces
// (GH₵ 10: initiateBridgePayout's floor and settings/platform's value) and
// makes no review or payment-time promise.

import 'package:cts_transport_driver_app/features/driver/presentation/driver_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('withdrawal FAQ: GH₵ 10 minimum, Pending until confirmed',
      (tester) async {
    // The screen's tiles trip one pre-existing debug-only check (a ListTile
    // inside a coloured Container). Tolerate exactly that message; any other
    // error still fails the test.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
          'ListTile background color or ink splashes may be invisible')) {
        return;
      }
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);

    await tester.pumpWidget(const MaterialApp(home: DriverSupportScreen()));
    final question = find.text('How do I withdraw my earnings?');
    await tester.scrollUntilVisible(question, 200);
    await tester.tap(question);
    await tester.pumpAndSettle();

    final answer = find.textContaining('minimum withdrawal');
    expect(answer, findsOneWidget);
    final text = tester.widget<Text>(answer).data!;
    expect(text, contains('GH₵ 10'));
    expect(text, contains('shows as Pending until the payment is confirmed'));
    expect(text, isNot(contains('50')));
    expect(text, isNot(contains('24 hours')));
    expect(text, isNot(contains('business days')));
  });
}
