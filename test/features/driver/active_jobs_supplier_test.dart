// Active Jobs with Gas supplier jobs: they come only from the server
// (listMyGasSupplierJobs), appear once, open at the server's step, and every
// failure is shown rather than read as "no job". Ride, delivery and Gas
// order rows are unchanged.
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/active_jobs_screen.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/gas_supplier_jobs_screen.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/supplier_active_jobs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> own(String id, String status) => {
      'orderId': id, 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg12_5', 'quantity': 1,
      'station': {'name': 'Tema Station'}, 'deliveryAddress': 'Home', 'status': status, 'onDriverRecord': true,
    };

class Server {
  bool enabled = true;
  List<Map<String, dynamic>> mine = const [];
  GasSupplierJobFailure? mineFailure;
  final failNext = <String, GasSupplierJobFailure>{};
  final calls = <String>[];

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> d) async {
    calls.add(name);
    if (name == 'gasSupplierOrderingStatus') return {'enabled': enabled};
    final f = failNext.remove(name);
    if (f != null) throw f;
    if (name == 'listMyGasSupplierJobs') {
      if (mineFailure != null) throw mineFailure!;
      return {'jobs': mine};
    }
    return {'ok': true};
  }

  int count(String name) => calls.where((c) => c == name).length;
}

const ride = ActiveJob(id: 't1', collection: 'trips', status: 'tripStarted', from: 'Osu', to: 'Labone');
const delivery = ActiveJob(id: 'd1', collection: 'deliveries', status: 'packagePicked', from: 'Tema', to: 'Spintex');
const gasOrder = ActiveJob(id: 'g1', collection: 'gas_orders', status: 'refilling', from: 'Home', to: 'Home');
const network = GasSupplierJobFailure('unavailable', 'network', "Couldn't reach CTSGo. Check your connection and try again.");

