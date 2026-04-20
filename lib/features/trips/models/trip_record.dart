// features/trips/models/trip_record.dart

import '../../driver/models/driver_type.dart';

class TripRecord {
  final String id;
  final DriverType driverType;
  final String customerName;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final double distanceKm;
  final DateTime completedAt;
  final double driverRating;
  final bool isDelivery;

  TripRecord({
    required this.id,
    required this.driverType,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.distanceKm,
    required this.completedAt,
    required this.driverRating,
    required this.isDelivery,
  });

  // Factory method to create from JSON
  factory TripRecord.fromJson(Map<String, dynamic> json) {
    return TripRecord(
      id: json['id'],
      driverType: _parseDriverType(json['driverType']),
      customerName: json['customerName'],
      pickupAddress: json['pickupAddress'],
      dropoffAddress: json['dropoffAddress'],
      fare: json['fare'].toDouble(),
      distanceKm: json['distanceKm'].toDouble(),
      completedAt: DateTime.parse(json['completedAt']),
      driverRating: json['driverRating'].toDouble(),
      isDelivery: json['isDelivery'],
    );
  }

  // Helper to parse DriverType from string - Updated to match your DriverType enum
  static DriverType _parseDriverType(String type) {
    switch (type) {
      case 'okadaHailing':
        return DriverType.okadaHailing;
      case 'okadaDelivery':
        return DriverType.okadaDelivery;
      case 'aboboya':
        return DriverType.aboboya;
      case 'miniTruck':
        return DriverType.miniTruck;
      default:
        return DriverType.okadaHailing; // Default to okadaHailing
    }
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverType': _driverTypeToString(driverType),
      'customerName': customerName,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'fare': fare,
      'distanceKm': distanceKm,
      'completedAt': completedAt.toIso8601String(),
      'driverRating': driverRating,
      'isDelivery': isDelivery,
    };
  }

  // Helper to convert DriverType to string
  static String _driverTypeToString(DriverType type) {
    switch (type) {
      case DriverType.okadaHailing:
        return 'okadaHailing';
      case DriverType.okadaDelivery:
        return 'okadaDelivery';
      case DriverType.aboboya:
        return 'aboboya';
      case DriverType.miniTruck:
        return 'miniTruck';
    }
  }
}