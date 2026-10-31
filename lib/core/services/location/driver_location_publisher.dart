// lib/core/services/location/driver_location_publisher.dart
//
// The single owner of the driver's GPS stream for active jobs.
//
// Active-job mode publishes the driver's position to the job document of the
// job they are doing (Ride now; Delivery and Gas migrate to it next), through
// geolocator's foreground service so updates continue while the driver uses
// Google Maps. It never creates a job or changes a job's status.
//
// Safeguards:
//  • Before publishing it reads the stored job and only proceeds when the
//    signed-in driver is assigned and the job has not ended.
//  • It watches the job and stops by itself when it ends or is reassigned.
//  • Every stream subscription and write carries a session number, so a late
//    callback from an earlier job can never write to it or to a newer job.
//  • Starting the same job again is a no-op; starting another job replaces
//    the current one, so there is never more than one GPS stream here.
//  • Failures after start() returned are published on [problem] so screens
//    never report healthy tracking that is not happening.
//
//
// It also owns online-idle tracking (from DriverRuntimeService): there is only
// ever ONE GPS subscription, either the idle stream (no foreground service,
// best effort: Android may throttle it heavily in the background) or the
// active job's stream. Every accepted fix also updates the driver profile
// (drivers/{uid}: location, currentLocation, lastSeen, lastLocationUpdate) on
// its own throttle, which never delays job writes, so dispatch,
// syncDriverMap and the admin live map keep a current position during jobs.

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Configuration (centralised; change cadences here only)
// ─────────────────────────────────────────────────────────────────────────────

/// How often a job document receives a position.
class LocationCadence {
  /// Minimum time between writes (leading edge: always the latest fix).
  final Duration minInterval;

  /// GPS distance filter in metres.
  final int distanceFilterM;

  const LocationCadence(this.minInterval, this.distanceFilterM);
}

/// Driver-profile (drivers/{uid}) write throttle: a fix is written when this
/// much time has passed OR the driver moved this far since the last
/// SUCCESSFUL profile write, whichever comes first.
const Duration profileMinInterval = Duration(seconds: 30);
const double profileMinDistanceM = 50;

/// GPS distance filter of the idle (online, no job) stream. Unchanged from
/// DriverRuntimeService.
const int idleDistanceFilterM = 10;

