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
  // ── Trip state ─────────────────────────────────
  TripModel? _trip;
  TripStatus _currentStatus = TripStatus.accepted;

  // ── Map ────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(5.6037, -0.1870); // Accra default
  LatLng _pickupLocation = const LatLng(5.6037, -0.1870);
  LatLng _dropoffLocation = const LatLng(5.6037, -0.1870);

  // ── UI state ───────────────────────────────────
  bool _isLoading = true;
  String _eta = 'Calculating...';
  double _distanceRemaining = 0;

  // ── Button loading states ──────────────────────
  bool _isArriving = false;
  bool _isStartingTrip = false;
  bool _isCompletingTrip = false;

  // ── Subscriptions ──────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<DocumentSnapshot>? _tripSub;

  // ── Firebase refs ──────────────────────────────
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
    _startLocationTracking();
    _subscribeToTripChanges();
  }

  // ── Data loading ───────────────────────────────

  Future<void> _loadTripDetails() async {
    try {
      final doc = await _db.collection('trips').doc(widget.tripId).get();
      if (!doc.exists || !mounted) return;

      final trip = TripModel.fromFirestore(doc);
      setState(() {
        _trip = trip;
        _currentStatus = trip.status;
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
        _showSnackBar('Failed to load trip details.', isError: true);
      }
    }
  }

  void _subscribeToTripChanges() {
    _tripSub =
        _db.collection('trips').doc(widget.tripId).snapshots().listen((doc) {
      if (!doc.exists || !mounted) return;
      final trip = TripModel.fromFirestore(doc);
      setState(() {
        _trip = trip;
        _currentStatus = trip.status;
      });
    });
  }

  void _startLocationTracking() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _updateDriverLocation(position);
      _recalculateEta();
    });
  }

  Future<void> _updateDriverLocation(Position pos) async {
    await Future.wait([
      // Full location history (for playback / audit)
      _db.collection('trips').doc(widget.tripId).collection('locations').add({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'timestamp': FieldValue.serverTimestamp(),
      }),
      // Live cursor for passenger app
      _db.collection('trips').doc(widget.tripId).update({
        'driverCurrentLocation': GeoPoint(pos.latitude, pos.longitude),
        'driverHeading': pos.heading,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }),
    ]);
  }

  void _recalculateEta() {
    final destination = (_currentStatus == TripStatus.accepted ||
            _currentStatus == TripStatus.pending)
        ? _pickupLocation
        : _dropoffLocation;

    final distance = _haversineKm(_currentLocation, destination);
    if (!mounted) return;
    setState(() {
      _distanceRemaining = distance;
      // Rough estimate at 30 km/h average urban speed
      final minutes = (distance / 30 * 60).ceil();
      _eta = '$minutes min';
    });
  }

  // ── Trip action handlers ───────────────────────

  Future<void> _handleArrived() async {
    setState(() => _isArriving = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status': 'driverArrived',
        'arrivedAt': FieldValue.serverTimestamp(),
      });
      await _notifyPassenger('Your driver has arrived at the pickup point.');
      if (mounted) _showSnackBar('Marked as arrived', isSuccess: true);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to update status. Try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isArriving = false);
    }
  }

  Future<void> _handleStartTrip() async {
    final verified = await _showVerificationDialog();
    if (!verified) return;

    setState(() => _isStartingTrip = true);
    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status': 'tripStarted',
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
      final fare = _trip!.fare;

      await _db.runTransaction((txn) async {
        final tripRef = _db.collection('trips').doc(widget.tripId);
        final driverRef = _db.collection('drivers').doc(_uid);

        final driverSnap = await txn.get(driverRef);

        txn.update(tripRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'finalFare': fare,
          'totalDistance': _distanceRemaining,
        });

        final currentEarnings =
            (driverSnap.data()?['totalEarnings'] as num?)?.toDouble() ?? 0;
        txn.update(driverRef, {
          'totalEarnings': currentEarnings + fare,
          'completedTrips': FieldValue.increment(1),
          'todayEarnings': FieldValue.increment(fare),
        });
      });

      await _notifyPassenger('Your trip has been completed. Thank you!');

      if (mounted) {
        _showSnackBar('Trip completed! ${_formatCurrency(fare)}',
            isSuccess: true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/driver-shell', (_) => false);
          }
        });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Trip?'),
        content: const Text(
            'Cancelling after accepting may affect your acceptance rate.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Trip')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _db.collection('trips').doc(widget.tripId).update({
        'status': 'cancelled',
        'cancelledBy': 'driver',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('drivers').doc(_uid).update({
        'cancelledTrips': FieldValue.increment(1),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to cancel trip.', isError: true);
    }
  }

  // ── Verification dialog ────────────────────────

  Future<bool> _showVerificationDialog() async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Verify Passenger',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ask the passenger for their 4-digit trip code.'),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Trip Code',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                textAlign:    TextAlign.center,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
                maxLength: 4,
                onChanged: (v) {
                  if (v.length == 4) {
                    final valid = _trip?.verificationCode == null ||
                        v == _trip!.verificationCode;
                    Navigator.of(ctx).pop(valid);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ) ??
      false;
}

  // ── Helpers ────────────────────────────────────

  Future<void> _notifyPassenger(String message) async {
    if (_trip == null) return;
    await _db
        .collection('passengers')
        .doc(_trip!.passengerId)
        .collection('notifications')
        .add({
      'title': 'Trip Update',
      'body': message,
      'tripId': widget.tripId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

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
          LatLngBounds(southwest: sw, northeast: ne), 60),
    );
  }

  double _haversineKm(LatLng from, LatLng to) {
    const r = 6371.0;
    final dLat = _rad(to.latitude - from.latitude);
    final dLon = _rad(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(from.latitude)) *
            cos(_rad(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  String _formatCurrency(double amount) => 'GHS ${amount.toStringAsFixed(2)}';

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isSuccess
          ? Colors.green
          : isError
              ? Colors.red
              : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

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
          // ── Map ───────────────────────────────
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) {
                    _mapController = c;
                    _fitMapToBounds();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pickupLocation,
                    zoom: 14,
                  ),
                  markers: _buildMarkers(),
                  polylines: _buildPolylines(),
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Status pill overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: _buildStatusPill(),
                ),
              ],
            ),
          ),

          // ── Bottom panel ──────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────

  Widget _buildStatusPill() {
    final color = _statusColor(_currentStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 8),
          Text(
            _currentStatus.displayName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(_eta,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPassengerRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
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
                      color: AppColors.primaryColor),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_trip!.passengerName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFB74D), size: 14),
                  const SizedBox(width: 2),
                  Text(_trip!.passengerRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        // Chat button
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            '/driver-chat',
            arguments: {
              'tripId': widget.tripId,
              'passengerId': _trip!.passengerId,
              'passengerName': _trip!.passengerName,
            },
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 16),
          label: const Text('Chat'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            side: const BorderSide(color: AppColors.primaryColor),
          ),
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
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
            ),
            Container(width: 2, height: 24, color: Colors.grey[300]),
            Container(
              width: 10,
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
        _MetaChip(icon: Icons.schedule, label: _eta),
        _MetaChip(
            icon: Icons.straighten,
            label: '${_distanceRemaining.toStringAsFixed(1)} km'),
        _MetaChip(
            icon: Icons.payments_outlined, label: _formatCurrency(_trip!.fare)),
      ],
    );
  }

  // ── Action buttons — exhaustive switch ─────────

  Widget _buildActionButtons() {
    switch (_currentStatus) {
      // Driver heading to pickup
      case TripStatus.accepted:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _handleCancelTrip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isArriving ? null : _handleArrived,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isArriving
                    ? const _LoadingIndicator()
                    : const Text('I\'ve Arrived',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );

      // Waiting at pickup for passenger
      case TripStatus.arrived:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isStartingTrip ? null : _handleStartTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isStartingTrip
                ? const _LoadingIndicator()
                : const Text('Start Trip',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );

      // En route to destination
      case TripStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCompletingTrip ? null : _handleCompleteTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isCompletingTrip
                ? const _LoadingIndicator()
                : const Text('Complete Trip',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );

      // Terminal states — show summary, no actions
      case TripStatus.completed:
        return _TerminalBanner(
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          message:
              'Trip completed — ${_formatCurrency(_trip!.finalFare ?? _trip!.fare)}',
        );

      case TripStatus.cancelled:
        return const _TerminalBanner(
          icon: Icons.cancel_rounded,
          color: Colors.red,
          message: 'This trip was cancelled.',
        );

      // Should not normally reach the driver app in pending state,
      // but handled to satisfy exhaustive switch.
      case TripStatus.pending:
        return const _TerminalBanner(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          message: 'Waiting for passenger confirmation...',
        );
    }
  }

  // ── Map helpers ────────────────────────────────

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),
      Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    // Replace points with Google Directions API decoded polyline in production
    return {
      const Polyline(
        polylineId: PolylineId('route'),
        color: Colors.blue,
        width: 4,
        points: [],
      ),
    };
  }

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.pending:
        return Colors.orange;
      case TripStatus.accepted:
        return Colors.orange;
      case TripStatus.arrived:
        return Colors.green;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.completed:
        return Colors.purple;
      case TripStatus.cancelled:
        return Colors.red;
    }
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _TerminalBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _TerminalBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
