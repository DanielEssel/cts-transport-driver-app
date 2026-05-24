// lib/features/trips/presentation/active_trip_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../models/trip_model.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  TripModel?    _trip;
  TripStatus    _currentStatus = TripStatus.tripAccepted;

  GoogleMapController? _mapController;
  LatLng _currentLocation  = const LatLng(5.6037, -0.1870);
  LatLng _pickupLocation   = const LatLng(5.6037, -0.1870);
  LatLng _dropoffLocation  = const LatLng(5.6037, -0.1870);

  bool   _isLoading         = true;
  String _eta               = 'Calculating...';
  double _distanceRemaining = 0;

  bool _isArriving       = false;
  bool _isStartingTrip   = false;
  bool _isCompletingTrip = false;

  StreamSubscription<Position>?         _locationSub;
  StreamSubscription<DocumentSnapshot>? _tripSub;

  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
    _startLocationTracking();
    _subscribeToTripChanges();
  }

  Future<void> _loadTripDetails() async {
    try {
      final doc = await _db.collection('trips').doc(widget.tripId).get();
      if (!doc.exists || !mounted) return;
      final trip = TripModel.fromFirestore(doc);
      setState(() {
        _trip           = trip;
        _currentStatus  = trip.status;
        _pickupLocation = LatLng(
          trip.pickupLocation.latitude,
          trip.pickupLocation.longitude,
        );
        _dropoffLocation = LatLng(
          trip.dropoffLocation.latitude,
          trip.dropoffLocation.longitude,
        );
        _isLoading = false;
      });
      _fitMapToBounds();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load trip.', isError: true);
      }
    }
  }

  void _subscribeToTripChanges() {
    _tripSub = _db.collection('trips').doc(widget.tripId)
        .snapshots().listen((doc) {
      if (!doc.exists || !mounted) return;
      final trip = TripModel.fromFirestore(doc);
      setState(() {
        _trip          = trip;
        _currentStatus = trip.status;
      });
      // Auto-pop on cancellation by passenger
      if (trip.status == TripStatus.cancelledByPassenger) {
        _showSnackBar('Passenger cancelled the trip.', isError: true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  void _startLocationTracking() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentLocation =
          LatLng(pos.latitude, pos.longitude));
      _updateDriverLocation(pos);
      _recalculateEta();
    });
  }

  Future<void> _updateDriverLocation(Position pos) async {
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'driverCurrentLocation': GeoPoint(pos.latitude, pos.longitude),
        'driverHeading':         pos.heading,
        'lastLocationUpdate':    FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _recalculateEta() {
    final destination = (_currentStatus == TripStatus.tripAccepted)
        ? _pickupLocation
        : _dropoffLocation;
    final distance = _haversineKm(_currentLocation, destination);
    if (!mounted) return;
    setState(() {
      _distanceRemaining = distance;
      final minutes      = (distance / 30 * 60).ceil();
      _eta               = minutes <= 1 ? '< 1 min' : '$minutes min';
    });
  }

  // ── Trip actions ──────────────────────────────

  Future<void> _handleArrived() async {
    setState(() => _isArriving = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status':    'driverArrived',
        'arrivedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnackBar('Marked as arrived ✓', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to update status.', isError: true);
    } finally {
      if (mounted) setState(() => _isArriving = false);
    }
  }

  Future<void> _handleStartTrip() async {
    setState(() => _isStartingTrip = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status':    'tripStarted',
        'startedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnackBar('Trip started!', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to start trip.', isError: true);
    } finally {
      if (mounted) setState(() => _isStartingTrip = false);
    }
  }

  Future<void> _handleCompleteTrip() async {
    setState(() => _isCompletingTrip = true);
    try {
      final fare = _trip!.finalFare ?? _trip!.fare;
      await _db.runTransaction((txn) async {
        final tripRef   = _db.collection('trips').doc(widget.tripId);
        final driverRef = _db.collection('drivers').doc(_uid);
        final driverSnap = await txn.get(driverRef);
        final currentEarnings =
            (driverSnap.data()?['totalEarnings'] as num?)?.toDouble() ?? 0;
        txn.update(tripRef, {
          'status':        'completed',
          'completedAt':   FieldValue.serverTimestamp(),
          'finalFare':     fare,
          'isAvailable':   true,
        });
        txn.update(driverRef, {
          'totalEarnings':  currentEarnings + fare,
          'completedTrips': FieldValue.increment(1),
          'todayEarnings':  FieldValue.increment(fare),
          'isAvailable':    true,
        });
      });
      if (mounted) {
        _showSnackBar('Trip completed! GHS ${fare.toStringAsFixed(2)}',
            isSuccess: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/driver-shell', (_) => false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCompletingTrip = false);
        _showSnackBar('Failed to complete trip.', isError: true);
      }
    }
  }

  Future<void> _handleCancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title:   const Text('Cancel Trip?'),
        content: const Text(
            'Cancelling after accepting may affect your acceptance rate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Trip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status':      'cancelledByDriver',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('drivers').doc(_uid).update({
        'isAvailable': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to cancel.', isError: true);
    }
  }

  // ── Helpers ───────────────────────────────────

  void _fitMapToBounds() {
    if (_mapController == null) return;
    final sw = LatLng(
      min(_pickupLocation.latitude, _dropoffLocation.latitude),
      min(_pickupLocation.longitude, _dropoffLocation.longitude),
    );
    final ne = LatLng(
      max(_pickupLocation.latitude, _dropoffLocation.latitude),
      max(_pickupLocation.longitude, _dropoffLocation.longitude),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  double _haversineKm(LatLng from, LatLng to) {
    const r  = 6371.0;
    final dLat = _rad(to.latitude - from.latitude);
    final dLon = _rad(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(from.latitude)) * cos(_rad(to.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  void _showSnackBar(String msg,
      {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isSuccess
          ? Colors.green
          : isError
              ? Colors.red
              : null,
      behavior:  SnackBarBehavior.floating,
      shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _tripSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // ── Map (top 55%) ──
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) {
                    _mapController = c;
                    _fitMapToBounds();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pickupLocation,
                    zoom:   14,
                  ),
                  markers:              _buildMarkers(),
                  myLocationEnabled:    false,
                  zoomControlsEnabled:  false,
                  mapToolbarEnabled:    false,
                ),
                // Back button
                Positioned(
                  top:  MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width:  40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        shape:        BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:      Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                ),
                // Status pill
                Positioned(
                  top:   MediaQuery.of(context).padding.top + 12,
                  left:  68,
                  right: 16,
                  child: _buildStatusPill(),
                ),
              ],
            ),
          ),

          // ── Bottom panel (45%) ──
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color:      Color(0x10000000),
                    blurRadius: 16,
                    offset:     Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width:  40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:        Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _buildPassengerRow(),
                    const Divider(height: 24),
                    _buildRouteRow(),
                    const Divider(height: 24),
                    _buildMetaRow(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────

  Widget _buildStatusPill() {
    final (color, label) = switch (_currentStatus) {
      TripStatus.tripAccepted  => (Colors.orange, 'Heading to pickup'),
      TripStatus.driverArrived => (Colors.green,  'Waiting at pickup'),
      TripStatus.tripStarted   => (Colors.blue,   'Trip in progress'),
      TripStatus.completed     => (Colors.purple, 'Completed'),
      TripStatus.cancelledByDriver    => (Colors.red, 'Cancelled'),
      TripStatus.cancelledByPassenger => (Colors.red, 'Cancelled by passenger'),
      _ => (Colors.grey, _currentStatus.displayName),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      color.withValues(alpha: 0.4),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize:   13,
                )),
          ),
          Text(_eta,
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   13,
              )),
        ],
      ),
    );
  }

  Widget _buildPassengerRow() {
    return Row(
      children: [
        CircleAvatar(
          radius:          24,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          backgroundImage: _trip!.passengerPhotoUrl != null
              ? NetworkImage(_trip!.passengerPhotoUrl!)
              : null,
          child: _trip!.passengerPhotoUrl == null
              ? Text(
                  _trip!.passengerName.isNotEmpty
                      ? _trip!.passengerName[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color:      AppColors.primaryColor,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_trip!.passengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   15,
                  )),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFB74D), size: 14),
                  const SizedBox(width: 2),
                  Text(_trip!.passengerRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        // Cancel button
        OutlinedButton(
          onPressed: _handleCancelTrip,
          style: OutlinedButton.styleFrom(
            padding:         const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            side:            const BorderSide(color: Colors.red),
            foregroundColor: Colors.red,
          ),
          child: const Text('Cancel', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildRouteRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width:  10,
              height: 10,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
            ),
            Container(width: 2, height: 24, color: Colors.grey[300]),
            Container(
              width:  10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_trip!.pickupAddress,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 18),
              Text(_trip!.dropoffAddress,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MetaChip(icon: Icons.schedule,     label: _eta),
        _MetaChip(
            icon:  Icons.straighten,
            label: '${_distanceRemaining.toStringAsFixed(1)} km'),
        _MetaChip(
            icon:  Icons.payments_outlined,
            label: 'GHS ${(_trip!.finalFare ?? _trip!.fare).toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildActionButtons() {
    return switch (_currentStatus) {
      TripStatus.tripAccepted => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isArriving ? null : _handleArrived,
          icon:  _isArriving
              ? const _Spinner()
              : const Icon(Icons.location_on_rounded),
          label: const Text("I've Arrived at Pickup",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            padding:         const EdgeInsets.symmetric(vertical: 16),
            shape:           RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      TripStatus.driverArrived => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isStartingTrip ? null : _handleStartTrip,
          icon:  _isStartingTrip
              ? const _Spinner()
              : const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Trip',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            padding:         const EdgeInsets.symmetric(vertical: 16),
            shape:           RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      TripStatus.tripStarted => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isCompletingTrip ? null : _handleCompleteTrip,
          icon:  _isCompletingTrip
              ? const _Spinner()
              : const Icon(Icons.flag_rounded),
          label: const Text('Complete Trip',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding:         const EdgeInsets.symmetric(vertical: 16),
            shape:           RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      TripStatus.completed => _Banner(
        icon:    Icons.check_circle_rounded,
        color:   Colors.green,
        message: 'Trip completed — GHS ${(_trip!.finalFare ?? _trip!.fare).toStringAsFixed(2)}',
      ),

      TripStatus.cancelledByDriver ||
      TripStatus.cancelledByPassenger => const _Banner(
        icon:    Icons.cancel_rounded,
        color:   Colors.red,
        message: 'This trip was cancelled.',
      ),

      _ => const SizedBox.shrink(),
    };
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId:   const MarkerId('pickup'),
        position:   _pickupLocation,
        icon:       BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId:   const MarkerId('dropoff'),
        position:   _dropoffLocation,
        icon:       BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),
      Marker(
        markerId:   const MarkerId('driver'),
        position:   _currentLocation,
        icon:       BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ),
    };
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white),
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   message;
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
