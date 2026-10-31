// lib/features/trips/presentation/ride_job_screen.dart
//
// The driver's live ride screen, one stage at a time:
//
//   toPickup  (tripAccepted)  → Navigate to pickup, then I've arrived
//   atPickup  (driverArrived) → Start trip
//   onTrip    (tripStarted)   → Navigate to drop-off, then Complete trip
//
// TripFlowScreen picks the stage from the trip's live status, so a restored
// or reopened app always lands on the step the trip is actually at. Every
// step goes through applyRideStep, which re-checks the status in a
// transaction (no completing a ride that never started). What the driver
// sees at each stage (instruction, primary action) comes from ridePlan.
import 'dart:async';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../core/services/location/driver_location_publisher.dart'
    show distanceMetres;
import '../../../core/services/route_service.dart';
import '../../../core/services/trip_tracker.dart';
import '../../../core/utils/smooth_marker.dart';
import '../../jobs/domain/driver_job_cancellation.dart';
import '../../jobs/domain/job_stage_plan.dart';
import '../../jobs/widgets/job_map_layout.dart';
import '../../jobs/widgets/job_stage_panel.dart';
import '../domain/ride_lifecycle.dart';
import '../models/trip_model.dart';
import '../widgets/trip_map.dart';
import '../widgets/trip_passenger_card.dart';
import '../widgets/trip_metadata_chips.dart';
import '../widgets/navigation_button.dart' show openExternalNavigation;

/// One stage of the driver's ride, tied to an existing trip status.
enum RideStage {
  toPickup(status: TripStatus.tripAccepted, step: RideStep.arrive),
  atPickup(status: TripStatus.driverArrived, step: RideStep.start),
  onTrip(status: TripStatus.tripStarted, step: RideStep.complete);

  final TripStatus status;
  final RideStep step;

  const RideStage({required this.status, required this.step});

  /// What the driver sees at this stage (before any GPS fix).
  JobStagePlan get plan => ridePlan(step);
  String get actionLabel => plan.step.label;
  String? get navigateLabel => plan.navigateLabel;

  /// Where the driver is heading at this stage (null while waiting).
  bool get headsToPickup => this == toPickup;
  bool get headsToDropoff => this == onTrip;
}

class RideJobScreen extends StatefulWidget {
  final String tripId;
  final TripModel trip;
  final RideStage stage;

  const RideJobScreen({
    super.key,
    required this.tripId,
    required this.trip,
    required this.stage,
  });

  @override
  State<RideJobScreen> createState() => _RideJobScreenState();
}

