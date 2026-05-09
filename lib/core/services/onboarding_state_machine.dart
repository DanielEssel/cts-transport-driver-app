// lib/core/services/onboarding_state_machine.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_routes.dart';
import '../models/signup_step.dart';

class OnboardingStateMachine {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ─────────────────────────────────────────────
  /// MAIN ENTRY: Single source of truth routing
  /// ─────────────────────────────────────────────
  static Future<String> resolve(String uid) async {
    try {
      final doc = await _db.collection('drivers').doc(uid).get();

      // 🚨 No document → force login (never assume phoneVerified)
      if (!doc.exists || doc.data() == null) {
        return AppRoutes.login;
      }

      final data = doc.data()!;

      final String? rawStep = data['signupStep'] as String?;

      // 🚨 SAFETY: If step is missing, restart onboarding safely
      if (rawStep == null || rawStep.isEmpty) {
        await _setSafeFallback(uid);
        return AppRoutes.roleSelection;
      }

      final step = SignupStep.fromString(rawStep);

      switch (step) {
        case SignupStep.phoneVerified:
          return AppRoutes.roleSelection;

        case SignupStep.roleSelected:
          return AppRoutes.driverAccountSetup;

        case SignupStep.accountSetup:
          return AppRoutes.driverVehicleSetup;

        case SignupStep.vehicleSetup:
          return AppRoutes.driverDocuments;

        case SignupStep.documentsUpload:
          return AppRoutes.driverPending;

        case SignupStep.pendingApproval:
          return AppRoutes.driverPending;

        case SignupStep.approved:
          return AppRoutes.driverShell;
      }
    } catch (e) {
      // fallback safety
      return AppRoutes.login;
    }
  }

  /// ─────────────────────────────────────────────
  /// ADVANCE STATE (ONLY WAY TO MOVE FORWARD)
  /// ─────────────────────────────────────────────
  static Future<void> setStep(String uid, SignupStep step) async {
    await _db.collection('drivers').doc(uid).update({
      'signupStep': step.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ─────────────────────────────────────────────
  /// SAFE INITIALIZATION (prevents broken states)
  /// ─────────────────────────────────────────────
  static Future<void> _setSafeFallback(String uid) async {
    await _db.collection('drivers').doc(uid).set({
      'signupStep': SignupStep.roleSelected.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

 
}