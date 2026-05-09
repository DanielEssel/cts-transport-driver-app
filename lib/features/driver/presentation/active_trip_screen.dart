// features/driver/presentation/active_trip_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

enum TripPhase { enRouteToPickup, arrived, inProgress, completed }

class ActiveTripScreen extends StatefulWidget {
  final String rideId;
  const ActiveTripScreen({super.key, required this.rideId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  // ── Firebase ───────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // ── Map ────────────────────────────────────────
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _driverPosition;

  // ── Trip data ──────────────────────────────────
  Map<String, dynamic> _tripData = {};
  TripPhase _phase = TripPhase.enRouteToPickup;
  bool _isLoading = true;
  bool _isUpdating = false;
  Duration _elapsed = Duration.zero;

  // ── Subscriptions ──────────────────────────────
  StreamSubscription<DocumentSnapshot>? _tripSub;
  StreamSubscription<Position>? _locationSub;
  Timer? _timer;

  // ── Animation ─────────────────────────────────
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _subscribeToTrip();
    _startLocationTracking();
  }

  void _subscribeToTrip() {
    _tripSub = _firestore
        .collection('rideRequests')
        .doc(widget.rideId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      setState(() {
        _tripData = data;
        _isLoading = false;
        _phase = _phaseFromStatus(data['status'] as String? ?? 'accepted');
      });
      _updateMapMarkers();
      _slideController.forward();
    });
  }

  TripPhase _phaseFromStatus(String status) {
    switch (status) {
      case 'arrived':
        return TripPhase.arrived;
      case 'inProgress':
        return TripPhase.inProgress;
      case 'completed':
        return TripPhase.completed;
      default:
        return TripPhase.enRouteToPickup;
    }
  }