/// Great-circle distance in metres. Pure, for tests.
double distanceMetres(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Whether a fix should be written to the driver profile. Pure, for tests.
bool shouldWriteProfile({
  required DateTime now,
  required DateTime? lastWriteAt,
  required ({double lat, double lng})? lastWritePos,
  required double lat,
  required double lng,
}) {
  if (lastWriteAt == null || lastWritePos == null) return true;
  if (now.difference(lastWriteAt) >= profileMinInterval) return true;
  return distanceMetres(lastWritePos.lat, lastWritePos.lng, lat, lng) >=
      profileMinDistanceM;
}

/// The fields written to the driver profile for one position. Same names and
/// meaning as DriverRuntimeService always wrote. Pure, for tests.
Map<String, Object> profileLocationFields(
  Position p, {
  required Object serverTimestamp,
}) =>
    {
      'location': GeoPoint(p.latitude, p.longitude),
      'currentLocation': GeoPoint(p.latitude, p.longitude),
      'lastSeen': serverTimestamp,
      'lastLocationUpdate': serverTimestamp,
    };

/// One active-job kind and everything that differs between services.
enum ActiveJobKind {
  ride(
    collection: 'trips',
    // Statuses after which the trip no longer needs the driver's position.
    terminalStatuses: {
      'completed',
      'cancelledByDriver',
      'cancelledByPassenger',
      'expired',
      'noDriversAvailable',
      'cancelled',
    },
    cadence: LocationCadence(Duration(seconds: 2), 3),
    notificationText: 'Sharing your location for the active trip',
    // Unchanged from the existing Ride tracker.
    wakeLock: true,
    legacyTimestampField: null,
    writesSpeed: true,
  ),
  delivery(
    collection: 'deliveries',
    terminalStatuses: {
      'completed',
      'cancelled',
      'cancelledByDriver',
      'cancelledByPassenger',
    },
    cadence: LocationCadence(Duration(seconds: 5), 15),
    notificationText: 'Sharing your location for the active delivery',
    wakeLock: false,
    legacyTimestampField: 'driverLocationUpdatedAt',
    writesSpeed: false,
  ),
  gas(
    collection: 'gas_orders',
    terminalStatuses: {'delivered', 'cancelled', 'failed'},
    cadence: LocationCadence(Duration(seconds: 5), 15),
    notificationText: 'Sharing your location for the active gas order',
    wakeLock: false,
    legacyTimestampField: 'driverLocationUpdatedAt',
    writesSpeed: false,
  );

  final String collection;
  final Set<String> terminalStatuses;
  final LocationCadence cadence;
  final String notificationText;
  final bool wakeLock;

  /// Timestamp field older Passenger versions expect, written alongside
  /// `lastLocationUpdate` (null when the job has none).
  final String? legacyTimestampField;
  final bool writesSpeed;

  const ActiveJobKind({
    required this.collection,
    required this.terminalStatuses,
    required this.cadence,
    required this.notificationText,
    required this.wakeLock,
    required this.legacyTimestampField,
    required this.writesSpeed,
  });
}

/// The fields written to a job document for one position. Pure, for tests.
Map<String, Object> jobLocationFields(
  ActiveJobKind kind,
  Position p, {
  required Object serverTimestamp,
}) =>
    {
      'driverCurrentLocation': GeoPoint(p.latitude, p.longitude),
      if (p.heading > 0) 'driverHeading': p.heading,
      if (kind.writesSpeed) 'driverSpeed': p.speed,
      'lastLocationUpdate': serverTimestamp,
      if (kind.legacyTimestampField != null)
        kind.legacyTimestampField!: serverTimestamp,
    };

/// Why the driver may not publish to this job, or null when they may.
/// Pure, for tests.
String? jobPublishRefusal({
  required ActiveJobKind kind,
  required bool exists,
  required String? status,
  required String? assignedDriverId,
  required String driverUid,
}) {
  if (!exists) return 'This job no longer exists.';
  if (driverUid.isEmpty || assignedDriverId != driverUid) {
    return 'This job is not assigned to you.';
  }
  if (status == null || kind.terminalStatuses.contains(status)) {
    return 'This job has already ended.';
  }
  return null;
}

/// Driver-facing message for a location stream error. Pure, for tests.
String trackerProblemFor(Object e) {
  if (e is PermissionDeniedException) {
    return 'Location permission was turned off. Enable it to keep sharing '
        'your location.';
  }
  if (e is LocationServiceDisabledException) {
    return 'Location is turned off. Turn it on to keep sharing your location.';
  }
  final text = e is PlatformException ? '${e.code} ${e.message}' : '$e';
  if (text.contains('startForeground') ||
      text.contains('FOREGROUND_SERVICE') ||
      text.contains('SecurityException')) {
    return "Background location sharing couldn't start. Keep CTS Go open so "
        'the passenger can follow you.';
  }
  return 'Location sharing stopped unexpectedly. Reopen the job to retry.';
}

// ─────────────────────────────────────────────────────────────────────────────
// Ports (real implementations below; fakes in tests)
// ─────────────────────────────────────────────────────────────────────────────

abstract class LocationSource {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<Position?> lastKnownPosition();

  /// One fresh fix (used on app resume); null when unavailable.
  Future<Position?> currentPosition();

  /// The GPS stream for [kind], or the idle stream when [kind] is null.
  Stream<Position> positions(ActiveJobKind? kind);
}

/// Snapshot of the fields the publisher needs from a job document.
class JobSnapshot {
  final bool exists;
  final String? status;
  final String? driverId;
  const JobSnapshot({required this.exists, this.status, this.driverId});
}

abstract class JobLocationStore {
  Future<JobSnapshot> read(String collection, String jobId);
  Stream<JobSnapshot> watch(String collection, String jobId);
  Future<void> writeLocation(
      ActiveJobKind kind, String jobId, Position position);

  /// Merges the position into drivers/{uid} (see profileLocationFields).
  Future<void> writeProfileLocation(String uid, Position position);
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
  @override
  Future<Position?> lastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Location publisher: no fresh fix on resume: $e');
      return null;
    }
  }

  @override
  Stream<Position> positions(ActiveJobKind? kind) =>
      Geolocator.getPositionStream(
        locationSettings: kind == null
            // Idle: unchanged from DriverRuntimeService (no foreground
            // service; Android may throttle it while backgrounded).
            ? const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: idleDistanceFilterM,
              )
            : _settings(kind),
      );

  LocationSettings _settings(ActiveJobKind kind) {
    final c = kind.cadence;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: c.distanceFilterM,
        intervalDuration: c.minInterval,
        // A visible notification for as long as the job shares location;
        // geolocator removes it when the stream is cancelled.
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'CTS Go Driver',
          notificationText: kind.notificationText,
          enableWakeLock: kind.wakeLock,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: c.distanceFilterM,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: c.distanceFilterM);
  }
}

