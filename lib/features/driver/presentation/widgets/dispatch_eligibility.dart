import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/driver_types.dart';
import 'gas_dispatch_policy.dart';

/// UI-side mirror of the backend dispatch policy (functions/dispatch_policy.js
/// in the passenger repo, used by notification dispatch and by the
/// acceptRide / acceptDelivery / acceptGasOrder callables). It only hides
/// requests this driver could not accept; the server remains the authority.
/// Both sides run the same cases (test/fixtures/eligibility_cases.json).

/// Offer radius in km, inclusive (DISPATCH_RADIUS_KM).
const double dispatchRadiusKm = 10.0;

/// The vehicle each ride service needs.
const _rideServiceVehicle = {
  'okada': DriverVehicleType.motorbike,
  'taxi': DriverVehicleType.taxi,
  'pragyia': DriverVehicleType.pragyia,
};

/// True when the driver's vehicle is the one their ride service needs.
bool rideVehicleMatches(DriverProfile driver) =>
    _rideServiceVehicle[driver.serviceType] == driver.vehicleType;

/// The vehicle a delivery was booked on ('Okada' / 'Aboboya' / 'Mini Truck'),
/// or null for anything else.
DriverVehicleType? bookedDeliveryVehicle(String? booked) =>
    switch (booked?.trim().toLowerCase()) {
      'okada' => DriverVehicleType.motorbike,
      'aboboya' => DriverVehicleType.aboboyaa,
      'mini truck' => DriverVehicleType.miniTruck,
      _ => null,
    };

/// True when this Delivery driver may take a delivery booked on [booked]
/// for [weightTier]: the same vehicle, carrying a tier it is allowed.
bool canDriverTakeDelivery(
  DriverProfile driver,
  String? booked,
  String? weightTier,
) =>
    driver.isDelivery &&
    bookedDeliveryVehicle(booked) == driver.vehicleType &&
    driver.allowedWeightTiers.any((t) => t.label == weightTier);

// ── Full policy (dispatch_policy.js jobRejection / driverRejection) ──────────

enum DispatchService { ride, delivery, gas }

/// What eligibility reads from a request.
class DispatchJob {
  const DispatchJob({
    required this.service,
    this.serviceType,
    this.bookedVehicle,
    this.weightTier,
    this.refillType,
    this.point,
  });

  final DispatchService service;
  final String? serviceType; // ride
  final String? bookedVehicle; // delivery: 'Okada' / 'Aboboya' / 'Mini Truck'
  final String? weightTier; // delivery
  final String? refillType; // gas

  /// Where the driver goes first: the pickup, or the customer for gas.
  final GeoPoint? point;
}

/// The backend's vehicle spellings, normalised as normalizeVehicleType does
/// (gas_dispatch_policy.js); anything else is unknown (null).
String? canonicalVehicle(String? value) =>
    switch (value?.trim().toLowerCase()) {
      'motorcycle' || 'motorbike' || 'okada' => 'motorcycle',
      'tricycle' || 'aboboyaa' || 'aboboya' => 'tricycle',
      'minitruck' || 'mini_truck' || 'mini truck' => 'miniTruck',
      'pragyia' => 'pragyia',
      'taxi' => 'taxi',
      'quadricycle' => 'quadricycle',
      _ => null,
    };

const _rideVehicle = {
  'okada': 'motorcycle',
  'taxi': 'taxi',
  'pragyia': 'pragyia',
};

const _deliveryTiers = {
  'motorcycle': ['Small'],
  'tricycle': ['Medium', 'Large'],
  'miniTruck': ['Bulk'],
};

const _serviceRole = {
  DispatchService.ride: 'driver_hailing',
  DispatchService.delivery: 'driver_delivery',
  DispatchService.gas: 'driver_delivery',
};

const _gasVehicle = {
  'motorcycle': DriverVehicleType.motorbike,
  'tricycle': DriverVehicleType.aboboyaa,
  'miniTruck': DriverVehicleType.miniTruck,
};

