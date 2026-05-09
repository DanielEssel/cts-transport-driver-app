// lib/core/models/signup_step.dart

enum SignupStep {
  phoneVerified,
  roleSelected,
  accountSetup,
  vehicleSetup,
  documentsUpload,
  pendingApproval,
  approved;

  String get value => name;

  static SignupStep fromString(String value) {
    return SignupStep.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SignupStep.phoneVerified,
    );
  }
}