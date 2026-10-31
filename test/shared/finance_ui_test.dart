// Shared money-screen widgets: amount format, status / service colours and
// their contrast, the hero card's scrim, and the retry button.

import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/shared/widgets/finance_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.theme, home: Scaffold(body: child));

void main() {
  test('formatGhs: cedi sign, thousands separator, two decimals', () {
    expect(formatGhs(1234.5), 'GH₵ 1,234.50');
    expect(formatGhs(0), 'GH₵ 0.00');
    expect(formatGhs(7), 'GH₵ 7.00');
  });

  test('every status tone is readable (4.5:1)', () {
    for (final tone in StatusTone.values) {
      final c = statusColors(tone);
      expect(_contrast(c.fg, c.bg), greaterThanOrEqualTo(4.5), reason: '$tone');
    }
  });

  test('service accents are readable on their tint and on white', () {
    for (final s in ServiceTone.values) {
      final st = serviceStyle(s);
      expect(_contrast(st.fg, st.bg), greaterThanOrEqualTo(4.5), reason: '$s');
      expect(_contrast(st.fg, Colors.white), greaterThanOrEqualTo(4.5),
          reason: '$s');
    }
    expect(serviceStyle(ServiceTone.delivery).fg, AppTheme.serviceDelivery);
    expect(serviceStyle(ServiceTone.gas).fg, AppTheme.serviceGas);
  });

  testWidgets('hero card: Wallet gradient, small text on the scrim',
      (tester) async {
    await tester.pumpWidget(_app(const FinanceHeroCard(
      key: ValueKey('hero'),
      label: 'Wallet balance',
      amount: 'GH₵ 10.00',
      caption: 'Available for withdrawal',
      stats: [FinanceHeroStat('Jobs', '3')],
    )));
    final box = tester
        .widget<Container>(find
            .descendant(
                of: find.byKey(const ValueKey('hero')),
                matching: find.byType(Container))
            .first)
        .decoration! as BoxDecoration;
    expect(box.gradient, AppTheme.primaryGradient);

    for (final text in ['Wallet balance', 'Available for withdrawal', 'Jobs']) {
      final onScrim = find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == AppTheme.onGradientScrim),
      );
      expect(onScrim, findsWidgets, reason: text);
    }
  });

  testWidgets('hero card hides the amount while loading', (tester) async {
    await tester.pumpWidget(_app(const FinanceHeroCard(
        label: 'Wallet balance', amount: 'GH₵ 0.00', loading: true)));
    expect(find.text('GH₵ 0.00'), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('state view: deep-green Try again, 48 px, calls onRetry',
      (tester) async {
    var retried = 0;
    await tester.pumpWidget(_app(FinanceStateView(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load',
      message: 'Check your connection.',
      isError: true,
      onRetry: () => retried++,
    )));
    final button = find.byKey(const ValueKey('finance-retry'));
    final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first);
    expect(material.color, AppTheme.primaryDark);
    expect(material.textStyle?.color, Colors.white);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(retried, 1);
  });

  testWidgets('state view without onRetry has no button', (tester) async {
    await tester.pumpWidget(_app(const FinanceStateView(
        icon: Icons.receipt_long_rounded,
        title: 'No transactions yet',
        message: 'They will appear here.')));
    expect(find.byKey(const ValueKey('finance-retry')), findsNothing);
  });
}