  void _startLocationTracking() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _driverPosition = latLng);

      // Push to Firestore
      _firestore
          .collection('rideRequests')
          .doc(widget.rideId)
          .update({'driverLocation': GeoPoint(pos.latitude, pos.longitude)});

      // Animate camera
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      _updateMapMarkers();
    });
  }

  void _updateMapMarkers() {
    final pickup = _tripData['fromLocation'] as GeoPoint?;
    final dropoff = _tripData['toLocation'] as GeoPoint?;

    setState(() {
      _markers.clear();
      if (_driverPosition != null) {
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: _driverPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ));
      }
      if (pickup != null && _phase == TripPhase.enRouteToPickup) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.latitude, pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: _tripData['fromAddress'] ?? 'Pickup'),
        ));
      }
      if (dropoff != null && _phase == TripPhase.inProgress) {
        _markers.add(Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoff.latitude, dropoff.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _tripData['toAddress'] ?? 'Drop-off'),
        ));
      }
    });
  }

  // ── Phase Actions ──────────────────────────────

  Future<void> _advancePhase() async {
    if (_isUpdating) return;
    HapticFeedback.heavyImpact();
    setState(() => _isUpdating = true);

    try {
      String newStatus;
      switch (_phase) {
        case TripPhase.enRouteToPickup:
          newStatus = 'arrived';
          break;
        case TripPhase.arrived:
          newStatus = 'inProgress';
          _startTripTimer();
          break;
        case TripPhase.inProgress:
          newStatus = 'completed';
          _timer?.cancel();
          await _completeTrip();
          return;
        case TripPhase.completed:
          return;
      }

      await _firestore
          .collection('rideRequests')
          .doc(widget.rideId)
          .update({
        'status': newStatus,
        '${newStatus}At': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showError('Failed to update trip status.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _startTripTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _completeTrip() async {
    final fare = (_tripData['fareAmount'] as num?)?.toDouble() ?? 0.0;

    await Future.wait([
      _firestore.collection('rideRequests').doc(widget.rideId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'tripDurationSeconds': _elapsed.inSeconds,
      }),
      // Credit driver earnings
      _firestore
          .collection('drivers')
          .doc(_uid)
          .collection('earnings')
          .doc('summary')
          .set({
        'todayEarnings': FieldValue.increment(fare),
        'totalBalance': FieldValue.increment(fare),
        'todayTrips': FieldValue.increment(1),
        'weekEarnings': FieldValue.increment(fare),
      }, SetOptions(merge: true)),
      _firestore
          .collection('drivers')
          .doc(_uid)
          .collection('stats')
          .doc('lifetime')
          .set({
        'completedTrips': FieldValue.increment(1),
      }, SetOptions(merge: true)),
    ]);

    if (mounted) _showCompletionDialog(fare);
  }

  void _showCompletionDialog(double fare) {
    final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.successColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Trip Completed!', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              fmt.format(fare),
              style: AppTextStyles.driverStatsValue.copyWith(
                color: AppColors.successColor,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text('Added to your wallet',
                style: AppTextStyles.subtitle
                    .copyWith(color: AppColors.textSecondaryColor)),
            const SizedBox(height: 8),
            Text(
              'Duration: ${_formatDuration(_elapsed)}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Call / Navigate ────────────────────────────

  Future<void> _callPassenger() async {
    final phone = _tripData['passengerPhone'] as String?;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNavigation() async {
    GeoPoint? target;
    if (_phase == TripPhase.enRouteToPickup || _phase == TripPhase.arrived) {
      target = _tripData['fromLocation'] as GeoPoint?;
    } else {
      target = _tripData['toLocation'] as GeoPoint?;
    }
    if (target == null) return;
    final uri = Uri.parse(
        'google.navigation:q=${target.latitude},${target.longitude}&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  // ── Helpers ────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.errorColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  String get _phaseLabel {
    switch (_phase) {
      case TripPhase.enRouteToPickup:
        return 'En Route to Pickup';
      case TripPhase.arrived:
        return 'Arrived at Pickup';
      case TripPhase.inProgress:
        return 'Trip in Progress';
      case TripPhase.completed:
        return 'Trip Completed';
    }
  }

  String get _actionLabel {
    switch (_phase) {
      case TripPhase.enRouteToPickup:
        return 'I\'ve Arrived';
      case TripPhase.arrived:
        return 'Start Trip';
      case TripPhase.inProgress:
        return 'Complete Trip';
      case TripPhase.completed:
        return 'Done';
    }
  }

  Color get _phaseColor {
    switch (_phase) {
      case TripPhase.enRouteToPickup:
        return AppColors.primaryColor;
      case TripPhase.arrived:
        return const Color(0xFFFFB74D);
      case TripPhase.inProgress:
        return AppColors.successColor;
      case TripPhase.completed:
        return AppColors.successColor;
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _locationSub?.cancel();
    _timer?.cancel();
    _mapController?.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ── Map ─────────────────────────────
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverPosition ?? const LatLng(5.6037, -0.1870),
                    zoom: 15,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // ── Top status bar ───────────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _phaseColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _phaseColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 10),
                        const SizedBox(width: 8),
                        Text(
                          _phaseLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (_phase == TripPhase.inProgress)
                          Text(
                            _formatDuration(_elapsed),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Navigate button ──────────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'nav',
                    onPressed: _openNavigation,
                    backgroundColor: AppColors.backgroundColor,
                    child: const Icon(Icons.navigation_rounded,
                        color: AppColors.primaryColor),
                  ),
                ),

                // ── Bottom panel ─────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildBottomPanel(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomPanel() {
    final name = _tripData['passengerName'] as String? ?? 'Passenger';
    final rating =
        (_tripData['passengerRating'] as num?)?.toDouble() ?? 5.0;
    final from = _tripData['fromAddress'] as String? ?? '—';
    final to = _tripData['toAddress'] as String? ?? '—';
    final fare = (_tripData['fareAmount'] as num?)?.toDouble() ?? 0.0;
    final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Passenger row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: AppTextStyles.heading4
                      .copyWith(color: AppColors.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFFFB74D), size: 14),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(fare),
                style: AppTextStyles.cardPrice,
              ),
              const SizedBox(width: 12),
              // Call button
              GestureDetector(
                onTap: _callPassenger,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.successColor.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.phone,
                      color: AppColors.successColor, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 12),

          // Route
          _RouteRow(from: from, to: to),

          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _advancePhase,
              style: ElevatedButton.styleFrom(
                backgroundColor: _phaseColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(_actionLabel,
                      style: AppTextStyles.buttonSmall
                          .copyWith(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String from;
  final String to;
  const _RouteRow({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryColor, width: 2),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 28, color: AppColors.borderColor),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              Text(to,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}