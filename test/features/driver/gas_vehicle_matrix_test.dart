// Gas vehicle rules (business rule, 2026-10-28), mirrored from the backend
// (functions/gas_dispatch_policy.js) to hide requests a driver cannot take:
//   motorbike            standard only (exchangeEmpty, newCylinder, pickupAndReturn)
//   aboboyaa, mini truck standard and bulk (commercialBulk)
//   pragyia, taxi, quadricycle: no Gas orders
// The backend stays the authority at acceptance (functions/test/gas_vehicle_matrix.test.js).

import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/gas_dispatch_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _standard = ['exchangeEmpty', 'newCylinder', 'pickupAndReturn'];
const _all = [..._standard, 'commercialBulk'];
const _allowed = {
  DriverVehicleType.motorbike: _standard,
  DriverVehicleType.aboboyaa: _all,
  DriverVehicleType.miniTruck: _all,
  DriverVehicleType.pragyia: <String>[],
  DriverVehicleType.taxi: <String>[],
  DriverVehicleType.quadricycle: <String>[],
};

void main() {
  test('every vehicle and Gas order type combination', () {
    expect(_allowed.keys.toSet(), DriverVehicleType.values.toSet(), reason: 'a vehicle type is not covered');
    for (final entry in _allowed.entries) {
      for (final type in _all) {
        expect(canDriverHandleGasOrder(entry.key, type), entry.value.contains(type), reason: '${entry.key.name} × $type');
      }
    }
  });

  test('unknown or missing order types fail closed', () {
    for (final v in DriverVehicleType.values) {
      for (final type in [null, '', 'refill', 'bulk', 'PickupAndReturn']) {
        expect(canDriverHandleGasOrder(v, type), isFalse, reason: '${v.name} × $type');
      }
    }
  });
}
