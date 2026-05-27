// lib/core/utils/vehicle_icons.dart

import 'package:flutter/material.dart';
import '../../features/driver/models/driver_types.dart';

/// Returns icon for driver service
IconData vehicleIcon(DriverServiceType service) {
  switch (service) {
    case DriverServiceType.ride:
      return Icons.local_taxi_rounded;

    case DriverServiceType.delivery:
      return Icons.delivery_dining_rounded;
  }
}

/// Returns marker asset for vehicle type
String vehicleMarkerAsset(DriverVehicleType vehicleType) {
  switch (vehicleType) {
    case DriverVehicleType.motorbike:
      return 'assets/icons/motorcycle_marker.png';

    case DriverVehicleType.aboboyaa:
      return 'assets/icons/aboboyaa_marker.png';

    case DriverVehicleType.miniTruck:
      return 'assets/icons/truck_marker.png';

    case DriverVehicleType.pragyia:
      return 'assets/icons/pragyia_marker.png';

    case DriverVehicleType.taxi:
      return 'assets/icons/car_marker.png';

    case DriverVehicleType.quadricycle:
      return 'assets/icons/quadricycle_marker.png';
  }
}

/// Human readable label
String vehicleLabel(DriverVehicleType vehicleType) {
  return vehicleType.label;
}

/// Vehicle color
Color vehicleColor(DriverVehicleType vehicleType) {
  switch (vehicleType) {
    case DriverVehicleType.motorbike:
      return const Color(0xFF16A34A);

    case DriverVehicleType.aboboyaa:
      return const Color(0xFFD97706);

    case DriverVehicleType.miniTruck:
      return const Color(0xFF2563EB);

    case DriverVehicleType.pragyia:
      return const Color(0xFF7C3AED);

    case DriverVehicleType.taxi:
      return const Color(0xFF0EA5E9);

    case DriverVehicleType.quadricycle:
      return const Color(0xFFDC2626);
  }
}