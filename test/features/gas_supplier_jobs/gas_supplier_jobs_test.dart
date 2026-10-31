// Driver side of Gas supplier jobs against a fake server.
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'dart:io';

import 'package:cts_transport_driver_app/features/driver/services/driver_notification_service.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/gas_supplier_jobs_entry.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/gas_supplier_jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeServer {
  final calls = <String>[];
  final data = <String, Map<String, dynamic>>{};
  bool enabled = true, handedOver = false, statusFails = false;
  String code = '4821';
  /// The driver's own jobs in progress (listMyGasSupplierJobs), by status.
  List<String> mine = const [];
  /// Linked-rider offers (listGasSupplierJobs `offers`) and the earnings list.
  List<Map<String, dynamic>> offers = const [];
  List<Map<String, dynamic>> earnings = const [];
  int serverNowMs = 1000000;
  /// Reason the next accept is refused with, if any.
  String? acceptRefusal;
  /// When set, the job lists (open and own) fail as a dropped connection would.
  bool listsFail = false;
  /// Orders this driver accepted, with their status, as the real server lists them.
  final assigned = <String, String>{};

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> d) async {
    calls.add(name);
    data[name] = d;
    // The status callable is not gated: it reports the flag.
    if (name == 'gasSupplierOrderingStatus') {
      if (statusFails) throw Exception('not deployed');
      return {'enabled': enabled};
    }
    if (!enabled) throw GasSupplierJobFailure('unavailable', 'gas_supplier_fulfilment_disabled', gasSupplierJobMessage('gas_supplier_fulfilment_disabled', ''));
    if (listsFail && (name == 'listGasSupplierJobs' || name == 'listMyGasSupplierJobs')) {
      throw const GasSupplierJobFailure('unavailable', null, 'Could not reach CTSGo.');
    }
    switch (name) {
      case 'listGasSupplierJobs':
        return {'jobs': [{'orderId': 'order123456', 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg12_5', 'quantity': 2,
          'station': {'name': 'Tema Station', 'address': 'Community 1', 'location': {'latitude': 5.66, 'longitude': -0.01}},
          'deliveryAddress': 'Home', 'deliveryLocation': {'latitude': 5.68, 'longitude': -0.01}, 'deliveryFee': 14.5, 'distanceKm': 1.3}],
          if (offers.isNotEmpty) 'offers': offers, if (offers.isNotEmpty) 'serverNowMs': serverNowMs};
      case 'listMyGasSupplierEarnings':
        return {'earnings': earnings};
      case 'acceptGasSupplierJob':
        if (acceptRefusal != null) throw GasSupplierJobFailure('failed-precondition', acceptRefusal, gasSupplierJobMessage(acceptRefusal, ''));
        assigned['${d['orderId']}'] = 'driverAssigned';
        return {'ok': true};
      case 'arriveGasSupplierStation':
        assigned['${d['orderId']}'] = 'atStation';
        return {'ok': true};
      case 'listMyGasSupplierJobs':
        return {'jobs': [for (final st in mine) {'orderId': 'mine-$st', 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg6', 'quantity': 1,
          'station': {'name': 'Tema Station', 'address': 'Community 1'}, 'deliveryAddress': 'Home', 'status': st, 'onDriverRecord': true},
          for (final e in assigned.entries) {'orderId': e.key, 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg12_5', 'quantity': 2,
            'station': {'name': 'Tema Station'}, 'deliveryAddress': 'Home', 'status': e.value, 'onDriverRecord': true}]};
      case 'completeGasSupplierOrder':
        if (!handedOver) throw GasSupplierJobFailure('failed-precondition', 'invalid_transition', gasSupplierJobMessage('invalid_transition', ''));
        if (d['code'] != code) throw GasSupplierJobFailure('permission-denied', 'completion_code_mismatch', gasSupplierJobMessage('completion_code_mismatch', ''));
        assigned.remove('${d['orderId']}');
        return {'status': 'delivered'};
      default:
        return {'ok': true};
    }
  }
}

Map<String, dynamic> offerMap({String id = 'off1', int seq = 2, int expiresAtMs = 1060000, int feePesewas = 1500}) => {
      'orderId': id, 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg12_5', 'quantity': 1,
      'station': {'name': 'Tema Station', 'address': 'Community 1'},
      'deliveryAddress': 'Home', 'deliveryLocation': {'latitude': 5.68, 'longitude': -0.01},
      'offerSeq': seq, 'expiresAtMs': expiresAtMs, 'deliveryFeePesewas': feePesewas, 'feePaidBy': 'ctsgo',
    };

