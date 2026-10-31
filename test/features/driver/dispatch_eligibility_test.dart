// The request list shows a driver only what the backend would let them
// claim: rides of their own service on the matching vehicle, deliveries
// booked on their vehicle for a tier it carries, and gas their vehicle can
// handle. New-request taps never deep-link into a job.

import 'package:cts_transport_driver_app/core/services/driver_profile_defaults.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/dispatch_eligibility.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/gas_dispatch_policy.dart';
import 'package:cts_transport_driver_app/features/driver/services/driver_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

DriverProfile _driver(String role, String? vehicle, {String? serviceType}) =>
    DriverProfile.fromFirestore({
      'role': role,
      'vehicleType': vehicle,
      'serviceType': serviceType,
    }, 'd1');

void main() {
  group('rides', () {
    test('each ride service needs its own vehicle (setup and older spellings)', () {
      expect(rideVehicleMatches(_driver('driver_hailing', 'motorcycle', serviceType: 'okada')), isTrue);
      expect(rideVehicleMatches(_driver('driver_hailing', 'motorbike', serviceType: 'okada')), isTrue);
      expect(rideVehicleMatches(_driver('driver_hailing', 'taxi', serviceType: 'taxi')), isTrue);
      expect(rideVehicleMatches(_driver('driver_hailing', 'pragyia', serviceType: 'pragyia')), isTrue);
    });

    test('a Pragyia registered as Taxi, or no service, shows no rides', () {
      expect(rideVehicleMatches(_driver('driver_hailing', 'pragyia', serviceType: 'taxi')), isFalse);
      expect(rideVehicleMatches(_driver('driver_hailing', 'taxi')), isFalse);
    });
  });

  group('deliveries', () {
    final bike = _driver('driver_delivery', 'motorcycle');
    final trike = _driver('driver_delivery', 'tricycle');
    final truck = _driver('driver_delivery', 'miniTruck');

    test('a delivery is shown only to the booked vehicle, for tiers it carries', () {
      expect(canDriverTakeDelivery(bike, 'Okada', 'Small'), isTrue);
      expect(canDriverTakeDelivery(trike, 'Aboboya', 'Medium'), isTrue);
      expect(canDriverTakeDelivery(trike, 'Aboboya', 'Large'), isTrue);
      expect(canDriverTakeDelivery(truck, 'Mini Truck', 'Bulk'), isTrue);

      expect(canDriverTakeDelivery(trike, 'Okada', 'Small'), isFalse);
      expect(canDriverTakeDelivery(truck, 'Aboboya', 'Large'), isFalse);
      expect(canDriverTakeDelivery(bike, 'Okada', 'Medium'), isFalse,
          reason: 'Medium is beyond an Okada');
      expect(canDriverTakeDelivery(truck, 'Mini Truck', 'Small'), isFalse);
      expect(canDriverTakeDelivery(bike, null, 'Small'), isFalse);
    });

    test('a Ride driver never sees deliveries, whatever the vehicle', () {
      final rideBike = _driver('driver_hailing', 'motorcycle', serviceType: 'okada');
      expect(rideBike.allowedWeightTiers, isEmpty);
      expect(canDriverTakeDelivery(rideBike, 'Okada', 'Small'), isFalse);
    });

    test('tiers per vehicle; a non-delivery vehicle carries none (no unfiltered list)', () {
      expect(bike.allowedWeightTiers, [WeightTier.small]);
      expect(trike.allowedWeightTiers, [WeightTier.medium, WeightTier.large]);
      expect(truck.allowedWeightTiers, [WeightTier.bulk]);
      expect(_driver('driver_delivery', 'taxi').allowedWeightTiers, isEmpty);
    });
  });

  test('gas: all three delivery vehicles take everyday refills; ride vehicles none', () {
    for (final v in [DriverVehicleType.motorbike, DriverVehicleType.aboboyaa,
        DriverVehicleType.miniTruck]) {
      expect(canDriverHandleGasOrder(v, 'newCylinder'), isTrue, reason: v.name);
      expect(canDriverHandleGasOrder(v, 'exchangeEmpty'), isTrue, reason: v.name);
    }
    for (final v in [DriverVehicleType.taxi, DriverVehicleType.pragyia]) {
      expect(canDriverHandleGasOrder(v, 'newCylinder'), isFalse, reason: v.name);
    }
  });

  test('a new driver has no placeholder service', () {
    expect(newDriverDefaults('u', '+233000000000')['serviceType'], isNull);
  });

  group('notification taps', () {
    test('new-request pushes open the app, never a job route', () {
      for (final type in ['NEW_RIDE_REQUEST', 'NEW_DELIVERY_REQUEST', 'NEW_GAS_REQUEST']) {
        expect(DriverNotificationService.routeForTap(
            {'type': type, 'route': '/driver/active-gas?orderId=g1'}), isNull, reason: type);
      }
    });

    test('gas supplier offer pushes open the offers screen', () {
      for (final type in ['GAS_SUPPLIER_RIDER_OFFER', 'GAS_SUPPLIER_RIDER_OFFER_ENDED']) {
        expect(DriverNotificationService.routeForTap({'type': type, 'orderId': 'o'}), '/gas-supplier-jobs', reason: type);
      }
    });

    test('other notifications keep their route', () {
      expect(DriverNotificationService.routeForTap({'type': 'account_approved', 'route': '/x'}), '/x');
      expect(DriverNotificationService.routeForTap({'type': 'x', 'route': ''}), isNull);
      expect(DriverNotificationService.routeForTap({'type': 'x'}), isNull);
    });
  });
}
