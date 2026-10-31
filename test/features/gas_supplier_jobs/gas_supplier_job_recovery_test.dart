// Recovering the driver's own Gas supplier job (listMyGasSupplierJobs):
// what the client keeps from the server's answer, how failures are shown,
// and how the job screen follows the server when a step is refused or lost.
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/gas_supplier_jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> own(String id, String? status) => {
      'orderId': id, 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg6', 'quantity': 1,
      'station': {'name': 'Tema Station', 'address': 'Community 1'}, 'deliveryAddress': 'Home',
      if (status != null) 'status': status, 'onDriverRecord': true,
    };

class Server {
  final calls = <String>[];
  final sent = <String, Map<String, dynamic>>{};
  /// What listMyGasSupplierJobs answers; a failure to throw instead.
  List<Object?> mine = const [];
  Object? mineFailure;
  /// Failures for the next calls of a callable, in order.
  final failNext = <String, List<GasSupplierJobFailure>>{};
  /// Run when a callable succeeds (to move the "server" state).
  final onSuccess = <String, void Function()>{};

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> d) async {
    calls.add(name);
    sent[name] = d;
    final queued = failNext[name];
    if (queued != null && queued.isNotEmpty) throw queued.removeAt(0);
    switch (name) {
      case 'listMyGasSupplierJobs':
        if (mineFailure != null) throw mineFailure!;
        return {'jobs': mine};
      case 'listGasSupplierJobs':
        return {'jobs': const []};
      case 'listMyGasSupplierEarnings':
        return {'earnings': const []};
    }
    onSuccess[name]?.call();
    return {'ok': true};
  }

  GasSupplierJobRepository repo() => GasSupplierJobRepository(call: call, refreshLocation: () async => true);
}

const network = GasSupplierJobFailure('unavailable', 'network', "Couldn't reach CTSGo. Check your connection and try again.");

Future<void> openJob(WidgetTester tester, Server s, GasSupplierJob job) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: GasSupplierActiveJobScreen(job: job, repository: s.repo())));
  await tester.pump();
}

