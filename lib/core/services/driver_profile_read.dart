// lib/core/services/driver_profile_read.dart
//
// AUTH-05: how AppFlowResolver reads drivers/{uid}.
//
// Right after sign-in the local cache can hold only the push-token write
// (no role, no onboarding fields). Routing on that copy sent returning
// drivers to role selection. So: read the server copy first; offline, a
// cached copy may be used only when it carries a role; and "no profile" is
// believed only when the server says so.

import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverProfileStatus {
  /// Usable profile (from the server, or a cached copy that has a role).
  usable,

  /// The server says drivers/{uid} does not exist.
  notRegistered,

  /// Only a cached copy was available, and it is missing or has no role.
  /// Never route on it and never treat it as "no account".
  unverified,
}

DriverProfileStatus classifyDriverProfile({
  required bool exists,
  required Map<String, dynamic>? data,
  required bool fromServer,
}) {
  if (fromServer) {
    return exists && data != null
        ? DriverProfileStatus.usable
        : DriverProfileStatus.notRegistered;
  }
  final role = data?['role'];
  final hasRole = exists && role is String && role.isNotEmpty;
  return hasRole ? DriverProfileStatus.usable : DriverProfileStatus.unverified;
}

class DriverProfileRead {
  const DriverProfileRead(this.status, this.data);

  final DriverProfileStatus status;
  final Map<String, dynamic>? data;
}

/// Server first; on failure (offline, timeout) falls back to the cache.
/// Throws only if neither copy can be read.
Future<DriverProfileRead> readDriverProfile(
  DocumentReference<Map<String, dynamic>> ref, {
  Duration serverTimeout = const Duration(seconds: 10),
}) async {
  DocumentSnapshot<Map<String, dynamic>> snap;
  bool fromServer;
  try {
    snap = await ref
        .get(const GetOptions(source: Source.server))
        .timeout(serverTimeout);
    fromServer = true;
  } catch (_) {
    snap = await ref.get(const GetOptions(source: Source.cache));
    fromServer = false;
  }
  return DriverProfileRead(
    classifyDriverProfile(
      exists: snap.exists,
      data: snap.data(),
      fromServer: fromServer,
    ),
    snap.data(),
  );
}
