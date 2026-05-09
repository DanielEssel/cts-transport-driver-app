// core/providers/online_status_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../features/driver/domain/failures/driver_failures.dart';
import '../../../../features/driver/domain/usecases/toggle_online_status_provider.dart.dart';
import '../../services/location_service.dart';

part 'online_status_provider.g.dart';

@riverpod
class OnlineStatus extends _$OnlineStatus {
  @override
  Future<bool> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return false;
  }

  Future<void> toggle() async {
    // Capture before setting loading
    final currentStatus = state.valueOrNull ?? false;
    final newStatus = !currentStatus;

    state = const AsyncLoading();

    try {
      GeoPoint? location;

      // Only fetch location when going online
      if (newStatus) {
        location = await _fetchCurrentLocation();
        if (location == null) return; // state already set to error inside
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = AsyncError(
          Exception('User not authenticated'),
          StackTrace.current,
        );
        return;
      }

      final toggleOnlineStatus = ref.read(toggleOnlineStatusProvider);

      await toggleOnlineStatus(
        driverId: user.uid,
        isOnline: newStatus,
        location: location,
      );

      state = AsyncData(newStatus);
      _handleStatusChange(newStatus);
    } on DriverFailure catch (e) {
      state = AsyncError(e, StackTrace.current);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Fetch one-shot position using Geolocator directly ─────────────────────
  // LocationService only exposes a stream — use Geolocator for single fetch.
  Future<GeoPoint?> _fetchCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      return GeoPoint(position.latitude, position.longitude);
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  // ── Start/stop stream tracking via LocationService notifier ───────────────
  void _handleStatusChange(bool isOnline) {
    final notifier = ref.read(locationServiceProvider.notifier);
    if (isOnline) {
      notifier.startTracking();
    } else {
      notifier.stopTracking();
    }
  }
}