// lib/features/trips/presentation/active_trip_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip_model.dart';

// ── Brand colors (use your AppColors) ────────────────────────────────────────
const _kPrimary = Color(0xFF16A34A);
const _kSurface = Colors.white;
const _kBg = Color(0xFFF8FAF9);

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with WidgetsBindingObserver {
  // ── State ─────────────────────────────────────
  TripModel? _trip;
  TripStatus _status = TripStatus.tripAccepted;
  bool _isLoading = true;
  String _eta = 'Calculating...';
  double _distKm = 0;

  String _passengerName = 'Passenger';
  String? _passengerPhotoUrl;
  double _passengerRating = 0.0;


  // ── Button states ──────────────────────────────
  bool _isArriving = false;
  bool _isStarting = false;
  bool _isCompleting = false;
  bool _isCancelling = false;

  // ── Map ───────────────────────────────────────
  GoogleMapController? _mapController;
  BitmapDescriptor? _driverIcon;
  LatLng _driverPos = const LatLng(5.6037, -0.1870);
  LatLng _pickupPos = const LatLng(5.6037, -0.1870);
  LatLng _dropoffPos = const LatLng(5.6037, -0.1870);
  bool _mapReady = false;

  // ── Subscriptions ──────────────────────────────
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<DocumentSnapshot>? _tripSub;
  Timer? _locationThrottle;

  // ── Firebase ──────────────────────────────────
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Map style ─────────────────────────────────
  static const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8f5e9"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d9f2"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]}
]
''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomMarkers();
    _loadTrip();
    _subscribeToTrip();
    _startGps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _gpsSub?.pause();
    if (state == AppLifecycleState.resumed) _gpsSub?.resume();
  }

  // ── Init helpers ──────────────────────────────

  Future<void> _loadCustomMarkers() async {
    try {
      final serviceType = _trip?.serviceType ?? 'taxi';
      final asset = serviceType == 'okada'
          ? 'assets/icons/motorcycle_marker.png'
          : 'assets/icons/car_marker.png';
      _driverIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        asset,
      );
    } catch (_) {
      // Fallback to default if asset missing
      _driverIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadTrip() async {
  try {
    final doc = await _db.collection('trips').doc(widget.tripId).get();
    if (!doc.exists || !mounted) return;
    final trip = TripModel.fromFirestore(doc);
    _applyTrip(trip);

    if (trip.passengerId.isNotEmpty) {
      final userDoc = await _db.collection('users').doc(trip.passengerId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        final firstName   = userData['firstName']   as String? ?? '';
        final lastName    = userData['lastName']    as String? ?? '';
        final fullName    = '$firstName $lastName'.trim();
        final photoUrl    = userData['photoURL']    as String?;
        final ratingTotal = (userData['ratingTotal'] as num?)?.toDouble() ?? 0;
        final ratingCount = (userData['ratingCount'] as num?)?.toInt()    ?? 0;
        final avgRating   = ratingCount > 0 ? ratingTotal / ratingCount : 0.0;

        setState(() {
          _passengerName     = fullName.isEmpty ? 'Passenger' : fullName;
          _passengerPhotoUrl = photoUrl;
          _passengerRating   = avgRating;
        });
      }
    }

    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      _snack('Could not load trip details.', isError: true);
    }
  }
}

  void _subscribeToTrip() {
    _tripSub =
        _db.collection('trips').doc(widget.tripId).snapshots().listen((doc) {
      if (!doc.exists || !mounted) return;
      final trip = TripModel.fromFirestore(doc);
      _applyTrip(trip);
      setState(() {});

      if (trip.status == TripStatus.cancelledByPassenger) {
        _snack('Passenger cancelled the trip.', isError: true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  void _applyTrip(TripModel trip) {
    final firstLoad = _pickupPos.latitude == 5.6037;
    final prevServiceType = _trip?.serviceType;
    _trip = trip;
    _status = trip.status;
    _pickupPos = LatLng(
      trip.pickupLocation.latitude,
      trip.pickupLocation.longitude,
    );
    _dropoffPos = LatLng(
      trip.dropoffLocation.latitude,
      trip.dropoffLocation.longitude,
    );
    // Reload marker if serviceType changed
    if (prevServiceType != trip.serviceType) {
      _loadCustomMarkers();
    }
    // Fit map when data first arrives and map is ready
    if (firstLoad && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _startGps() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // ✅ increased from 10 — reduces updates
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _driverPos = LatLng(pos.latitude, pos.longitude));
      _recalcEta();
      _throttledLocationUpdate(pos); // ✅ throttled Firestore write
    });
  }

  // ── Throttled Firestore location write ────────
  // Writes at most once every 5 seconds regardless of GPS frequency

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

  void _recalcEta() {
    final dest = _status == TripStatus.tripAccepted ? _pickupPos : _dropoffPos;
    final km = _haversineKm(_driverPos, dest);
    if (!mounted) return;
    // Speed estimate varies by service type
    final speedKmh = _trip?.serviceType == 'okada' ? 25.0 : 30.0;
    final mins = (km / speedKmh * 60).ceil();
    setState(() {
      _distKm = km;
      _eta = mins <= 1 ? '< 1 min' : '$mins min';
    });
  }

  // ── Map helpers ───────────────────────────────

  void _fitBounds() {
    if (!_mapReady || _mapController == null) return;
    final sw = LatLng(
      min(_pickupPos.latitude, _dropoffPos.latitude),
      min(_pickupPos.longitude, _dropoffPos.longitude),
    );
    final ne = LatLng(
      max(_pickupPos.latitude, _dropoffPos.latitude),
      max(_pickupPos.longitude, _dropoffPos.longitude),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  Set<Marker> _buildMarkers() => {
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupPos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Drop-off'),
        ),
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos,
          icon: _driverIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
          rotation: 0,
          flat: true, // ✅ rotates with map
        ),
      };

  // ── Trip actions ──────────────────────────────

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

  Future<void> _handleStartTrip() async {
    if (_isStarting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isStarting = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status': 'tripStarted',
        'startedAt': FieldValue.serverTimestamp(),
      });
      _snack('Trip started! 🚀', isSuccess: true);
      // Switch map focus to dropoff
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_dropoffPos, 14),
      );
    } catch (_) {
      _snack('Failed to start trip.', isError: true);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _handleCompleteTrip() async {
    if (_isCompleting) return;
    HapticFeedback.heavyImpact();

    // Confirm before completing
    final confirmed = await _showConfirmDialog(
      title: 'Complete Trip?',
      content: 'Have you reached the drop-off location?',
      confirm: 'Yes, Complete',
      confirmColor: _kPrimary,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);
    try {
      final fare = _trip!.finalFare ?? _trip!.fare;
      // Cloud Function onTripCompleted handles wallet deduction + driver credit
      await _db.collection('trips').doc(widget.tripId).update({
        'status':           'completed',
        'completedAt':      FieldValue.serverTimestamp(),
        'finalFare':        fare,
        'actualDistanceKm': _distKm,
        'distanceKm':       _distKm,
      });

      if (!mounted) return;
      _snack('Trip completed! GHS ${fare.toStringAsFixed(2)} 🎉',
          isSuccess: true);

      // Navigate after snack is visible
      // AFTER
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/driver-shell', (_) => false);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isCompleting = false);
        _snack('Failed to complete trip. Try again.', isError: true);
      }
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
          'currentTripId': FieldValue.delete(), // ✅ clean up
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
    final phone = _trip?.driverPhone; // passenger phone stored here
    // Actually get passenger phone from users collection
    if (_trip == null) return;
    try {
      final doc = await _db.collection('users').doc(_trip!.passengerId).get();
      final phone = doc.data()?['phoneNumber'] as String?;
      if (phone == null || phone.isEmpty) {
        _snack('Passenger phone not available.');
        return;
      }
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {
      _snack('Could not get passenger contact.');
    }
  }

  // ── Dialogs ───────────────────────────────────

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirm,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(content, style: TextStyle(color: Colors.grey[600])),
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

  // ── Utilities ─────────────────────────────────

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }
  
  double _rad(double d) => d * pi / 180;

  void _snack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess
            ? _kPrimary
            : isError
                ? Colors.red[700]
                : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _tripSub?.cancel();
    _locationThrottle?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _trip == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Map ──
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                GoogleMap(
                  style: _mapStyle,
                  onMapCreated: (c) {
                    _mapController = c;
                    setState(() => _mapReady = true);
                    // Wait for trip data to load then fit bounds
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted) _fitBounds();
                    });
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pickupPos,
                    zoom: 14,
                  ),
                  markers: _buildMarkers(),
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
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
                    color: _kPrimary,
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
                  child: _buildStatusBar(),
                ),
              ],
            ),
          ),

          // ── Bottom panel ──
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: _kSurface,
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
                    _buildPassengerRow(),
                    const _Divider(),
                    _buildRouteRow(),
                    const _Divider(),
                    _buildMetaRow(),
                    const SizedBox(height: 20),
                    _buildActionButton(),
                    const SizedBox(height: 10),
                    _buildCancelButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status bar ────────────────────────────────

  Widget _buildStatusBar() {
    final (color, icon, label) = switch (_status) {
      TripStatus.tripAccepted => (
          _kPrimary,
          Icons.directions_rounded,
          'Heading to pickup'
        ),
      TripStatus.driverArrived => (
          Colors.green,
          Icons.location_on_rounded,
          'Waiting at pickup'
        ),
      TripStatus.tripStarted => (
          Colors.blue,
          Icons.electric_bolt_rounded,
          'Trip in progress'
        ),
      TripStatus.completed => (
          Colors.purple,
          Icons.flag_rounded,
          'Trip completed'
        ),
      _ => (Colors.grey, Icons.info_rounded, _status.displayName),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_eta,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
          ),
        ],
      ),
    );
  }

  // ── Handle ────────────────────────────────────

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

  // ── Passenger row ─────────────────────────────

  Widget _buildPassengerRow() {
    final name = _passengerName;
    final initials = name
        .trim()
        .split(' ')
        .map((p) => p.isEmpty ? '' : p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _kPrimary.withValues(alpha: 0.1),
          backgroundImage: _passengerPhotoUrl != null
              ? NetworkImage(_passengerPhotoUrl!)
              : null,
          child: _passengerPhotoUrl == null
              ? Text(initials.isEmpty ? 'P' : initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                    fontSize: 16,
                  ))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
             // REPLACE the const Row(children: [Icon, SizedBox]) block with:
Row(
  children: [
    const Icon(Icons.star_rounded, color: Color(0xFFFFB74D), size: 14),
    const SizedBox(width: 3),
    Text(
      _passengerRating > 0
          ? _passengerRating.toStringAsFixed(1)
          : 'New',
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    ),
  ],
),
            ],
          ),
        ),
        // ✅ Call button
        _IconAction(
          icon: Icons.phone_rounded,
          color: _kPrimary,
          onTap: _callPassenger,
          tooltip: 'Call passenger',
        ),
      ],
    );
  }

  // ── Route row ────────────────────────────────

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
              Text('Pickup',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
              Text(_trip!.pickupAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 18),
              Text('Drop-off',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
              Text(_trip!.dropoffAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ── Meta row ──────────────────────────────────

  Widget _buildMetaRow() {
    final fare = _trip!.finalFare ?? _trip!.fare;
    return Row(
      children: [
        Expanded(
            child: _MetaChip(
          icon: Icons.schedule_rounded,
          label: _eta,
          color: _kPrimary,
        )),
        const SizedBox(width: 8),
        Expanded(
            child: _MetaChip(
          icon: Icons.route_rounded,
          label: '${_distKm.toStringAsFixed(1)} km',
          color: Colors.blue,
        )),
        const SizedBox(width: 8),
        Expanded(
            child: _MetaChip(
          icon: Icons.payments_outlined,
          label: 'GHS ${fare.toStringAsFixed(2)}',
          color: Colors.orange,
        )),
      ],
    );
  }

  // ── Action button ─────────────────────────────

  Widget _buildActionButton() {
    return switch (_status) {
      TripStatus.tripAccepted => _ActionBtn(
          label: "I've Arrived at Pickup",
          icon: Icons.location_on_rounded,
          color: Colors.green,
          isLoading: _isArriving,
          onTap: _handleArrived,
        ),
      TripStatus.driverArrived => _ActionBtn(
          label: 'Start Trip',
          icon: Icons.play_arrow_rounded,
          color: Colors.blue,
          isLoading: _isStarting,
          onTap: _handleStartTrip,
        ),
      TripStatus.tripStarted => _ActionBtn(
          label: 'Complete Trip',
          icon: Icons.flag_rounded,
          color: _kPrimary,
          isLoading: _isCompleting,
          onTap: _handleCompleteTrip,
        ),
      // AFTER
      TripStatus.completed => Column(
          children: [
            _Banner(
              icon: Icons.check_circle_rounded,
              color: Colors.green,
              message:
                  'Trip completed — GHS ${(_trip!.finalFare ?? _trip!.fare).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/driver-shell', (_) => false),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      TripStatus.cancelledByDriver ||
      TripStatus.cancelledByPassenger =>
        const _Banner(
          icon: Icons.cancel_rounded,
          color: Colors.red,
          message: 'This trip was cancelled.',
        ),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Cancel button (separate from action) ──────

  Widget _buildCancelButton() {
    // Only show cancel when trip is still active
    final showCancel = _status == TripStatus.tripAccepted ||
        _status == TripStatus.driverArrived ||
        _status == TripStatus.tripStarted;

    if (!showCancel) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isCancelling ? null : _handleCancelTrip,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
          foregroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isCancelling
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.red),
              )
            : const Text('Cancel Trip',
                style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════

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
  Widget build(BuildContext context) => GestureDetector(
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

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(
        height: 28,
        thickness: 1,
        color: Colors.grey[100],
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isLoading ? null : onTap,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon),
          label: Text(label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
            ),
          ],
        ),
      );
}
