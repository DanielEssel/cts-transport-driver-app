// lib/core/services/driver_profile_defaults.dart
//
// Defaults for a new drivers/{uid}, and the subset that may be added to an
// existing doc (for example a token-only doc left by older app versions,
// AUTH-03). Existing fields are never overwritten, and only fields the
// drivers owner allow-list in firestore.rules permits are added: never
// isApproved, uid or createdAt (a missing isApproved already means "not
// approved" everywhere).

Map<String, Object?> newDriverDefaults(String uid, String phone) => {
      'uid': uid,
      'phone': phone,
      'role': null,
      'displayName': null,
      'email': null,
      'photoUrl': null,
      'accountSetupComplete': false,
      'vehicleSetupComplete': false,
      'documentsUploaded': false,
      'isApproved': false,
      'isOnline': false,
      'isAvailable': false,
      // Set by vehicle setup. No default: a placeholder 'taxi' made an
      // unconfigured driver look like a Taxi driver.
      'serviceType': null,
      'location': null,
    };

const _ownerWritableDefaults = {
  'phone',
  'role',
  'displayName',
  'email',
  'photoUrl',
  'accountSetupComplete',
  'vehicleSetupComplete',
  'documentsUploaded',
  'isOnline',
  'isAvailable',
  'serviceType',
  'location',
};

/// Defaults missing from [existing] that the driver may add themselves.
Map<String, Object?> missingOwnerDefaults(
  Map<String, dynamic> existing,
  String uid,
  String phone,
) {
  final defaults = newDriverDefaults(uid, phone);
  return {
    for (final key in _ownerWritableDefaults)
      if (!existing.containsKey(key)) key: defaults[key],
  };
}
