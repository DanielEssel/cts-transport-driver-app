// lib/core/services/app_flow_resolver.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';

// ─────────────────────────────────────────────────────────────
// Route destination wrapper
// ─────────────────────────────────────────────────────────────

class RouteDestination {
  final String route;
  final Object? arguments;
  const RouteDestination(this.route, {this.arguments});
}

// ─────────────────────────────────────────────────────────────
// AppFlowResolver
// ─────────────────────────────────────────────────────────────

class AppFlowResolver {

  // ── Public entry point ─────────────────────────────────────

  static Future<RouteDestination> resolveDestination(String uid) async {
    try {
      final data = await _fetchDriverData(uid);

      // No document → sign out and send to login
      if (data == null) {
        await FirebaseAuth.instance.signOut();
        return const RouteDestination(AppRoutes.login);
      }

      return _resolveFromData(uid, data);

    } on FirebaseException catch (e) {
      debugPrint('❌ AppFlowResolver Firebase error [${e.code}]: ${e.message}');

      if (e.code == 'permission-denied') {
        // Rules not yet propagated — fail safe, retry on next launch
        return const RouteDestination(AppRoutes.login);
      }

      return const RouteDestination(AppRoutes.login);

    } catch (e) {
      debugPrint('❌ AppFlowResolver unexpected error: $e');
      return const RouteDestination(AppRoutes.login);
    }
  }

  /// Convenience method for callers that only need the route string.
  static Future<String> resolveRoute(String uid) async {
    final dest = await resolveDestination(uid);
    return dest.route;
  }

  static Future<bool> isFullyOnboarded(String uid) async {
    final data = await _fetchDriverData(uid);
    if (data == null) return false;
    return data['role'] != null &&
        data['accountSetupComplete'] == true &&
        data['vehicleSetupComplete'] == true &&
        data['documentsUploaded']    == true &&
        data['isApproved']           == true;
  }

  // ── Internal helpers ───────────────────────────────────────

  static Future<Map<String, dynamic>?> _fetchDriverData(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// Pure routing logic — no async, no side effects.
  /// Each step is checked in order; first unmet step wins.
  static RouteDestination _resolveFromData(
    String uid,
    Map<String, dynamic> data,
  ) {
    final String? role        = data['role'] as String?;
    final bool accountSetup   = data['accountSetupComplete'] == true;
    final bool vehicleSetup   = data['vehicleSetupComplete'] == true;
    final bool docsUploaded   = data['documentsUploaded']    == true;
    final bool isApproved     = data['isApproved']           == true;

    // ── Step 1: Role selection ────────────────────────────────
    if (role == null || role.isEmpty) {
      return const RouteDestination(AppRoutes.roleSelection);
    }

    // ── Step 2: Account / phone setup ────────────────────────
    if (!accountSetup || data['signupStep'] == 'phoneVerified') {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      return RouteDestination(
        AppRoutes.driverPhone,
        arguments: {'phone': phone, 'role': role},
      );
    }

    // ── Step 3: Vehicle setup ─────────────────────────────────
    if (!vehicleSetup) {
      return const RouteDestination(AppRoutes.driverVehicleSetup);
    }

    // ── Step 4: Document upload ───────────────────────────────
    if (!docsUploaded) {
      return const RouteDestination(AppRoutes.driverDocuments);
    }

    // ── Step 5: Awaiting admin approval ──────────────────────
    if (!isApproved) {
      return const RouteDestination(AppRoutes.driverPending);
    }

    // ── Step 6: Fully onboarded → shell ──────────────────────
    final profile = _buildProfile(uid, data);
    return RouteDestination(AppRoutes.driverShell, arguments: profile);
  }

  // ── Profile builder ────────────────────────────────────────

  static DriverProfile _buildProfile(
    String uid,
    Map<String, dynamic> data,
  ) {
    return DriverProfile.fromFirestore(data, uid);
  }

}