// lib/features/trips/presentation/accepted_trip_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/route_service.dart';
import '../models/trip_model.dart';
import '../widgets/trip_map.dart';
import '../widgets/trip_passenger_card.dart';
import '../widgets/trip_status_bar.dart';
import '../widgets/trip_action_button.dart';
import '../widgets/trip_cancel_button.dart';
import '../widgets/trip_metadata_chips.dart';
import '../widgets/navigation_button.dart';

class AcceptedTripScreen extends StatefulWidget {
  final String tripId;
  final TripModel trip;

  const AcceptedTripScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  State<AcceptedTripScreen> createState() => _AcceptedTripScreenState();
}

class _AcceptedTripScreenState extends State<AcceptedTripScreen>
    with WidgetsBindingObserver {
  // ── State ─────────────────────────────────────
  late TripModel _trip;
  bool _isLoading = true;
  String _eta = 'Calculating...';
  double _distKm = 0;

  String _passengerName = 'Passenger';
  String? _passengerPhone;
  String? _passengerPhotoUrl;
  double _passengerRating = 0.0;

  // ── Button states ──────────────────────────────
  bool _isArriving = false;
  bool _isCancelling = false;
  bool _hasFirstGpsFix = false;

  // ── Map ───────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng _driverPos = const LatLng(5.6037, -0.1870);
  late LatLng _pickupPos;
  late LatLng _dropoffPos;
  double _driverHeading = 0;
  bool _mapReady = false;

  final _routeService = RouteService();
  Set<Polyline> _routePolyline = {};

  // ── Subscriptions ──────────────────────────────
  StreamSubscription<Position>? _gpsSub;
  Timer? _locationThrottle;
  Timer? _routeRefreshThrottle;

  // ── Firebase ──────────────────────────────────
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trip = widget.trip;
    _pickupPos = LatLng(
      _trip.pickupLocation.latitude,
      _trip.pickupLocation.longitude,
    );
    _dropoffPos = LatLng(
      _trip.dropoffLocation.latitude,
      _trip.dropoffLocation.longitude,
    );
    _loadPassengerInfo();
    _startGps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _gpsSub?.pause();
    if (state == AppLifecycleState.resumed) _gpsSub?.resume();
  }

  Future<void> _loadPassengerInfo() async {
    try {
      final tripDoc = await _db.collection('trips').doc(widget.tripId).get();

      if (!tripDoc.exists || !mounted) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final data = tripDoc.data() as Map<String, dynamic>;

      final embeddedName = data['passengerName'] as String? ?? '';
      final embeddedPhoto = data['passengerPhotoUrl'] as String?;
      final embeddedRating =
          (data['passengerRating'] as num?)?.toDouble() ?? 0.0;
      final embeddedPhone = data['passengerPhone'] as String? ?? '';

      if (embeddedName.isNotEmpty ||
          embeddedPhoto != null ||
          embeddedPhone.isNotEmpty) {
        setState(() {
          _passengerName = embeddedName.isEmpty ? 'Passenger' : embeddedName;
          _passengerPhotoUrl = embeddedPhoto;
          _passengerRating = embeddedRating;
          _passengerPhone = embeddedPhone.isEmpty ? null : embeddedPhone;
        });
      } else if (_trip.passengerId.isNotEmpty) {
        final userDoc =
            await _db.collection('users').doc(_trip.passengerId).get();

        if (userDoc.exists && mounted) {
          final ud = userDoc.data()!;

          final firstName = ud['firstName'] as String? ?? '';
          final lastName = ud['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();

          final photoUrl = ud['photoURL'] as String?;

          final ratingTotal = (ud['ratingTotal'] as num?)?.toDouble() ?? 0;

          final ratingCount = (ud['ratingCount'] as num?)?.toInt() ?? 0;

          setState(() {
            _passengerName = fullName.isEmpty ? 'Passenger' : fullName;
            _passengerPhotoUrl = photoUrl;
            _passengerRating =
                ratingCount > 0 ? ratingTotal / ratingCount : 5.0;
            _passengerPhone = ud['phoneNumber'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Could not fetch passenger profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startGps() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _snack(
          'Location permission denied. Enable it in Settings.',
          isError: true,
        );
      }
      return;
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _snack('Location permission is required.', isError: true);
      }
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _snack('Please enable location services.', isError: true);
      }
      return;
    }

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(
      (pos) {
        if (!mounted) return;

        setState(() {
          _driverPos = LatLng(pos.latitude, pos.longitude);
          if (pos.heading >= 0) {
            _driverHeading = pos.heading;
          }
        });

        _throttledLocationUpdate(pos);

        if (!_hasFirstGpsFix) {
          _hasFirstGpsFix = true;
          _fetchRoute();
        }

        if (!(_routeRefreshThrottle?.isActive ?? false)) {
          _routeRefreshThrottle = Timer(
            const Duration(seconds: 20),
            () {
              if (mounted) _fetchRoute();
            },
          );
        }
      },
      onError: (e) {
        debugPrint('❌ GPS stream error: $e');
      },
    );
  }

  void _throttledLocationUpdate(Position pos) {
    if (_locationThrottle?.isActive ?? false) return;
    _locationThrottle = Timer(const Duration(seconds: 5), () {
      _writeLocation(pos);
    });
  }

  Future<void> _writeLocation(Position pos) async {
    if (_uid.isEmpty) return;
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'driverCurrentLocation': GeoPoint(pos.latitude, pos.longitude),
        'driverHeading': pos.heading,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _fetchRoute() async {
    try {
      final result = await _routeService.getRoute(
        _driverPos,
        _pickupPos,
      );

      if (!mounted) return;
      if (result == null || result.points.isEmpty) return;

      setState(() {
        _routePolyline = {
          Polyline(
            polylineId: const PolylineId('accepted_trip_route'),
            points: result.points,
            color: const Color(0xFF16A34A),
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        };

        _distKm = result.distanceKm;
        _eta =
            result.durationMin <= 1 ? '< 1 min' : '${result.durationMin} min';
      });

      if (_mapReady) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _fitBounds();
        });
      }
    } catch (e) {
      debugPrint('❌ _fetchRoute failed: $e');
    }
  }

  Future<void> _handleArrived() async {
    if (_isArriving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isArriving = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status': 'driverArrived',
        'arrivedAt': FieldValue.serverTimestamp(),
      });
      _snack('Marked as arrived ✓', isSuccess: true);
    } catch (_) {
      _snack('Failed to update status. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isArriving = false);
    }
  }

  Future<void> _handleCancelTrip() async {
    if (_isCancelling) return;

    final confirmed = await _showConfirmDialog(
      title: 'Cancel Trip?',
      content: 'Cancelling after accepting may affect your acceptance rate.',
      confirm: 'Cancel Trip',
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await _db.runTransaction((txn) async {
        final tripRef = _db.collection('trips').doc(widget.tripId);
        final driverRef = _db.collection('drivers').doc(_uid);
        txn.update(tripRef, {
          'status': 'cancelledByDriver',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        txn.update(driverRef, {
          'isAvailable': true,
          'currentTripId': FieldValue.delete(),
        });
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _isCancelling = false);
        _snack('Failed to cancel. Try again.', isError: true);
      }
    }
  }

  Future<void> _callPassenger() async {
    String? phone = _passengerPhone;
    if ((phone == null || phone.isEmpty) && _trip.passengerId.isNotEmpty) {
      try {
        final doc = await _db.collection('users').doc(_trip.passengerId).get();
        phone = doc.data()?['phoneNumber'] as String?;
      } catch (_) {}
    }
    if (phone == null || phone.isEmpty) {
      _snack('Passenger phone not available.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirm,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            content,
            style: TextStyle(color: Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              child: Text(confirm),
            ),
          ],
        ),
      );

  void _snack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isSuccess
              ? const Color(0xFF16A34A)
              : isError
                  ? Colors.red[700]
                  : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _locationThrottle?.cancel();
    _routeRefreshThrottle?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF9),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Column(
        children: [
          // ── Map ──
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                TripMap(
                  controller: _mapController,
                  onMapCreated: (c) {
                    _mapController = c;
                    setState(() => _mapReady = true);

                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted) _fitBounds();
                    });
                  },
                  driverPos: _driverPos,
                  pickupPos: _pickupPos,
                  dropoffPos: _dropoffPos,
                  driverHeading: _driverHeading,
                  serviceType: _trip.serviceType,
                  polylines: _routePolyline,

                  // Accepted phase = Driver → Pickup.
                  showPickup: true,
                  showDropoff: false,
                  showDriver: true,
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: _MapButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                // Recenter button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 16,
                  child: _MapButton(
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFF16A34A),
                    onTap: () => _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_driverPos, 16),
                    ),
                  ),
                ),
                // Status pill
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TripStatusBar(
                    status: TripStatus.tripAccepted,
                    eta: _eta,
                  ),
                ),
              ],
            ),
          ),
          // ── Bottom panel ──
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHandle(),
                    TripPassengerCard(
                      name: _passengerName,
                      photoUrl: _passengerPhotoUrl,
                      rating: _passengerRating,
                      phone: _passengerPhone,
                      onCall: _callPassenger,
                    ),
                    const _Divider(),
                    _buildRouteRow(),
                    const _Divider(),
                    TripMetadataChips(
                      eta: _eta,
                      distanceKm: _distKm,
                      fare: _trip.finalFare ?? _trip.fare,
                    ),
                    const SizedBox(height: 20),
                    NavigationButton(
                      label: 'Navigate to Pickup',
                      destination: _pickupPos,
                    ),
                    const SizedBox(height: 10),
                    TripActionButton(
                      label: "I've Arrived at Pickup",
                      icon: Icons.location_on_rounded,
                      color: Colors.green,
                      isLoading: _isArriving,
                      onTap: _handleArrived,
                    ),
                    const SizedBox(height: 10),
                    TripCancelButton(
                      isLoading: _isCancelling,
                      onTap: _handleCancelTrip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildRouteRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2.5),
              ),
            ),
            Container(width: 2, height: 28, color: Colors.grey[200]),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pickup',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _trip.pickupAddress,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Text(
                'Drop-off',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _trip.dropoffAddress,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fitBounds() {
    if (!_mapReady || _mapController == null) return;

    // Accepted-trip phase:
    // Only show the driver's current position and the pickup.
    final points = <LatLng>[
      _driverPos,
      _pickupPos,
    ];

    final minLat = points.map((p) => p.latitude).reduce(min);
    final maxLat = points.map((p) => p.latitude).reduce(max);
    final minLng = points.map((p) => p.longitude).reduce(min);
    final maxLng = points.map((p) => p.longitude).reduce(max);

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();

    // Prevent Google Maps from receiving an invalid/too-small bounds.
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_driverPos, 16),
      );
      return;
    }

    final latPadding = latDiff * 0.15;
    final lngPadding = lngDiff * 0.15;

    final sw = LatLng(
      minLat - latPadding,
      minLng - lngPadding,
    );

    final ne = LatLng(
      maxLat + latPadding,
      maxLng + lngPadding,
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: sw,
          northeast: ne,
        ),
        80,
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 28,
      thickness: 1,
      color: Colors.grey[100],
    );
  }
}
