import '../../models/driver_types.dart';

/// UI-side mirror of the authoritative backend gas dispatch policy.
///
/// IMPORTANT:
/// This is only for hiding gas requests the driver cannot handle.
/// The Cloud Function remains the authoritative acceptance/security check.
bool canDriverHandleGasOrder(
  DriverVehicleType vehicleType,
  String? refillType,
) {
  if (refillType == null) return false;

  switch (vehicleType) {
    case DriverVehicleType.motorbike:
      return {
        'exchangeEmpty',
        'newCylinder',
        'pickupAndReturn',
      }.contains(refillType);

    case DriverVehicleType.aboboyaa:
      return {
        'exchangeEmpty',
        'newCylinder',
        'commercialBulk',
      }.contains(refillType);

    case DriverVehicleType.miniTruck:
      return {
        'exchangeEmpty',
        'newCylinder',
        'commercialBulk',
      }.contains(refillType);

    case DriverVehicleType.pragyia:
    case DriverVehicleType.taxi:
    case DriverVehicleType.quadricycle:
      return false;
  }
}
