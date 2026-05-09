// ─── domain/usecases/toggle_online_status.dart ───────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class ToggleOnlineStatus {
  final DriverRepository repository;

  const ToggleOnlineStatus(this.repository);

  Future<void> call({
    required String driverId,
    required bool isOnline,
    GeoPoint? location,
  }) async {
    try {
      await repository.setOnlineStatus(
        driverId: driverId,
        isOnline: isOnline,
        location: location,
      );
    } on DriverFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw FirebaseFailure(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}