class FirestoreJobLocationStore implements JobLocationStore {
  final FirebaseFirestore _db;
  FirestoreJobLocationStore([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  JobSnapshot _snap(DocumentSnapshot<Map<String, dynamic>> s) => JobSnapshot(
        exists: s.exists,
        status: s.data()?['status'] as String?,
        driverId: s.data()?['driverId'] as String?,
      );

  // Server when reachable, cached copy offline (so a reopened job can resume
  // with a weak signal); watch() then reconciles with the stored status and
  // stops publishing if the job has in fact ended or been reassigned.
  @override
  Future<JobSnapshot> read(String collection, String jobId) async =>
      _snap(await _db.collection(collection).doc(jobId).get());

  @override
  Stream<JobSnapshot> watch(String collection, String jobId) =>
      _db.collection(collection).doc(jobId).snapshots().map(_snap);

  @override
  Future<void> writeLocation(
          ActiveJobKind kind, String jobId, Position position) =>
      _db.collection(kind.collection).doc(jobId).update(jobLocationFields(
          kind, position,
          serverTimestamp: FieldValue.serverTimestamp()));

  @override
  Future<void> writeProfileLocation(String uid, Position position) =>
      _db.collection('drivers').doc(uid).set(
          profileLocationFields(position,
              serverTimestamp: FieldValue.serverTimestamp()),
          SetOptions(merge: true));
}

// ─────────────────────────────────────────────────────────────────────────────
// Publisher
// ─────────────────────────────────────────────────────────────────────────────

class ActiveJobRef {
  final ActiveJobKind kind;
  final String jobId;
  const ActiveJobRef(this.kind, this.jobId);

  @override
  bool operator ==(Object other) =>
      other is ActiveJobRef && other.kind == kind && other.jobId == jobId;
  @override
  int get hashCode => Object.hash(kind, jobId);
  @override
  String toString() => '${kind.name}/$jobId';
}

class DriverLocationPublisher with WidgetsBindingObserver {
  DriverLocationPublisher({
    LocationSource? source,
    JobLocationStore? store,
    String Function()? driverUid,
    DateTime Function()? now,
    bool observeLifecycle = true,
  })  : _source = source ?? const GeolocatorLocationSource(),
        _storeOverride = store,
        _driverUid =
            driverUid ?? (() => FirebaseAuth.instance.currentUser?.uid ?? ''),
        _now = now ?? DateTime.now,
        _observeLifecycle = observeLifecycle;

  static final DriverLocationPublisher instance = DriverLocationPublisher();

  final LocationSource _source;
  final JobLocationStore? _storeOverride;
  JobLocationStore? _defaultStore;
  JobLocationStore get _store =>
      _storeOverride ?? (_defaultStore ??= FirestoreJobLocationStore());
  final String Function() _driverUid;
  final DateTime Function() _now;
  final bool _observeLifecycle;
  bool _observing = false;

  /// Latest GPS fix from whichever stream is running (screens read; never
  /// own).
  final ValueNotifier<Position?> position = ValueNotifier(null);

  /// Why active-job location sharing is not working, or null while healthy.
  final ValueNotifier<String?> problem = ValueNotifier(null);

  // ── State ──────────────────────────────────────────────────────────────
  /// The driver is online: idle publishing is wanted whenever no job runs.
  bool _online = false;
  ActiveJobRef? _job;

  /// Incremented whenever the GPS subscription is replaced or stopped; every
  /// callback and write checks it, so late callbacks can never write.
  int _session = 0;

  /// Incremented by every job start/stop: a start that finishes after a newer
  /// start or a stop is discarded. Separate from [_session] so a refused
  /// start never invalidates the stream that is already running.
  int _startGen = 0;
  StreamSubscription<Position>? _gps;
  StreamSubscription<JobSnapshot>? _jobWatch;
  DateTime _lastJobWrite = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastProfileWriteAt;
  ({double lat, double lng})? _lastProfileWritePos;
  bool _profileWriteInFlight = false;
  Future<String?>? _starting;
  ActiveJobRef? _startingJob;

  /// The job currently receiving positions, if any.
  ActiveJobRef? get activeJob => _gps == null ? null : _job;

  /// True while the idle (online, no job) stream is running.
  bool get isIdleTracking => _gps != null && _job == null;

  /// Number of GPS subscriptions this publisher holds (0 or 1).
  int get subscriptionCount => _gps == null ? 0 : 1;

  // ── Online idle ────────────────────────────────────────────────────────

  /// The driver is online: publish their position to the profile whenever no
  /// job is running. Idempotent. Best effort only: there is no foreground
  /// service for idle tracking, so Android may throttle it in the background.
  /// Returns null on success or the reason tracking could not start.
  Future<String?> startIdle() async {
    _online = true;
    _ensureObserving();
    if (_gps != null) return null; // job or idle stream already running
    return _openIdleStream();
  }

  /// Records a profile write made outside the publisher (DriverRuntimeService
  /// writes the first fix together with the online flags), so the throttle
  /// does not immediately write the same position again.
  void noteProfileWritten(double lat, double lng) {
    _lastProfileWriteAt = _now();
    _lastProfileWritePos = (lat: lat, lng: lng);
  }

  /// The driver went offline: stop idle publishing. An active job keeps its
  /// own stream (it still needs the customer to see the driver).
  Future<void> stopIdle() async {
    _online = false;
    if (_job == null) await _closeStream();
  }

  /// Sign-out: stop everything (idle and any active job).
  Future<void> stopAll() async {
    _online = false;
    _startGen++;
    _job = null;
    await _closeStream();
  }

  Future<String?> _openIdleStream() async {
    final reason = await _checkLocationAccess();
    if (reason != null) {
      debugPrint('Location publisher: idle tracking not started: $reason');
      return reason;
    }
    if (_gps != null || !_online) return null; // changed while checking
    final session = ++_session;
    _gps = _source.positions(null).listen(
          (p) => _onPosition(session, p),
          onError: (Object e) =>
              debugPrint('Location publisher idle GPS error: $e'),
        );
    return null;
  }

  // ── Active job ─────────────────────────────────────────────────────────

  /// Starts (or keeps) publishing for [jobId]. Returns null on success or a
  /// message the UI can show. Idempotent for the job already running.
  Future<String?> startJob(ActiveJobKind kind, String jobId) {
    final ref = ActiveJobRef(kind, jobId);
    if (_gps != null && _job == ref) return Future.value(null);
    // Coalesce concurrent starts for the same job (rapid screen rebuilds).
    if (_starting != null && _startingJob == ref) return _starting!;
    _startingJob = ref;
    final f = _start(ref).whenComplete(() {
      if (_startingJob == ref) {
        _starting = null;
        _startingJob = null;
      }
    });
    _starting = f;
    return f;
  }

  Future<String?> _start(ActiveJobRef ref) async {
    _ensureObserving();
    final generation = ++_startGen; // supersedes any start still in flight
    problem.value = null;

    // Ownership from the stored job, not a cached screen copy.
    final JobSnapshot snap;
    try {
      snap = await _store.read(ref.kind.collection, ref.jobId);
    } catch (e) {
      debugPrint('Location publisher: could not verify $ref: $e');
      return problem.value =
          "Couldn't confirm this job. Check your connection and reopen it.";
    }
    if (generation != _startGen) return null; // superseded while reading
    final refusal = jobPublishRefusal(
      kind: ref.kind,
      exists: snap.exists,
      status: snap.status,
      assignedDriverId: snap.driverId,
      driverUid: _driverUid(),
    );
    if (refusal != null) {
      debugPrint('Location publisher: not starting $ref: $refusal');
      return refusal; // not a tracking fault: nothing to share for this job
    }

    final access = await _checkLocationAccess(request: true);
    if (access != null) return problem.value = access;
    if (generation != _startGen) return null;

    // Replace whatever stream is running (idle or another job) with this
    // job's: never two subscriptions.
    await _closeStream();
    final session = ++_session;
    _job = ref;

    // Show and publish something immediately instead of waiting for a fix.
    final last = await _source.lastKnownPosition();
    if (session != _session) return null;
    if (last != null) {
      position.value = last;
      _lastJobWrite = _now();
      unawaited(_writeJob(session, ref, last));
    }

    _gps = _source.positions(ref.kind).listen(
          (p) => _onPosition(session, p),
          onError: (Object e) => _onStreamError(session, e),
        );

    // Stop by itself when the job ends or is no longer this driver's.
    _jobWatch = _store.watch(ref.kind.collection, ref.jobId).listen((s) {
      if (session != _session) return;
      final reason = jobPublishRefusal(
        kind: ref.kind,
        exists: s.exists,
        status: s.status,
        assignedDriverId: s.driverId,
        driverUid: _driverUid(),
      );
      if (reason != null) {
        debugPrint('Location publisher: stopping $ref: $reason');
        stopJob();
      }
    });

    return null;
  }

  /// Stops publishing for the current job. If the driver is still online the
  /// idle stream takes over at once, so the profile does not go stale just
  /// because a job ended or a screen changed.
  Future<void> stopJob() async {
    if (_job == null && _starting == null) return;
    _startGen++; // cancels a start still in flight
    _job = null;
    await _closeStream();
    if (_online) await _openIdleStream();
  }

  // ── Shared plumbing ────────────────────────────────────────────────────

  Future<void> _closeStream() async {
    _session++; // invalidates every pending callback and write
    final gps = _gps;
    final watch = _jobWatch;
    _gps = null;
    _jobWatch = null;
    await gps?.cancel();
    await watch?.cancel();
  }

  Future<String?> _checkLocationAccess({bool request = true}) async {
    var perm = await _source.checkPermission();
    if (perm == LocationPermission.denied && request) {
      perm = await _source.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Location permission denied. Enable it in Settings.';
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission is required.';
    }
    if (!await _source.isLocationServiceEnabled()) {
      return 'Please enable location services.';
    }
    return null;
  }

  void _onStreamError(int session, Object e) {
    if (session != _session) return;
    debugPrint('Location publisher GPS error: $e');
    problem.value = trackerProblemFor(e);
  }

  /// One accepted fix: job write on the job's own throttle, profile write on
  /// the profile throttle. The two never delay each other.
  void _onPosition(int session, Position p, {bool forceProfile = false}) {
    if (session != _session) return; // late callback from an older stream
    position.value = p;
    final now = _now();
    final job = _job;
    if (job != null &&
        now.difference(_lastJobWrite) >= job.kind.cadence.minInterval) {
      _lastJobWrite = now;
      unawaited(_writeJob(session, job, p));
    }
    if (forceProfile ||
        shouldWriteProfile(
          now: now,
          lastWriteAt: _lastProfileWriteAt,
          lastWritePos: _lastProfileWritePos,
          lat: p.latitude,
          lng: p.longitude,
        )) {
      unawaited(_writeProfile(session, p, now));
    }
  }

  Future<void> _writeJob(int session, ActiveJobRef ref, Position p) async {
    if (session != _session || _job != ref) return;
    try {
      await _store.writeLocation(ref.kind, ref.jobId, p);
    } catch (e) {
      // Never swallow: a failed write == a frozen marker for the customer.
      debugPrint('Location publisher write failed for $ref: $e');
      if (session == _session) {
        problem.value = "Your location isn't reaching the customer. "
            'Check your connection.';
      }
    }
  }

  Future<void> _writeProfile(int session, Position p, DateTime at) async {
    final uid = _driverUid();
    if (uid.isEmpty || session != _session || _profileWriteInFlight) return;
    _profileWriteInFlight = true;
    try {
      await _store.writeProfileLocation(uid, p);
      // Only a SUCCESSFUL write moves the throttle: a failed write must not
      // make the driver look freshly located.
      _lastProfileWriteAt = at;
      _lastProfileWritePos = (lat: p.latitude, lng: p.longitude);
    } catch (e) {
      debugPrint('Driver profile location update failed: $e');
    } finally {
      _profileWriteInFlight = false;
    }
  }

  // ── App lifecycle ──────────────────────────────────────────────────────

  void _ensureObserving() {
    if (_observing || !_observeLifecycle) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshNow());
  }

  /// One immediate fix through the current owner (no new subscription):
  /// published to the active job (on its throttle) and to the profile
  /// (bypassing the profile throttle). No-op when not tracking.
  Future<void> refreshNow() async {
    final session = _session;
    if (_gps == null) {
      // Online but the idle stream is not running (e.g. it failed to start
      // earlier, or the app was relaunched): try to start it once.
      if (_online) await _openIdleStream();
      return;
    }
    final p = await _source.currentPosition();
    if (p == null || session != _session) return;
    _onPosition(session, p, forceProfile: true);
  }
}