class _RideJobScreenState extends State<RideJobScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────
  late TripModel _trip;
  // Passenger basics come with the trip, so render straight away; the
  // remaining details (phone, profile fallback) fill in when fetched.
  bool _isLoading = false;
  String _eta = 'Calculating...';
  double _distKm = 0;

  String _passengerName = 'Passenger';
  String? _passengerPhone;
  String? _passengerPhotoUrl;
  double _passengerRating = 0.0;

  RideStage get _stage => widget.stage;

  // ── Button states ──────────────────────────────
  bool _isWorking = false; // the stage's primary action is in flight
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

  // ── Live driver marker ─────────────────────────
  late final SmoothMarker _driverAnim;
  final ValueNotifier<({LatLng pos, double bearing})> _pose =
      ValueNotifier((pos: const LatLng(5.6037, -0.1870), bearing: 0));
  LatLng? _driverTarget; // latest raw GPS fix
  bool _follow = true; // camera follows until the driver touches the map
  DateTime _lastCam = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Subscriptions ──────────────────────────────
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
    _passengerName = _trip.passengerName;
    _passengerPhotoUrl = _trip.passengerPhotoUrl;
    _passengerRating = _trip.passengerRating;

    _driverAnim = SmoothMarker(
      vsync: this,
      onFrame: (pos, bearing) {
        _driverPos = pos;
        _driverHeading = bearing;
        _pose.value = (pos: pos, bearing: bearing);
        _followCamera();
      },
    );

    _loadPassengerInfo();
    _startTracking();
    // NOTE: no _fetchRoute() here. Before the first GPS fix _driverPos is the
    // Accra placeholder, which drew a bogus route. The first fix triggers it.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do NOT pause GPS here: the driver is usually in the navigation app,
    // and the passenger must keep seeing the live position.
    if (state == AppLifecycleState.resumed) {
      _follow = true;
      _lastCam = DateTime.fromMillisecondsSinceEpoch(0);
      _fitBounds();
    }
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

  // ── Live tracking ─────────────────────────────

  Future<void> _startTracking() async {
    final tracker = TripTracker.instance;
    tracker.position.addListener(_onPosition);
    // Failures can arrive after start() returns (e.g. the background service
    // being refused), so watch for them for as long as this screen is open.
    tracker.problem.addListener(_onTrackingProblem);

    // If the tracker already has a fix (started on the accepted screen),
    // show it right away instead of waiting for the next GPS tick.
    _onPosition();

    // Idempotent: a no-op when already tracking this trip, and it restarts
    // tracking if the app process was killed mid-trip.
    final err = await tracker.start(widget.tripId);
    if (!mounted) return;
    _onTrackingProblem(); // shows err (start() also records it as a problem)
    if (err != null) return;
    _onPosition();
  }

  String? _shownProblem;

  /// Tells the driver when their location is not reaching the passenger,
  /// once per distinct problem.
  void _onTrackingProblem() {
    final problem = TripTracker.instance.problem.value;
    if (!mounted || problem == null || problem == _shownProblem) return;
    _shownProblem = problem;
    _snack(problem, isError: true);
  }

  void _onPosition() {
    final p = TripTracker.instance.position.value;
    if (p == null || !mounted) return;

    final next = LatLng(p.latitude, p.longitude);
    _driverTarget = next;

    if (!_hasFirstGpsFix) {
      setState(() => _hasFirstGpsFix = true); // reveals the driver marker
      _fetchRoute();
    }

    // Rebuild when the driver comes within reach of the target, so the
    // confirm step takes over from navigation as the primary action.
    final near = isNear(_metresToTarget);
    if (near != _wasNear) setState(() => _wasNear = near);

    _driverAnim.moveTo(next, heading: p.heading > 0 ? p.heading : null);

    if (!(_routeRefreshThrottle?.isActive ?? false)) {
      _routeRefreshThrottle = Timer(const Duration(seconds: 20), () {
        if (mounted) _fetchRoute();
      });
    }
  }

  bool _wasNear = false;

  /// Straight-line metres from the latest GPS fix to where this stage
  /// heads, or null before the first fix / while waiting at the pickup.
  double? get _metresToTarget {
    final from = _driverTarget;
    final to = _stage.headsToPickup
        ? _pickupPos
        : _stage.headsToDropoff
            ? _dropoffPos
            : null;
    if (from == null || to == null) return null;
    return distanceMetres(
        from.latitude, from.longitude, to.latitude, to.longitude);
  }

  JobStagePlan get _plan =>
      ridePlan(_stage.step, metresToTarget: _metresToTarget);

  void _followCamera() {
    if (!_follow || !_mapReady || !_hasFirstGpsFix) return;
    final now = DateTime.now();
    if (now.difference(_lastCam).inSeconds < 3) return;
    _lastCam = now;
    _fitBounds();
  }

  Future<void> _fetchRoute() async {
    // Waiting at the pickup: nothing to route to.
    if (!_stage.headsToPickup && !_stage.headsToDropoff) {
      if (_routePolyline.isNotEmpty && mounted) {
        setState(() => _routePolyline = {});
      }
      return;
    }
    try {
      final result = await _routeService.getRoute(
        _driverTarget ?? _driverPos,
        _stage.headsToPickup ? _pickupPos : _dropoffPos,
      );

      if (!mounted) return;
      if (result == null || result.points.isEmpty) return;

      setState(() {
        _routePolyline = {
          Polyline(
            polylineId: PolylineId('ride_${_stage.name}_route'),
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
    } catch (e) {
      debugPrint('❌ _fetchRoute failed: $e');
    }
  }

  /// Confirms the stage's checks for its status step, if it has any.
  /// None of them can be undone and each notifies the passenger, so:
  /// arrival asks only when the driver seems far from the pickup; start
  /// asks whether the passenger is on board; completion keeps its
  /// existing confirmation.
  Future<bool> _confirmStep(JobStagePlan plan) async {
    switch (plan.step.guard) {
      case JobGuard.arrival:
        return confirmArrival(
          context,
          place: 'pickup',
          whoIsTold: 'passenger',
          metresToTarget: _metresToTarget,
        );
      case JobGuard.start:
        return showJobConfirm(
          context,
          title: 'Is the passenger on board?',
          message: 'Start the trip only when the passenger is in your '
              'vehicle. The passenger will be told the trip has started.',
          confirmLabel: 'Start trip',
          keepLabel: 'Not yet',
        );
      case JobGuard.complete:
        return showJobConfirm(
          context,
          title: 'Complete trip?',
          message: 'Have you reached the drop-off location? '
              'This ends the trip.',
          confirmLabel: 'Yes, complete',
        );
      case JobGuard.none:
      case JobGuard.handOver:
        return true;
    }
  }

  /// The stage's one status step: arrive, start or complete.
  Future<void> _handlePrimaryAction() async {
    if (_isWorking) return;
    final plan = _plan;
    // Blocks a second tap while the confirmation is open.
    setState(() => _isWorking = true);
    final confirmed = await _confirmStep(plan);
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _isWorking = false);
      return;
    }
    HapticFeedback.heavyImpact();

    try {
      await applyRideStep(
        _db,
        tripId: widget.tripId,
        driverUid: _uid,
        step: _stage.step,
      );
      debugPrint('✅ Ride step ${_stage.step.name} submitted: ${widget.tripId}');
      final done = plan.step.doneMessage;
      if (done != null) _snack(done, isSuccess: true);
      // TripFlowScreen's listener moves to the next stage (and TripTracker
      // stops itself on completion). Keep the spinner until it does.
    } on RideStepException catch (e) {
      if (mounted) {
        setState(() => _isWorking = false);
        _snack(e.message, isError: true);
      }
    } catch (e) {
      debugPrint('❌ Ride step ${_stage.step.name} failed: $e');
      if (mounted) {
        setState(() => _isWorking = false);
        _snack("Couldn't update the trip. Check your connection and try again.",
            isError: true);
      }
    }
  }

  Future<void> _handleCancelTrip() async {
    if (_isCancelling) return;

    final confirmed = await showJobConfirm(
      context,
      title: 'Cancel this trip?',
      message: _stage == RideStage.atPickup
          ? 'Cancelling after arriving may affect your acceptance rate.'
          : 'Are you sure you want to cancel this trip?',
      confirmLabel: 'Cancel trip',
      keepLabel: 'Keep trip',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      // Re-read the trip in the transaction (same rule as delivery and gas):
      // never overwrite a trip that already ended or was cancelled by the
      // passenger. onTripStatusChanged frees the driver (currentTripId is
      // server-owned).
      final outcome = await _db.runTransaction((txn) async {
        final tripRef = _db.collection('trips').doc(widget.tripId);
        final trip = await txn.get(tripRef);
        final decision = decideDriverCancellation(
          driverUid: _uid,
          orderId: widget.tripId,
          orderExists: trip.exists,
          orderDriverId: trip.data()?['driverId'],
          orderStatus: trip.data()?['status'],
          // Unchanged policy: the driver may cancel before completion.
          cancellableStatuses: const {
            'tripAccepted',
            'driverArrived',
            'tripStarted',
          },
          cancelledStatus: 'cancelledByDriver',
          driverCurrentTripId: null,
        );
        if (decision.cancelOrder) {
          txn.update(tripRef, {
            'status': 'cancelledByDriver',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        }
        return decision.outcome;
      });
      if (outcome == DriverCancelOutcome.notCancellable ||
          outcome == DriverCancelOutcome.notAssignedToDriver) {
        // The trip moved on (e.g. the passenger cancelled or it completed);
        // TripFlowScreen shows its real state.
        if (mounted) {
          setState(() => _isCancelling = false);
          _snack('This trip can no longer be cancelled.', isError: true);
        }
        return;
      }
      await TripTracker.instance.stop();
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

  void _snack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          // White text: primaryDeep 7.1:1, danger 4.8:1.
          backgroundColor: isSuccess
              ? AppTheme.primaryDeep
              : isError
                  ? AppTheme.danger
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
    // Deliberately NOT stopping TripTracker: it stops itself when the trip
    // reaches a terminal status, and on cancel (above).
    TripTracker.instance.position.removeListener(_onPosition);
    TripTracker.instance.problem.removeListener(_onTrackingProblem);
    _driverAnim.dispose();
    _pose.dispose();
    _routeRefreshThrottle?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final plan = _plan;
    final destination = switch (_stage) {
      RideStage.toPickup || RideStage.atPickup => (
          'Pickup',
          _trip.pickupAddress
        ),
      RideStage.onTrip => ('Drop-off', _trip.dropoffAddress),
    };
    return JobMapLayout(
      plan: plan,
      destinationLabel: destination.$1,
      destination: destination.$2,
      eta: _summaryEta,
      onBack: () => Navigator.pop(context),
      onRecenter: () {
        _follow = true;
        _lastCam = DateTime.fromMillisecondsSinceEpoch(0);
        _fitBounds();
      },
      // Only the map rebuilds on animation frames; a touch on the map turns
      // off camera-follow.
      mapBuilder: (context, padding) => Listener(
        onPointerDown: (_) => _follow = false,
        child: ValueListenableBuilder(
          valueListenable: _pose,
          builder: (_, pose, __) => TripMap(
            controller: _mapController,
            onMapCreated: (c) {
              _mapController = c;
              setState(() => _mapReady = true);
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) _fitBounds();
              });
            },
            driverPos: pose.pos,
            pickupPos: _pickupPos,
            dropoffPos: _dropoffPos,
            driverHeading: pose.bearing,
            serviceType: _trip.serviceType,
            polylines: _routePolyline,
            // No marker parked in central Accra before the first fix.
            showDriver: _hasFirstGpsFix,
            padding: padding,
          ),
        ),
      ),
      details: [
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
          eta: _stage == RideStage.atPickup ? '—' : _eta,
          distanceKm: _distKm,
          fare: _trip.finalFare ?? _trip.fare,
        ),
        const _Divider(),
        // Kept apart from the stage's actions on purpose.
        JobCancelLink(
          label: 'Cancel trip',
          busy: _isCancelling,
          onTap: _handleCancelTrip,
        ),
      ],
      actions: JobStageActions(
        plan: plan,
        busy: _isWorking,
        onStep: _handlePrimaryAction,
        onNavigate: plan.target == null
            ? null
            : () => openExternalNavigation(
                  plan.target == JobTarget.pickup ? _pickupPos : _dropoffPos,
                ),
      ),
    );
  }

  /// The route service's ETA and distance to this stage's target, once a
  /// route has been fetched. Nothing while waiting at the pickup.
  String? get _summaryEta {
    if (_stage == RideStage.atPickup || _distKm <= 0) return null;
    return '$_eta · ${_distKm.toStringAsFixed(1)} km';
  }

  /// Pickup and drop-off; the one this stage heads to is emphasised.
  Widget _buildRouteRow() {
    final toDropoff = _stage.headsToDropoff;
    return Column(
      children: [
        _RidePlaceRow(
          icon: Icons.trip_origin_rounded,
          iconColor: AppTheme.primaryDark,
          label: 'Pickup',
          address: _trip.pickupAddress,
          current: !toDropoff,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 14, color: AppTheme.divider),
          ),
        ),
        _RidePlaceRow(
          icon: Icons.location_on_rounded,
          iconColor: AppTheme.danger,
          label: 'Drop-off',
          address: _trip.dropoffAddress,
          current: toDropoff,
        ),
      ],
    );
  }

  void _fitBounds() {
    if (!_mapReady || _mapController == null) return;

    // Before the first fix there is no real driver position: frame the whole
    // trip. After that, frame the driver and where they are heading (the
    // pickup until the trip starts, then the drop-off).
    final target = _stage.headsToDropoff ? _dropoffPos : _pickupPos;
    final points = _hasFirstGpsFix
        ? <LatLng>[_driverPos, target]
        : <LatLng>[_pickupPos, _dropoffPos];

    final minLat = points.map((p) => p.latitude).reduce(min);
    final maxLat = points.map((p) => p.latitude).reduce(max);
    final minLng = points.map((p) => p.longitude).reduce(min);
    final maxLng = points.map((p) => p.longitude).reduce(max);

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();

    // Prevent Google Maps from receiving an invalid/too-small bounds.
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    final latPadding = latDiff * 0.15;
    final lngPadding = lngDiff * 0.15;

    final sw = LatLng(minLat - latPadding, minLng - lngPadding);
    final ne = LatLng(maxLat + latPadding, maxLng + lngPadding);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 28, thickness: 1, color: AppTheme.divider);
  }
}

class _RidePlaceRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  /// Where the current stage is heading: larger and bolder.
  final bool current;

  const _RidePlaceRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: current ? 16 : 14.5,
                  height: 1.35,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: current
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
