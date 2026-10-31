// Wallet screen presentation: the balance card's loading / error / ready
// states, transaction statuses, the unchanged quick-stat totals, and the
// withdraw sheet's checks and wording (a request, not an instant payment).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/wallet/presentation/screens/driver_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
    theme: AppTheme.theme,
    home: Scaffold(body: SingleChildScrollView(child: child)));

OutlinedButton _withdrawButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byKey(const ValueKey('wallet-withdraw')));

Map<String, dynamic> _tx({
  String type = 'credit',
  String? category = 'trip_earning',
  String? status = 'completed',
  num amount = 25,
  String description = 'Trip to Airport',
  bool dated = true,
}) =>
    {
      'type': type,
      'category': category,
      'status': status,
      'amount': amount,
      'description': description,
      'createdAt':
          dated ? Timestamp.fromDate(DateTime(2026, 10, 20, 9, 30)) : null,
    };

void main() {
  group('Balance card', () {
    testWidgets('ready: balance, availability note, Withdraw enabled',
        (tester) async {
      var withdrew = 0;
      await tester.pumpWidget(_app(WalletBalanceCard(
        balance: 1250.5,
        loading: false,
        error: false,
        onWithdraw: () => withdrew++,
        onRetry: () {},
      )));
      expect(find.text('GH₵ 1,250.50'), findsOneWidget);
      expect(find.textContaining('Available for withdrawal'), findsOneWidget);
      expect(find.textContaining('minimum GH₵ 10.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wallet-withdraw')));
      expect(withdrew, 1);
    });

    testWidgets('loading: no amount, Withdraw disabled', (tester) async {
      await tester.pumpWidget(_app(WalletBalanceCard(
        balance: 0,
        loading: true,
        error: false,
        onWithdraw: () {},
        onRetry: () {},
      )));
      expect(find.text('GH₵ 0.00'), findsNothing);
      expect(_withdrawButton(tester).onPressed, isNull);
    });

    testWidgets('error: never shows GH₵ 0.00; the button retries',
        (tester) async {
      var withdrew = 0, retried = 0;
      await tester.pumpWidget(_app(WalletBalanceCard(
        balance: 0,
        loading: false,
        error: true,
        onWithdraw: () => withdrew++,
        onRetry: () => retried++,
      )));
      expect(find.text('GH₵ 0.00'), findsNothing);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining('could not load your balance'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wallet-withdraw')));
      expect((withdrew, retried), (0, 1));
    });

    testWidgets('Withdraw: white button, readable deep-green text',
        (tester) async {
      await tester.pumpWidget(_app(WalletBalanceCard(
        balance: 20,
        loading: false,
        error: false,
        onWithdraw: () {},
        onRetry: () {},
      )));
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byKey(const ValueKey('wallet-withdraw')),
              matching: find.byType(Material))
          .first);
      expect(material.color, Colors.white);
      expect(material.textStyle?.color, AppTheme.primaryDeep);
      expect(
          tester.getSize(find.byKey(const ValueKey('wallet-withdraw'))).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('Earnings card', () {
    testWidgets('shows the stored period figures', (tester) async {
      await tester.pumpWidget(_app(const WalletEarningsCard(
        todayEarnings: 45,
        weekEarnings: 310.25,
        totalEarnings: 5000,
        completedTrips: 42,
        loading: false,
      )));
      expect(find.text('GH₵ 45.00'), findsOneWidget);
      expect(find.text('GH₵ 310.25'), findsOneWidget);
      expect(find.text('GH₵ 5,000.00'), findsOneWidget);
      expect(find.text('42 trips completed'), findsOneWidget);
    });

    testWidgets('error replaces the figures with a message', (tester) async {
      await tester.pumpWidget(_app(const WalletEarningsCard(
        todayEarnings: 0,
        weekEarnings: 0,
        totalEarnings: 0,
        completedTrips: 0,
        loading: false,
        error: true,
      )));
      expect(find.text('GH₵ 0.00'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });
  });

  group('Quick stats (totals unchanged)', () {
    testWidgets('in = credit earning categories; out = all debits; pending',
        (tester) async {
      await tester.pumpWidget(_app(WalletQuickStats(txList: [
        _tx(amount: 30), // trip_earning credit: in
        _tx(category: 'bonus', amount: 5), // in
        _tx(category: 'other', amount: 100), // credit, not an earning: no
        _tx(type: 'debit', category: 'withdrawal', amount: 20, status: 'pending'),
        _tx(type: 'debit', category: 'commission', amount: 4.5),
      ])));
      expect(find.text('GH₵ 35.00'), findsOneWidget); // in
      expect(find.text('GH₵ 24.50'), findsOneWidget); // out
      expect(find.text('1'), findsOneWidget); // pending
      expect(find.text('Based on your recent transactions.'), findsOneWidget);
    });
  });

  group('Transaction tile', () {
    Future<void> pump(WidgetTester t, Map<String, dynamic> tx) =>
        t.pumpWidget(_app(WalletTransactionTile(tx: tx)));

    testWidgets('credit: plus sign, deep green, category, no status pill',
        (tester) async {
      await pump(tester, _tx());
      final amount = tester.widget<Text>(find.text('+ GH₵ 25.00'));
      expect(amount.style?.color, AppTheme.primaryDark);
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Failed'), findsNothing);
      expect(find.text('Oct 20 · 9:30 AM'), findsOneWidget);
    });

    testWidgets('pending withdrawal is labelled Pending', (tester) async {
      await pump(tester,
          _tx(type: 'debit', category: 'withdrawal', status: 'pending'));
      expect(find.text('− GH₵ 25.00'), findsOneWidget);
      expect(find.text('Withdrawal'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('failed is labelled Failed and struck through',
        (tester) async {
      await pump(tester,
          _tx(type: 'debit', category: 'withdrawal', status: 'failed'));
      expect(find.text('Failed'), findsOneWidget);
      final amount = tester.widget<Text>(find.text('− GH₵ 25.00'));
      expect(amount.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('other stored statuses are shown, not hidden', (tester) async {
      await pump(tester, _tx(type: 'debit', status: 'pending_review'));
      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('a missing date is not replaced with today', (tester) async {
      await pump(tester, _tx(dated: false));
      expect(find.text('Date unavailable'), findsOneWidget);
    });
  });

  test('accepted request message: a request shown as Pending, no review or '
      'timing promise', () {
    final m = withdrawalRequestedMessage(20, '0241234567');
    expect(
        m,
        'Withdrawal of GH₵ 20.00 requested. It shows as Pending until the '
        'payment to 0241234567 is confirmed.');
    expect(m, isNot(contains('review')));
    expect(m, isNot(contains('approved')));
  });

  group('Withdraw sheet', () {
    late List<String> invalid;
    late List<(double, String, String)> submitted;
    late Completer<void> server;

    Future<void> pumpSheet(WidgetTester tester, {double balance = 50}) async {
      invalid = [];
      submitted = [];
      server = Completer<void>();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: WithdrawSheet(
            balance: balance,
            onInvalid: invalid.add,
            onSubmit: (a, m, p) {
              submitted.add((a, m, p));
              return server.future;
            },
          ),
        ),
      ));
    }

    FilledButton submitButton(WidgetTester t) =>
        t.widget<FilledButton>(find.byKey(const ValueKey('withdraw-submit')));

    Future<void> fill(WidgetTester t, String amount, String phone) async {
      await t.enterText(find.byType(TextField).at(0), amount);
      await t.enterText(find.byType(TextField).at(1), phone);
    }

    testWidgets('a request shown as Pending until confirmed; no review or '
        'timing promise', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Request withdrawal'), findsOneWidget);
      expect(find.textContaining('Instant'), findsNothing);
      // The deployed payout sends to Bridge at once: there is no review step.
      expect(find.textContaining('review'), findsNothing);
      expect(
          find.text('Your withdrawal is sent to your mobile money provider. '
              'It shows as Pending until the payment is confirmed.'),
          findsOneWidget);
      expect(find.text('Available balance: GH₵ 50.00'), findsOneWidget);
    });

    testWidgets('disabled until a network is chosen', (tester) async {
      await pumpSheet(tester);
      expect(submitButton(tester).onPressed, isNull);
      expect(find.text('Choose a network to continue'), findsOneWidget);
      await tester.tap(find.text('MTN MoMo'));
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('original checks, in order, before any server call',
        (tester) async {
      await pumpSheet(tester, balance: 50);
      await tester.tap(find.text('Telecel Cash'));
      await tester.pump();

      for (final (amount, phone, message) in [
        ('5', '0241234567', 'Minimum withdrawal is GH₵ 10'),
        ('60', '0241234567', 'Insufficient wallet balance'),
        ('20', '', 'Enter your mobile number'),
      ]) {
        await fill(tester, amount, phone);
        await tester.tap(find.byKey(const ValueKey('withdraw-submit')));
        await tester.pump();
        expect(invalid.last, message);
      }
      expect(submitted, isEmpty);
    });

    testWidgets('valid request: submits once and shows progress until the '
        'server answers', (tester) async {
      await pumpSheet(tester, balance: 50);
      await tester.tap(find.text('MTN MoMo'));
      await tester.pump();
      await fill(tester, '20', '0241234567');
      await tester.tap(find.byKey(const ValueKey('withdraw-submit')));
      await tester.pump();

      expect(submitted, [(20.0, 'MTN MoMo', '0241234567')]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);

      server.complete();
      await tester.pumpAndSettle();
      expect(find.text('Request withdrawal'), findsOneWidget);
    });
  });

  testWidgets('overview fits 320 px at 1.5× text', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
            WalletBalanceCard(
                balance: 12345.67,
                loading: false,
                error: false,
                onWithdraw: () {},
                onRetry: () {}),
            const WalletEarningsCard(
                todayEarnings: 1234.5,
                weekEarnings: 9876.54,
                totalEarnings: 123456.78,
                completedTrips: 1200,
                loading: false),
            WalletQuickStats(txList: [
              _tx(amount: 12345.67),
              _tx(type: 'debit', category: 'withdrawal', amount: 9999.99),
            ]),
            WalletTransactionTile(
                tx: _tx(
                    type: 'debit',
                    category: 'commission',
                    status: 'pending_review',
                    description: 'Commission on a very long trip description '
                        'that wraps')),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('withdraw sheet fits 320 px at 1.5× text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: WithdrawSheet(
              balance: 12345.67,
              onInvalid: (_) {},
              onSubmit: (_, __, ___) async {}),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