void main() {
  group('the driver\'s own jobs', () {
    test('asks with an empty request; keeps each order once and only in a driver step', () async {
      final s = Server()
        ..mine = [
          own('a', 'driverAssigned'), own('a', 'atStation'), // duplicate order
          own('b', 'outForDelivery'),
          own('c', 'confirmed'), own('d', 'delivered'), own('e', 'cancelled'), own('f', null), // not a job in progress
          'not a map', null,
        ];
      final jobs = await s.repo().myJobs();
      expect(s.sent['listMyGasSupplierJobs'], isEmpty);
      expect([for (final j in jobs) '${j.orderId}:${j.status}'], ['a:driverAssigned', 'b:outForDelivery']);
    });

    test('myJob finds the order or says it is no longer the driver\'s', () async {
      final s = Server()..mine = [own('a', 'atStation')];
      expect((await s.repo().myJob('a'))?.status, 'atStation');
      expect(await s.repo().myJob('zzz'), isNull);
    });

    test('failures without a server reason get a plain message', () {
      expect(gasSupplierTransportReason('unavailable'), 'network');
      expect(gasSupplierTransportReason('deadline-exceeded'), 'network');
      expect(gasSupplierTransportReason('unauthenticated'), 'signed_out');
      expect(gasSupplierTransportReason('permission-denied'), 'not_allowed');
      expect(gasSupplierTransportReason('failed-precondition'), isNull);
      expect(gasSupplierJobMessage('network', 'x'), contains('connection'));
      expect(gasSupplierJobMessage('job_no_longer_yours', 'x'), contains('cancelled or reassigned'));
    });
  });

  group('jobs screen', () {
    testWidgets('a failed check for the driver\'s own job is shown, never as "none", and can be retried', (tester) async {
      final s = Server()..mineFailure = network;
      await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: s.repo())));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gsj-mine-error')), findsOneWidget);
      expect(find.textContaining('connection'), findsWidgets);
      s..mineFailure = null..mine = [own('a', 'atStation')];
      await tester.tap(find.byKey(const Key('gsj-mine-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gsj-mine-error')), findsNothing);
      expect(find.byKey(const Key('gsj-resume-a')), findsOneWidget);
    });

    testWidgets('a permission refusal is reported the same way', (tester) async {
      final s = Server()..mineFailure = GasSupplierJobFailure('permission-denied', 'not_allowed', gasSupplierJobMessage('not_allowed', ''));
      await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: s.repo())));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gsj-mine-error')), findsOneWidget);
      expect(find.text("You don't have access to this job."), findsOneWidget);
    });

    testWidgets('a double tap on Continue opens the job once', (tester) async {
      final s = Server()..mine = [own('a', 'driverAssigned')];
      await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: s.repo())));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('gsj-resume-a')));
      await tester.tap(find.byKey(const Key('gsj-resume-a')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(GasSupplierActiveJobScreen), findsOneWidget);
    });
  });

  group('job screen follows the server', () {
    testWidgets('a lost answer to "at the station" moves on to the step the server reached, without sending it twice', (tester) async {
      final s = Server()..mine = [own('a', 'atStation')];
      s.failNext['arriveGasSupplierStation'] = [network];
      await openJob(tester, s, GasSupplierJob.fromMap(own('a', 'driverAssigned')));
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gsj-arrived')), findsNothing);
      expect(find.byKey(const Key('gsj-complete')), findsOneWidget);
      expect(s.calls.where((c) => c == 'arriveGasSupplierStation').length, 1);
    });

    testWidgets('a cancelled job stops all actions and says so', (tester) async {
      final s = Server()..mine = const [];
      s.failNext['arriveGasSupplierStation'] = [GasSupplierJobFailure('failed-precondition', 'invalid_transition', gasSupplierJobMessage('invalid_transition', ''))];
      await openJob(tester, s, GasSupplierJob.fromMap(own('a', 'driverAssigned')));
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('no longer in progress for you'), findsOneWidget);
      expect(find.byKey(const Key('gsj-arrived')), findsNothing);
      expect(find.byKey(const Key('gsj-complete')), findsNothing);
      expect(find.byKey(const Key('gsj-back')), findsOneWidget);
    });

    testWidgets('a job reassigned to another driver is not acted on', (tester) async {
      final s = Server()..mine = const [];
      s.failNext['completeGasSupplierOrder'] = [GasSupplierJobFailure('not-found', 'order_not_found', gasSupplierJobMessage('order_not_found', ''))];
      await openJob(tester, s, GasSupplierJob.fromMap(own('a', 'outForDelivery')));
      await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
      await tester.tap(find.byKey(const Key('gsj-complete')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('gsj-complete')), findsNothing);
      expect(find.byKey(const Key('gsj-done')), findsNothing, reason: 'never shown as delivered when the server did not say so');
      expect(s.calls.where((c) => c == 'completeGasSupplierOrder').length, 1);
    });

    testWidgets('an early completion stays at the step with the hand-over message when the job is still the driver\'s', (tester) async {
      final s = Server()..mine = [own('a', 'atStation')];
      s.failNext['completeGasSupplierOrder'] = [GasSupplierJobFailure('failed-precondition', 'invalid_transition', gasSupplierJobMessage('invalid_transition', ''))];
      await openJob(tester, s, GasSupplierJob.fromMap(own('a', 'atStation')));
      await tester.enterText(find.byKey(const Key('gsj-code')), '4821');
      await tester.tap(find.byKey(const Key('gsj-complete')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('has not handed over'), findsOneWidget);
      expect(find.byKey(const Key('gsj-complete')), findsOneWidget);
    });

    testWidgets('when the check itself fails, the first error stays and the step can be retried', (tester) async {
      final s = Server()..mineFailure = network;
      s.failNext['arriveGasSupplierStation'] = [network];
      await openJob(tester, s, GasSupplierJob.fromMap(own('a', 'driverAssigned')));
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('connection'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pump();
      expect(find.byKey(const Key('gsj-complete')), findsOneWidget);
    });
  });
}
