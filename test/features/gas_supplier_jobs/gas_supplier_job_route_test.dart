// Route, estimate, fee and navigation for Gas supplier jobs, as the server
// returns them (gas_supplier_fulfilment.js jobView): nothing is invented
// when a field is missing, and the straight-line distance is never shown as
// a road distance.
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/gas_supplier_jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> jobMap({bool route = true, Map<String, dynamic> extra = const {}}) => {
      'orderId': 'order123456', 'orderType': 'exchangeEmpty', 'cylinderSize': 'kg6', 'quantity': 1,
      'station': {'name': 'PKAB GAS', 'address': 'Station road', 'location': {'latitude': 5.68798, 'longitude': -0.55108}},
      'deliveryAddress': 'Home', 'deliveryLocation': {'latitude': 5.6547, 'longitude': -0.5814},
      'deliveryFee': 14.5, 'distanceKm': 1.3,
      if (route) ...{'routeDistanceKm': 6.24, 'routeDurationMinutes': 17, 'estimatedDeliveryAtMs': DateTime(2026, 10, 30, 14, 5).millisecondsSinceEpoch},
      ...extra,
    };

void main() {
  group('job model', () {
    test('RT-01 parses the quoted route distance, drive time and estimate', () {
      final j = GasSupplierJob.fromMap(jobMap());
      expect([j.routeDistanceKm, j.routeDurationMinutes], [6.24, 17]);
      expect(j.estimatedDeliveryAtMs, DateTime(2026, 10, 30, 14, 5).millisecondsSinceEpoch);
      expect(gasRouteSummary(j), '6.2 km by road from the station · about 17 min driving');
    });

    test('RT-02 no route from the server: no summary, no estimate, nothing guessed', () {
      final j = GasSupplierJob.fromMap(jobMap(route: false));
      expect([j.routeDistanceKm, j.routeDurationMinutes, j.estimatedDeliveryAtMs], [null, null, null]);
      expect(gasRouteSummary(j), isNull);
      // A distance without a drive time shows only the distance.
      expect(gasRouteSummary(GasSupplierJob.fromMap(jobMap(route: false, extra: {'routeDistanceKm': 3.0}))), '3.0 km by road from the station');
    });

    test('RT-03 an offer shows the fee the server checks at accept (deliveryFeePesewas), not the customer delivery fee', () {
      final o = GasSupplierJob.fromMap(jobMap(extra: {'offerSeq': 1, 'expiresAtMs': 1, 'deliveryFeePesewas': 1300}));
      expect(o.deliveryFee, 13.0);
      // An open job has no rider fee: its delivery fee is shown.
      expect(GasSupplierJob.fromMap(jobMap()).deliveryFee, 14.5);
    });
  });

  group('screens', () {
    Future<Map<String, dynamic>> server(String name, Map<String, dynamic> d) async => switch (name) {
          'gasSupplierOrderingStatus' => {'enabled': true},
          'listGasSupplierJobs' => {'jobs': [jobMap()]},
          'listMyGasSupplierJobs' => {'jobs': const []},
          'listMyGasSupplierEarnings' => {'earnings': const []},
          _ => {'ok': true},
        };

    testWidgets('RT-10 an open job labels its straight-line distance and shows the road route', (tester) async {
      await tester.pumpWidget(MaterialApp(home: GasSupplierJobsScreen(repository: GasSupplierJobRepository(call: server))));
      await tester.pumpAndSettle();
      expect(find.textContaining('1.3 km from you (straight line)'), findsOneWidget);
      expect(find.textContaining('6.2 km by road from the station · about 17 min driving'), findsOneWidget);
    });

    testWidgets('RT-11 the active job offers navigation to the station, then to the customer, and shows the estimate as an estimate', (tester) async {
      final went = <String>[];
      final job = GasSupplierJob.fromMap(jobMap());
      await tester.pumpWidget(MaterialApp(home: GasSupplierActiveJobScreen(
        job: job, repository: GasSupplierJobRepository(call: server),
        navigate: (lat, lng) async => went.add('$lat,$lng'),
      )));
      expect(find.byKey(const Key('gsj-route')), findsOneWidget);
      expect(find.textContaining('Customer was told about'), findsOneWidget);
      expect(find.textContaining('(estimate)'), findsOneWidget);
      expect(find.byKey(const Key('gsj-nav-customer')), findsNothing);
      await tester.tap(find.byKey(const Key('gsj-nav-station')));
      await tester.tap(find.byKey(const Key('gsj-arrived')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gsj-nav-customer')));
      expect(went, ['5.68798,-0.55108', '5.6547,-0.5814']);
    });

    testWidgets('RT-12 without coordinates or a route there is no navigation button and no estimate', (tester) async {
      final job = GasSupplierJob.fromMap({...jobMap(route: false), 'station': {'name': 'PKAB GAS'}, 'deliveryLocation': null});
      await tester.pumpWidget(MaterialApp(home: GasSupplierActiveJobScreen(job: job, repository: GasSupplierJobRepository(call: server),
          navigate: (lat, lng) async {})));
      expect(find.byKey(const Key('gsj-nav-station')), findsNothing);
      expect(find.byKey(const Key('gsj-route')), findsNothing);
      expect(find.textContaining('Customer was told'), findsNothing);
    });
  });
}
