// The driver side of CTSGo pool dispatch for supplier orders: a pool-job push
// opens the supplier jobs screen, and listing or accepting a pool job first
// tries to write a fresh position (the server measures the pool radius from
// the station and checks the position's age), without ever blocking the call.
import 'package:cts_transport_driver_app/features/driver/services/driver_notification_service.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PD-01 a supplier pool-job push opens the gas supplier jobs screen', () {
    expect(DriverNotificationService.routeForTap({'type': 'GAS_SUPPLIER_POOL_JOB', 'orderId': 'o'}), '/gas-supplier-jobs');
  });

  group('position refresh before pool listing and accept', () {
    late List<String> order;
    Future<Map<String, dynamic>> server(String name, Map<String, dynamic> d) async {
      order.add(name);
      return name == 'listGasSupplierJobs' ? {'jobs': const []} : {'ok': true};
    }

    setUp(() => order = []);

    test('PD-02 listing and a pool accept refresh first', () async {
      final repo = GasSupplierJobRepository(call: server, refreshLocation: () async { order.add('location'); return true; });
      await repo.openJobs();
      await repo.accept('o1');
      expect(order, ['location', 'listGasSupplierJobs', 'location', 'acceptGasSupplierJob']);
    });

    test('PD-03 no fix, or a failing refresh, still lets the server decide (pool only)', () async {
      for (final refresh in <Future<bool> Function()>[() async => false, () async => throw Exception('no GPS')]) {
        order.clear();
        final repo = GasSupplierJobRepository(call: server, refreshLocation: refresh);
        await repo.openJobs();
        await repo.accept('o1');
        expect(order, ['listGasSupplierJobs', 'acceptGasSupplierJob']);
      }
      // An offer still needs a fix, as before.
      order.clear();
      final strict = GasSupplierJobRepository(call: server, refreshLocation: () async => false);
      await expectLater(strict.accept('o1', offerSeq: 1), throwsA(isA<GasSupplierJobFailure>()));
      expect(order, isEmpty);
    });
  });

  test('PD-04 a station without coordinates is explained to the driver', () {
    expect(gasSupplierJobMessage('station_location_invalid', 'x'), "This job's station is not available right now.");
  });
}