/// A usable position: finite, in range and not the (0, 0) default.
bool validPoint(GeoPoint? p) =>
    p != null &&
    p.latitude.isFinite &&
    p.longitude.isFinite &&
    p.latitude >= -90 &&
    p.latitude <= 90 &&
    p.longitude >= -180 &&
    p.longitude <= 180 &&
    !(p.latitude == 0 && p.longitude == 0);

/// Great-circle distance in km (mean Earth radius 6371 km).
double distanceKm(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 6371 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Why no driver may take [job], or null.
String? jobRejection(DispatchJob job) {
  if (!validPoint(job.point)) return 'invalid_job_location';
  switch (job.service) {
    case DispatchService.ride:
      if (!_rideVehicle.containsKey(job.serviceType)) {
        return 'unknown_ride_service';
      }
    case DispatchService.delivery:
      final v = canonicalVehicle(job.bookedVehicle);
      if (v == null || !_deliveryTiers.containsKey(v)) {
        return 'unknown_delivery_vehicle';
      }
      if (!_deliveryTiers[v]!.contains(job.weightTier)) {
        return 'vehicle_cannot_carry_weight_tier';
      }
    case DispatchService.gas:
      break;
  }
  return null;
}

/// Why [driver] may not take [job], or null when they may.
String? driverRejection(DriverProfile driver, DispatchJob job) {
  if (!driver.isApproved || driver.signupStep == 'suspended') {
    return 'driver_not_approved';
  }
  if (!driver.isOnline || !driver.isAvailable) return 'driver_unavailable';
  if (driver.currentTripId != null) return 'driver_on_job';
  if (driver.role != _serviceRole[job.service]) return 'wrong_service';

  final vehicle = canonicalVehicle(driver.vehicleTypeRaw);
  switch (job.service) {
    case DispatchService.ride:
      if (driver.serviceType != job.serviceType) return 'wrong_ride_service';
      if (vehicle == null || vehicle != _rideVehicle[job.serviceType]) {
        return 'vehicle_not_eligible';
      }
    case DispatchService.delivery:
      if (vehicle == null || vehicle != canonicalVehicle(job.bookedVehicle)) {
        return 'vehicle_not_eligible';
      }
      if (!(_deliveryTiers[vehicle] ?? const []).contains(job.weightTier)) {
        return 'vehicle_not_eligible';
      }
    case DispatchService.gas:
      final type = _gasVehicle[vehicle];
      if (type == null || !canDriverHandleGasOrder(type, job.refillType)) {
        return 'vehicle_not_eligible';
      }
  }

  final at = driver.dispatchLocation;
  if (!validPoint(at)) return 'driver_location_invalid';
  if (!(distanceKm(at!, job.point!) <= dispatchRadiusKm)) {
    return 'outside_radius';
  }
  return null;
}

/// True when dispatch would offer [job] to [driver] and acceptance allow it.
bool driverMayTake(DriverProfile driver, DispatchJob job) =>
    jobRejection(job) == null && driverRejection(driver, job) == null;

/// Why the request list shows this driver nothing at all, whatever is
/// pending, or null. The driver-level checks of [driverRejection]; going
/// offline is handled by the caller.
String? requestListBlock(DriverProfile driver) {
  if (!driver.isApproved || driver.signupStep == 'suspended') {
    return 'Your account is not approved to take requests.';
  }
  if (driver.currentTripId != null) {
    return 'Finish your current job to see new requests.';
  }
  if (!driver.isAvailable) {
    return 'You are not available for requests. Go offline and online again.';
  }
  final vehicle = canonicalVehicle(driver.vehicleTypeRaw);
  final setUp = switch (driver.role) {
    'driver_hailing' =>
      vehicle != null && vehicle == _rideVehicle[driver.serviceType],
    'driver_delivery' => _deliveryTiers.containsKey(vehicle),
    _ => false,
  };
  if (!setUp) {
    return 'Your service or vehicle is not set up for requests. '
        'Contact support.';
  }
  if (!validPoint(driver.dispatchLocation)) {
    return 'Waiting for your location. Check that location access is on.';
  }
  return null;
}
