// lib/core/services/app_flow_resolver.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart'; // ✅

/// Holds a route string + optional typed argument.0
class RouteDestination {
  final String route;
  final Object? arguments;
  const RouteDestination(this.route, {this.arguments});
}

// lib/core/services/app_flow_resolver.dart

class AppFlowResolver {
  static Future<RouteDestination> resolveDestination(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await FirebaseAuth.instance.signOut();
        return const RouteDestination(AppRoutes.login);
      }

      final data = doc.data()!;
      final String? role = data['role'] as String?;
      final String? vehicleStr = data['vehicleType'] as String?;
      final bool accountSetup = (data['accountSetupComplete'] ?? false) == true;
      final bool vehicleSetup = (data['vehicleSetupComplete'] ?? false) == true;
      final bool docsUploaded = (data['documentsUploaded'] ?? false) == true;
      final bool isApproved = (data['isApproved'] ?? false) == true;

      // ── STEP 1: Role Selection ──
      if (role == null || role.isEmpty) {
        return const RouteDestination(AppRoutes.roleSelection);
      }

      // ── STEP 2: Phone/Account Setup ──
      if (data['signupStep'] == 'phoneVerified' || !accountSetup) {
        final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
        return RouteDestination(
          AppRoutes.driverPhone,
          arguments: {'phone': phone, 'role': role},
        );
      }

      // ── STEP 3: Vehicle Setup ──
      if (!vehicleSetup) {
        return const RouteDestination(AppRoutes.driverVehicleSetup);
      }

      // ── STEP 4: Documents ──
      if (!docsUploaded) {
        // Updated: Passing 'uid' to build the profile for the document screen
        final profile = DriverProfile.fromFirestore(data, uid);
return RouteDestination(AppRoutes.driverShell, arguments: profile);
      }

      // ── STEP 5: Pending Approval ──
      if (!isApproved) {
        return const RouteDestination(AppRoutes.driverPending);
      }

      // ── STEP 6: Fully Onboarded ──
      // Updated: Passing 'uid' to the final driver shell
      final profile = DriverProfile.fromFirestore(data, uid);
return RouteDestination(AppRoutes.driverShell, arguments: profile);
      
    } catch (e) {
      debugPrint('❌ AppFlowResolver error: $e');
      return const RouteDestination(AppRoutes.login);
    }
  }

  // ── Legacy string-only method ────────────────────────────────────────────────
  static Future<String> resolveRoute(String uid) async {
    final dest = await resolveDestination(uid);
    return dest.route;
  }

  // ✅ Fix — pass the full data map through
static DriverProfile _buildProfile(
  String uid,
  Map<String, dynamic> data, // ← pass full Firestore data
) {
  return DriverProfile(
    uid: uid,
    displayName: data['displayName'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    isApproved: (data['isApproved'] ?? false) == true,
    service: _serviceFromRole(data['role'] as String?),
    vehicleType: _vehicleFromString(data['vehicleType'] as String?),
    documents: Map<String, dynamic>.from(data['documents'] ?? {}),
  );
}

  static DriverServiceType _serviceFromRole(String? role) {
    switch (role) {
      case 'driver_delivery':
        return DriverServiceType.delivery;
      case 'driver_hailing':
      default:
        return DriverServiceType.ride;
    }
  }

  static DriverVehicleType _vehicleFromString(String? v) {
    switch (v) {
      case 'tricycle':
        return DriverVehicleType.pragyia;
      case 'quadricycle':
        return DriverVehicleType.quadricycle;
      case 'miniTruck':
        return DriverVehicleType.miniTruck;
      case 'aboboyaa':
        return DriverVehicleType.aboboyaa;
      case 'motorcycle':
      default:
        return DriverVehicleType.motorbike;
    }
  }

  static Future<bool> isFullyOnboarded(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();
    if (!doc.exists) return false;
    final d = doc.data()!;
    return d['role'] != null &&
        d['accountSetupComplete'] == true &&
        d['vehicleSetupComplete'] == true &&
        d['documentsUploaded'] == true &&
        d['isApproved'] == true;
  }

  static Future<Map<String, dynamic>?> getDriverData(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();
    return doc.exists ? doc.data() : null;
  }
}