void main() {
  test('jobs are parsed from the server answer, and only digits are sent as a code', () async {
    final s = FakeServer();
    final repo = GasSupplierJobRepository(call: s.call);
    final job = (await repo.openJobs()).jobs.single;
    expect([job.orderId, job.quantity, job.station.name, job.delivery.address, job.deliveryFee], ['order123456', 2, 'Tema Station', 'Home', 14.5]);
    expect(() => repo.complete('order123456', '12ab'), throwsA(isA<GasSupplierJobFailure>()));
    expect(s.calls, ['listGasSupplierJobs']);
    s.handedOver = true;
    await repo.complete('order123456', ' 4821 ');
    expect(s.data['completeGasSupplierOrder'], {'orderId': 'order123456', 'code': '4821'});
  });

  test('refusal reasons become driver messages', () {
    expect(gasSupplierJobMessage('outside_radius', 'x'), contains('too far'));
    expect(gasSupplierJobMessage('invalid_transition', 'x'), contains('supplier has not handed over'));
    expect(gasSupplierJobMessage('unknown', 'Server text'), 'Server text');
    expect(gasSupplierJobMessage('completion_code_locked', 'x'), contains('Contact CTSGo support'));
  });

  testWidgets('accept, arrive, refused early completion, then complete with the code', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = FakeServer();
    await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: GasSupplierJobRepository(call: s.call))));
    await tester.pump();
    expect(find.text('Accept GH₵14.50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gsj-accept-order123456')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gsj-arrived')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
    await tester.tap(find.byKey(const Key('gsj-complete')));
    await tester.pump();
    expect(find.textContaining('supplier has not handed over'), findsOneWidget);
    s.handedOver = true;
    await tester.enterText(find.byKey(const Key('gsj-code')), '1111');
    await tester.tap(find.byKey(const Key('gsj-complete')));
    await tester.pump();
    expect(find.textContaining('code is not right'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
    await tester.tap(find.byKey(const Key('gsj-complete')));
    await tester.pump();
    expect(find.byKey(const Key('gsj-done')), findsOneWidget);
    // The refused early completion is checked against the server once (still the driver's job, still at the station).
    expect(s.calls, ['listMyGasSupplierJobs', 'listGasSupplierJobs', 'listMyGasSupplierEarnings', 'acceptGasSupplierJob', 'arriveGasSupplierStation', 'completeGasSupplierOrder', 'listMyGasSupplierJobs', 'completeGasSupplierOrder', 'completeGasSupplierOrder']);
  });

  testWidgets('shows that jobs are not available while the feature is off', (tester) async {
    final s = FakeServer()..enabled = false;
    await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: GasSupplierJobRepository(call: s.call))));
    await tester.pump();
    expect(find.text('Gas supplier jobs are not available yet.'), findsOneWidget);
  });

  test('a resumed job starts at the step its server status names', () {
    expect(gasSupplierJobStep('driverAssigned'), GasSupplierJobStep.goingToStation);
    expect(gasSupplierJobStep('atStation'), GasSupplierJobStep.atStation);
    expect(gasSupplierJobStep('outForDelivery'), GasSupplierJobStep.delivering);
    expect(gasSupplierJobStep(null), GasSupplierJobStep.goingToStation);
  });

  testWidgets("after a restart the driver's accepted job is offered and resumes at its step", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = FakeServer()..mine = ['atStation'];
    await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: GasSupplierJobRepository(call: s.call))));
    await tester.pump();
    expect(find.text('In progress'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gsj-resume-mine-atStation')));
    await tester.pumpAndSettle();
    // Already at the station: no arrival step, straight to the code.
    expect(find.byKey(const Key('gsj-arrived')), findsNothing);
    expect(find.byKey(const Key('gsj-code')), findsOneWidget);
    s.handedOver = true;
    await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
    await tester.tap(find.byKey(const Key('gsj-complete')));
    await tester.pump();
    expect(find.byKey(const Key('gsj-done')), findsOneWidget);
    expect(s.data['completeGasSupplierOrder'], {'orderId': 'mine-atStation', 'code': '4821'});
  });

  testWidgets('a job just accepted (driverAssigned) resumes at the arrival step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = FakeServer()..mine = ['driverAssigned'];
    await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: GasSupplierJobRepository(call: s.call))));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gsj-resume-mine-driverAssigned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gsj-arrived')), findsOneWidget);
  });

  group('home screen entry', () {
    Future<FakeServer> pumpEntry(WidgetTester tester, FakeServer s) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GasSupplierJobsEntry(repository: GasSupplierJobRepository(call: s.call)))));
      await tester.pump();
      return s;
    }

    testWidgets('hidden while the service is off or its status cannot be read', (tester) async {
      await pumpEntry(tester, FakeServer()..enabled = false);
      expect(find.byKey(const Key('gsj-entry')), findsNothing);
      await pumpEntry(tester, FakeServer()..statusFails = true);
      expect(find.byKey(const Key('gsj-entry')), findsNothing);
    });

    testWidgets('shown while on, and opens the jobs screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final s = await pumpEntry(tester, FakeServer());
      expect(find.text('Gas supplier jobs'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gsj-entry')));
      await tester.pumpAndSettle();
      expect(find.text('Accept GH₵14.50'), findsOneWidget);
      expect(s.calls.first, 'gasSupplierOrderingStatus');
    });

    testWidgets('offers the job in progress first', (tester) async {
      await pumpEntry(tester, FakeServer()..mine = ['outForDelivery']);
      expect(find.text('Gas supplier job in progress'), findsOneWidget);
    });

    test('the home screen shows the entry to delivery drivers', () {
      // DriverHomeScreen needs live Firestore providers to pump, so its
      // wiring is pinned here; the entry itself is tested above.
      final src = File('lib/features/driver/presentation/screens/driver_home_screen.dart').readAsStringSync();
      expect(src, contains("if (profile.role == 'driver_delivery')\n                const SliverToBoxAdapter(child: GasSupplierJobsEntry()),"));
    });
  });

  group('offers and earnings data layer', () {
    test('DA-01 openJobs parses offers and serverNowMs; old responses give none', () async {
      final s = FakeServer()..offers = [offerMap()];
      final list = await GasSupplierJobRepository(call: s.call).openJobs();
      expect(list.jobs.single.orderId, 'order123456');
      final o = list.offers.single;
      expect([o.orderId, o.offerSeq, o.expiresAtMs, o.deliveryFee], ['off1', 2, 1060000, 15.0]);
      expect(list.serverNowMs, 1000000);
      final old = await GasSupplierJobRepository(call: FakeServer().call).openJobs();
      expect(old.offers, isEmpty);
      expect(old.serverNowMs, isNull);
    });

    test('DA-02 accept refreshes location first and sends offerSeq; no fix means no call', () async {
      final s = FakeServer();
      final order = <String>[];
      final repo = GasSupplierJobRepository(call: (n, d) { order.add(n); return s.call(n, d); }, refreshLocation: () async { order.add('location'); return true; });
      await repo.accept('o1', offerSeq: 2);
      expect(order, ['location', 'acceptGasSupplierJob']);
      expect(s.data['acceptGasSupplierJob'], {'orderId': 'o1', 'offerSeq': 2});

      final s2 = FakeServer();
      final stale = GasSupplierJobRepository(call: s2.call, refreshLocation: () async => false);
      await expectLater(stale.accept('o1', offerSeq: 2), throwsA(isA<GasSupplierJobFailure>().having((e) => e.reason, 'reason', 'driver_location_stale')));
      expect(s2.calls, isEmpty);
      // A plain job accept (no offerSeq) is unchanged.
      await GasSupplierJobRepository(call: s2.call, refreshLocation: () async => false).accept('o1');
      expect(s2.data['acceptGasSupplierJob'], {'orderId': 'o1'});
    });

    test('DA-03 decline sends the offer sequence', () async {
      final s = FakeServer();
      await GasSupplierJobRepository(call: s.call).decline('o1', 2);
      expect(s.calls, ['declineGasSupplierRiderOffer']);
      expect(s.data['declineGasSupplierRiderOffer'], {'orderId': 'o1', 'offerSeq': 2});
    });

    test('DA-04 earning labels never say Paid', () {
      expect(gasEarningLabel('pending'), 'Earned · pending');
      expect(gasEarningLabel('owed'), 'Owed');
      expect(gasEarningLabel('credited_to_wallet'), 'Credited to wallet');
      expect(gasEarningLabel('reversed'), 'Reversed');
      expect(gasEarningLabel('outstanding_adjustment'), 'Under review');
      for (final st in ['pending', 'owed', 'credited_to_wallet', 'reversed', 'outstanding_adjustment', 'other']) {
        expect(gasEarningLabel(st), isNot(contains('Paid')));
      }
    });

    test('myEarnings parses the list', () async {
      final s = FakeServer()..earnings = [{'orderId': 'e1', 'amountPesewas': 1500, 'status': 'pending', 'deliveredAtMs': 5, 'eligibleFromMs': 9, 'creditedAtMs': null, 'linkedSupplierName': 'Tema Gas'}];
      final e = (await GasSupplierJobRepository(call: s.call).myEarnings()).single;
      expect([e.orderId, e.amountPesewas, e.status, e.deliveredAtMs, e.eligibleFromMs, e.creditedAtMs, e.linkedSupplierName], ['e1', 1500, 'pending', 5, 9, null, 'Tema Gas']);
    });

    test('DA-05 new refusal reasons map to their messages', () {
      expect(gasSupplierJobMessage('offer_expired', 'x'), 'This offer has expired.');
      expect(gasSupplierJobMessage('offer_stale', 'x'), 'This offer changed. Pull to refresh.');
      expect(gasSupplierJobMessage('rider_not_linked', 'x'), "You're no longer linked to this supplier.");
      expect(gasSupplierJobMessage('rider_fee_changed', 'x'), 'This offer changed. Pull to refresh.');
      expect(gasSupplierJobMessage('driver_location_stale', 'x'), 'Your location is out of date. Turn on location and try again.');
    });
  });

  group('offer card, earnings and push routing', () {
    const feeText = "You earn this fee when the customer confirms delivery with their code. After CTSGo's settlement hold, CTSGo credits it to your CTSGo wallet. You can then request a withdrawal. Money is paid out only when CTSGo confirms the transfer. Any commission you owe from cash jobs is deducted when you withdraw.";

    /// Device clock the screen reads; the fake server's clock is 120 s ahead of it.
    late int clock;
    setUp(() => clock = 5000000);
    GasSupplierJobRepository repoFor(FakeServer s, {bool fix = true}) =>
        GasSupplierJobRepository(call: s.call, refreshLocation: () async => fix);

    Future<void> pumpScreen(WidgetTester tester, FakeServer s, {bool fix = true}) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      s.serverNowMs = clock + 120000;
      await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: repoFor(s, fix: fix), clockMs: () => clock)));
      await tester.pump();
      addTearDown(() async => tester.pumpWidget(const SizedBox()));
    }

    testWidgets('DU-01 the offer card shows the fee, station, address and countdown', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 90000)];
      await pumpScreen(tester, s);
      expect(find.text('Offer from your supplier'), findsOneWidget);
      expect(find.text('Delivery fee GH₵15.00 · paid by CTSGo'), findsOneWidget);
      expect(find.textContaining('Tema Station'), findsWidgets);
      expect(find.textContaining('Home'), findsWidgets);
      expect(find.byKey(const Key('gsj-offer-countdown-off1')), findsOneWidget);
      expect(find.byKey(const Key('gsj-offer-accept-off1')), findsOneWidget);
      expect(find.byKey(const Key('gsj-offer-decline-off1')), findsOneWidget);
    });

    testWidgets('DU-02 the countdown uses the server clock; at zero the card is expired and disabled', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)];
      await pumpScreen(tester, s);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('3:00'), findsNothing);
      clock += 30000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:30'), findsOneWidget);
      clock += 31000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Expired'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('gsj-offer-accept-off1'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('gsj-offer-decline-off1'))).onPressed, isNull);
    });

    testWidgets('DU-03 accept opens the job; a refusal shows its message and reloads', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)];
      await pumpScreen(tester, s);
      await tester.tap(find.byKey(const Key('gsj-offer-accept-off1')));
      await tester.pumpAndSettle();
      expect(s.data['acceptGasSupplierJob'], {'orderId': 'off1', 'offerSeq': 2});
      expect(find.byType(GasSupplierActiveJobScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      for (final reason in ['job_taken', 'offer_expired']) {
        s.acceptRefusal = reason;
        s.calls.clear();
        await tester.tap(find.byKey(const Key('gsj-offer-accept-off1')));
        await tester.pumpAndSettle();
        expect(find.text(gasSupplierJobMessage(reason, '')), findsOneWidget, reason: reason);
        expect(s.calls, contains('listGasSupplierJobs'), reason: reason);
        expect(find.byType(GasSupplierActiveJobScreen), findsNothing);
      }
    });

    testWidgets('accept without a location fix says so and does not call the server', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)];
      await pumpScreen(tester, s, fix: false);
      await tester.tap(find.byKey(const Key('gsj-offer-accept-off1')));
      await tester.pumpAndSettle();
      expect(find.text('Your location is out of date. Turn on location and try again.'), findsOneWidget);
      expect(s.calls, isNot(contains('acceptGasSupplierJob')));
    });

    testWidgets('DU-04 decline asks first, then calls decline', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)];
      await pumpScreen(tester, s);
      await tester.tap(find.byKey(const Key('gsj-offer-decline-off1')));
      await tester.pumpAndSettle();
      expect(s.calls, isNot(contains('declineGasSupplierRiderOffer')));
      await tester.tap(find.byKey(const Key('gsj-decline-cancel')));
      await tester.pumpAndSettle();
      expect(s.calls, isNot(contains('declineGasSupplierRiderOffer')));
      await tester.tap(find.byKey(const Key('gsj-offer-decline-off1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gsj-decline-confirm')));
      await tester.pumpAndSettle();
      expect(s.data['declineGasSupplierRiderOffer'], {'orderId': 'off1', 'offerSeq': 2});
    });

    testWidgets('DU-04b a decline without an offer sequence never reaches the server and asks for a refresh', (tester) async {
      final s = FakeServer()..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)..remove('offerSeq')];
      await pumpScreen(tester, s);
      await tester.tap(find.byKey(const Key('gsj-offer-decline-off1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gsj-decline-confirm')), findsNothing);
      expect(s.calls, isNot(contains('declineGasSupplierRiderOffer')));
      expect(find.text('This offer changed. Pull to refresh.'), findsOneWidget);
    });

    testWidgets('DU-07 a failed 30 s poll keeps the offer and the jobs on screen; the next good poll updates them', (tester) async {
      final s = FakeServer()
        ..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 600000)]
        ..mine = ['atStation'];
      await pumpScreen(tester, s);
      expect(find.byKey(const Key('gsj-offer-off1')), findsOneWidget);
      expect(find.byKey(const Key('gsj-accept-order123456')), findsOneWidget);
      expect(find.byKey(const Key('gsj-resume-mine-atStation')), findsOneWidget);

      s.listsFail = true;
      s.calls.clear();
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(s.calls, contains('listGasSupplierJobs'), reason: 'the poll ran');
      expect(find.byKey(const Key('gsj-offer-off1')), findsOneWidget);
      expect(find.byKey(const Key('gsj-accept-order123456')), findsOneWidget);
      expect(find.byKey(const Key('gsj-resume-mine-atStation')), findsOneWidget);
      expect(find.byKey(const Key('gsj-error')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('gsj-offer-accept-off1'))).onPressed, isNotNull);

      s.listsFail = false;
      s.offers = [offerMap(id: 'off2', expiresAtMs: 5000000 + 120000 + 600000)];
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.byKey(const Key('gsj-offer-off1')), findsNothing);
      expect(find.byKey(const Key('gsj-offer-off2')), findsOneWidget);
    });

    testWidgets('DU-05 fee wording is exact, the delivered screen says earned and pending, nothing says Paid', (tester) async {
      final s = FakeServer()
        ..offers = [offerMap(expiresAtMs: 5000000 + 120000 + 60000)]
        ..earnings = [
          {'orderId': 'e1', 'amountPesewas': 1500, 'status': 'pending', 'linkedSupplierName': 'Tema Gas'},
          {'orderId': 'e2', 'amountPesewas': 1500, 'status': 'credited_to_wallet', 'creditedAtMs': 1700000000000},
        ];
      await pumpScreen(tester, s);
      expect(find.text(feeText), findsOneWidget);
      expect(find.text('Earned · pending · Tema Gas'), findsOneWidget);
      expect(find.textContaining('Credited to wallet'), findsOneWidget);
      expect(find.textContaining('Paid'), findsNothing);

      await tester.tap(find.byKey(const Key('gsj-offer-accept-off1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pump();
      s.handedOver = true;
      await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
      await tester.tap(find.byKey(const Key('gsj-complete')));
      await tester.pump();
      expect(find.byKey(const Key('gsj-done')), findsOneWidget);
      expect(find.text('Earned GH₵15.00 · pending'), findsOneWidget);
      expect(find.textContaining('Paid'), findsNothing);
    });

    testWidgets('the home entry says a delivery offer is waiting', (tester) async {
      final s = FakeServer()..offers = [offerMap()];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GasSupplierJobsEntry(repository: repoFor(s)))));
      await tester.pump();
      expect(find.text('Delivery offer waiting'), findsOneWidget);
    });

    test('DU-06 offer pushes open the gas supplier jobs route; request pushes still open nothing', () {
      for (final type in ['GAS_SUPPLIER_RIDER_OFFER', 'GAS_SUPPLIER_RIDER_OFFER_ENDED']) {
        expect(DriverNotificationService.routeForTap({'type': type, 'orderId': 'o'}), '/gas-supplier-jobs', reason: type);
      }
      expect(DriverNotificationService.routeForTap({'type': 'NEW_GAS_REQUEST', 'route': '/x'}), isNull);
    });
  });
}
