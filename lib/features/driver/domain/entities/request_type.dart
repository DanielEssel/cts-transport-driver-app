import 'package:flutter/material.dart';
import 'package:cts_transport_driver_app/core/constants/app_colors.dart';

// domain/entities/request_type.dart
enum RequestType {
  ride,
  delivery,
  courier;

  String get displayName {
    switch (this) {
      case RequestType.ride:
        return 'Ride';
      case RequestType.delivery:
        return 'Delivery';
      case RequestType.courier:
        return 'Courier';
    }
  }

  Color get accentColor {
    switch (this) {
      case RequestType.ride:
        return AppColors.primaryColor;
      case RequestType.delivery:
        return const Color(0xFFFF7043);
      case RequestType.courier:
        return const Color(0xFF9C27B0);
    }
  }
}