Future<void> pumpScreen(WidgetTester tester, Server s, {List<ActiveJob> firestore = const [], Duration poll = const Duration(seconds: 60)}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreActiveJobsProvider.overrideWith((ref) => firestore),
      gasSupplierJobRepositoryProvider.overrideWithValue(GasSupplierJobRepository(call: s.call, refreshLocation: () async => true)),
      supplierJobsPollIntervalProvider.overrideWithValue(poll),
    ],
    child: const MaterialApp(home: ActiveJobsScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

const supplierRow = Key('active-job-gas_supplier_orders-o1');

void main() {
  testWidgets('feature off: no job list is asked for, nothing is added, other jobs unchanged', (tester) async {
    final s = Server()..enabled = false..mine = [own('o1', 'atStation')];
    await pumpScreen(tester, s, firestore: [ride, delivery, gasOrder]);
    expect(s.count('listMyGasSupplierJobs'), 0);
    expect(find.byKey(supplierRow), findsNothing);
    for (final k in ['active-job-trips-t1', 'active-job-deliveries-d1', 'active-job-gas_orders-g1']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsNothing);
    await done(tester);
  });

  testWidgets('feature off and no other jobs: the empty state', (tester) async {
    await pumpScreen(tester, Server()..enabled = false);
    expect(find.byKey(const Key('active-jobs-empty')), findsOneWidget);
    await done(tester);
  });

  testWidgets('a recovered supplier job is listed once, beside the other jobs, and opens at the server step', (tester) async {
    final s = Server()..mine = [own('o1', 'atStation'), own('o1', 'atStation')];
    await pumpScreen(tester, s, firestore: [ride, delivery]);
    expect(find.byKey(supplierRow), findsOneWidget);
    expect(find.text('Gas supplier job'), findsOneWidget);
    expect(find.byKey(const Key('active-job-trips-t1')), findsOneWidget);
    await tester.tap(find.byKey(supplierRow));
    await tester.pumpAndSettle();
    expect(find.byType(GasSupplierActiveJobScreen), findsOneWidget);
    expect(find.byKey(const Key('gsj-arrived')), findsNothing);
    expect(find.byKey(const Key('gsj-complete')), findsOneWidget);
    await done(tester);
  });

  testWidgets('a double tap opens the job once', (tester) async {
    final s = Server()..mine = [own('o1', 'driverAssigned')];
    await pumpScreen(tester, s);
    await tester.tap(find.byKey(supplierRow));
    await tester.tap(find.byKey(supplierRow), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(GasSupplierActiveJobScreen), findsOneWidget);
    await done(tester);
  });

  testWidgets('offline: the failed check is shown with Retry, and Retry recovers the job', (tester) async {
    final s = Server()..mineFailure = network;
    await pumpScreen(tester, s, firestore: [ride]);
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsOneWidget);
    expect(find.textContaining('connection'), findsOneWidget);
    expect(find.byKey(const Key('active-job-trips-t1')), findsOneWidget, reason: 'other jobs still show');
    s..mineFailure = null..mine = [own('o1', 'outForDelivery')];
    await tester.tap(find.byKey(const Key('active-jobs-supplier-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsNothing);
    expect(find.byKey(supplierRow), findsOneWidget);
    await done(tester);
  });

  testWidgets('permission denied is reported, not shown as no job', (tester) async {
    final s = Server()..mineFailure = GasSupplierJobFailure('permission-denied', 'not_allowed', gasSupplierJobMessage('not_allowed', ''));
    await pumpScreen(tester, s);
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsOneWidget);
    expect(find.byKey(const Key('active-jobs-empty')), findsNothing);
    await done(tester);
  });

  testWidgets('a failed refresh keeps the last known job and says the check failed', (tester) async {
    final s = Server()..mine = [own('o1', 'atStation')];
    await pumpScreen(tester, s, poll: const Duration(seconds: 1));
    s.mineFailure = network;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(supplierRow), findsOneWidget);
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsOneWidget);
    await done(tester);
  });

  testWidgets('switched off while running: the job and the error go away', (tester) async {
    final s = Server()..mine = [own('o1', 'atStation')];
    await pumpScreen(tester, s, poll: const Duration(seconds: 1));
    s.mineFailure = GasSupplierJobFailure('unavailable', 'gas_supplier_fulfilment_disabled', gasSupplierJobMessage('gas_supplier_fulfilment_disabled', ''));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(supplierRow), findsNothing);
    expect(find.byKey(const Key('active-jobs-supplier-error')), findsNothing);
    await done(tester);
  });

  testWidgets('cancelled or reassigned while open: actions stop, and the job leaves Active Jobs on return', (tester) async {
    final s = Server()..mine = [own('o1', 'driverAssigned')];
    await pumpScreen(tester, s, firestore: [ride]);
    await tester.tap(find.byKey(supplierRow));
    await tester.pumpAndSettle();
    // Meanwhile an admin cancelled it (or gave it to another driver).
    s.mine = const [];
    s.failNext['arriveGasSupplierStation'] = GasSupplierJobFailure('failed-precondition', 'invalid_transition', gasSupplierJobMessage('invalid_transition', ''));
    await tester.tap(find.byKey(const Key('gsj-arrived')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('no longer in progress for you'), findsOneWidget);
    expect(find.byKey(const Key('gsj-arrived')), findsNothing);
    final before = s.count('listMyGasSupplierJobs');
    await tester.tap(find.byKey(const Key('gsj-back')));
    await tester.pumpAndSettle();
    expect(s.count('listMyGasSupplierJobs'), greaterThan(before), reason: 'the list is asked again on return');
    expect(find.byKey(supplierRow), findsNothing);
    expect(find.byKey(const Key('active-job-trips-t1')), findsOneWidget);
    await done(tester);
  });

  test('a supplier ActiveJob takes its status and places from the server and opens the supplier job screen', () {
    final repo = GasSupplierJobRepository(call: (n, d) async => {});
    final j = ActiveJob.supplier(GasSupplierJob.fromMap(own('o1', 'outForDelivery')), repo);
    expect([j.collection, j.status, j.from, j.to, j.typeLabel], ['gas_supplier_orders', 'outForDelivery', 'Tema Station', 'Home', 'Gas supplier job']);
    expect(j.trackingScreen(), isA<SupplierJobRoute>());
    expect(ride.trackingScreen().runtimeType.toString(), 'TripFlowScreen');
  });
}
