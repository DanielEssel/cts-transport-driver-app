import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../driver/constants/driver_constants.dart';

part 'location_service.g.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

@Riverpod(keepAlive: true)
class LocationService extends _$LocationService {
  StreamSubscription<Position>? _locationSubscription;
  Timer? _throttleTimer;

  @override
  Position? build() {
    // Standard Riverpod practice: clean up on disposal
    ref.onDispose(() {
      _locationSubscription?.cancel();
      _throttleTimer?.cancel();
    });

    // We return the raw Position.
    // The UI will see this as AsyncValue<Position?> via the provider.
    return null;
  }

  /// Initialize and start tracking if permissions are already set
  Future<void> init() async {
    final hasPermission = await _checkPermissions();
    if (hasPermission) {
      startTracking();
    }
  }

  Future<bool> _checkPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      startTracking();
      return true;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }

    return false;
  }

  void startTracking() {
    _locationSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: DriverConstants.locationDistanceFilter,
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        state = position; // This updates the provider state
        _throttledFirestoreUpdate(position);
      },
      onError: (error) {
        debugPrint('Location Stream Error: $error');
      },
    );
  }

  /// Custom Throttle logic: Only updates Firestore once every 5 seconds
  void _throttledFirestoreUpdate(Position position) {
    if (_throttleTimer?.isActive ?? false) return;

    _updateLocationInFirestore(position);

    _throttleTimer = Timer(const Duration(seconds: 5), () {
      _throttleTimer = null;
    });
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'heading': position.heading, // Useful for the map icon direction
      });
    } catch (e) {
      debugPrint('Firestore Location Update Failed: $e');
    }
  }

  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    state = null;
  }
}
