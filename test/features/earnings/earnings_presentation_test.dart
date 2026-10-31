// Earnings screen presentation: the estimate is labelled as one, figures
// match the records, the period selector, the day detail, empty states and
// small screens.

import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/earnings/presentation/screens/earning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rate = 0.15;

DailyEarningsRecord _day(DateTime date,
    {int trips = 2, int deliveries = 1, int gas = 0, double gross = 100}) {
  final fee = gross * _rate;
  return DailyEarningsRecord(
    date: date,
    trips: trips,
    deliveries: deliveries,
    gasOrders: gas,
    gross: gross,
    platformFee: fee,
    net: gross - fee,
  );
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, 12);
}

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.theme, home: Scaffold(body: child));

void main() {
  group("Today's card", () {
    testWidgets('net, job counts, and an estimate note pointing to Wallet',
        (tester) async {
      await tester.pumpWidget(_app(EarningsTodayCard(
          today: _day(_today(), trips: 3, deliveries: 1, gas: 2, gross: 200),
          feeRate: _rate)));
      expect(find.text('GH₵ 170.00'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // jobs
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('Estimated'), findsOneWidget);
      expect(find.textContaining('15% platform fee'), findsOneWidget);
      expect(find.textContaining('withdrawable balance is in Wallet'),
          findsOneWidget);
    });

    testWidgets('no jobs today: zero, not hidden', (tester) async {
      await tester
          .pumpWidget(_app(const EarningsTodayCard(today: null, feeRate: _rate)));
      expect(find.text('GH₵ 0.00'), findsOneWidget);
    });
  });

  group('Daily view', () {
    testWidgets('empty: names the selected period', (tester) async {
      for (final (period, label) in [
        ('week', 'No earnings this week'),
        ('month', 'No earnings this month'),
        ('year', 'No earnings this year'),
      ]) {
        await tester.pumpWidget(_app(EarningsDailyView(
            records: const [], today: null, period: period, feeRate: _rate)));
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('day tile shows net and fee; detail lists the breakdown',
        (tester) async {
      final day = DateTime(2026, 3, 4, 10);
      await tester.pumpWidget(_app(EarningsDailyView(
          records: [_day(day, trips: 2, deliveries: 1, gross: 80)],
          today: null,
          period: 'month',
          feeRate: _rate)));

      final tile = find.byType(EarningsDayTile);
      expect(find.descendant(of: tile, matching: find.text('GH₵ 68.00')),
          findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Fee GH₵ 12.00')),
          findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('2 trips')),
          findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('1 delivery')),
          findsOneWidget);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final sheet = find.byType(EarningsDayDetail);
      expect(sheet, findsOneWidget);
      for (final t in [
        'Wednesday, March 4, 2026',
        'Gross fares',
        'GH₵ 80.00',
        'Platform fee (15%)',
        '− GH₵ 12.00',
        'Net earnings',
        'GH₵ 68.00',
      ]) {
        expect(find.descendant(of: sheet, matching: find.text(t)),
            findsOneWidget,
            reason: t);
      }
      final close = tester.widget<Material>(find
          .descendant(
              of: find.widgetWithText(FilledButton, 'Close'),
              matching: find.byType(Material))
          .first);
      expect(close.color, AppTheme.primaryDark);
    });

    testWidgets('chart: a week fits; longer periods scroll sideways',
        (tester) async {
      final start = DateTime(2026, 1, 1, 12);
      List<DailyEarningsRecord> days(int n) => [
            for (var i = 0; i < n; i++)
              _day(start.add(Duration(days: i)), gross: 10.0 + i)
          ];

      await tester.pumpWidget(_app(
          EarningsTrendChart(records: days(7), period: 'week')));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('earnings-trend-chart')),
              matching: find.byType(ListView)),
          findsNothing);

      await tester.pumpWidget(_app(
          EarningsTrendChart(records: days(40), period: 'month')));
      expect(tester.takeException(), isNull);
      final list = tester.widget<ListView>(find.descendant(
          of: find.byKey(const ValueKey('earnings-trend-chart')),
          matching: find.byType(ListView)));
      expect(list.scrollDirection, Axis.horizontal);
      expect(list.reverse, isTrue); // opens on the most recent day
    });
  });

  group('Summary view', () {
    testWidgets('totals come from the records; fee = gross × rate',
        (tester) async {
      final records = [
        _day(DateTime(2026, 3, 2, 9), trips: 2, deliveries: 1, gross: 100),
        _day(DateTime(2026, 3, 3, 9), trips: 1, deliveries: 0, gas: 1, gross: 60),
      ];
      final gross = records.fold(0.0, (s, r) => s + r.gross);
      final net = records.fold(0.0, (s, r) => s + r.net);
      await tester.pumpWidget(_app(EarningsSummaryView(
        records: records,
        totalNet: net,
        totalGross: gross,
        totalJobs: 6,
        period: 'month',
        feeRate: _rate,
      )));
      final hero = find.byKey(const ValueKey('earnings-period-card'));
      expect(find.descendant(of: hero, matching: find.text('This Month · net earnings')),
          findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('GH₵ 136.00')),
          findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('GH₵ 160.00')),
          findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('GH₵ 24.00')),
          findsOneWidget);
      expect(find.text('GH₵ 22.67'), findsOneWidget); // avg / job: 136 / 6
      expect(find.text('GH₵ 68.00'), findsOneWidget); // avg / active day
      expect(find.text('Week projection'), findsNothing); // weeks only
    });
  });

  group('Period selector', () {
    testWidgets('selected is deep green with white text; taps report value',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_app(
          EarningsPeriodSelector(period: 'week', onChanged: picked.add)));

      Material fill(String v) => tester.widget<Material>(find
          .ancestor(
              of: find.byKey(ValueKey('earnings-period-$v')),
              matching: find.byType(Material))
          .first);
      expect(fill('week').color, AppTheme.primaryDark);
      expect(fill('month').color, Colors.transparent);
      expect(tester.widget<Text>(find.text('This Week')).style?.color,
          AppTheme.onPrimary);
      expect(
          tester.getSize(find.byKey(const ValueKey('earnings-period-month'))).height,
          greaterThanOrEqualTo(44));

      await tester.tap(find.text('This Month'));
      await tester.tap(find.text('This Year'));
      expect(picked, ['month', 'year']);
    });
  });

  testWidgets('daily and summary fit 320 px at 1.5× text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final records = [
      for (var i = 6; i >= 0; i--)
        _day(_today().subtract(Duration(days: i)),
            trips: 12, deliveries: 10, gas: 9, gross: 12345.67),
    ];
    for (final view in [
      EarningsDailyView(
          records: records, today: records.last, period: 'week', feeRate: _rate),
      EarningsSummaryView(
          records: records,
          totalNet: 73456.78,
          totalGross: 86419.69,
          totalJobs: 217,
          period: 'week',
          feeRate: _rate),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: Column(children: [
              EarningsPeriodSelector(period: 'month', onChanged: (_) {}),
              Expanded(child: view),
            ]),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: '${view.runtimeType}');
      // Scroll the whole list so every item is laid out.
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${view.runtimeType}');
    }
  });
}
