// DriverLocationPublisher: one GPS stream, published only to a job the
// driver owns and that has not ended, never after the job moves on.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/core/services/location/driver_location_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position fix(double lat, {double heading = 90, double speed = 4}) => Position(
      latitude: lat,
      longitude: -0.18,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

class FakeSource implements LocationSource {
  LocationPermission permission = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  Position? lastKnown;
  Position? current;
  final controllers = <StreamController<Position>>[];
  final kinds = <ActiveJobKind?>[];
  int get listening => controllers.where((c) => c.hasListener).length;

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  Future<Position?> lastKnownPosition() async => lastKnown;
  @override
  Future<Position?> currentPosition() async => current;
  @override
  Stream<Position> positions(ActiveJobKind? kind) {
    final c = StreamController<Position>();
    controllers.add(c);
    kinds.add(kind);
    return c.stream;
  }

  void emit(Position p) => controllers.last.add(p);
}

class FakeStore implements JobLocationStore {
  final docs = <String, JobSnapshot>{};
  final watchers = <String, StreamController<JobSnapshot>>{};
  final writes = <(ActiveJobKind, String, Position)>[];
  final profileWrites = <(String, Position)>[];
  bool failProfileWrites = false;
  bool failWrites = false;
  int reads = 0;

  String key(String c, String id) => '$c/$id';
  void put(String c, String id, {String? status, String? driverId = 'd1'}) =>
      docs[key(c, id)] =
          JobSnapshot(exists: true, status: status, driverId: driverId);
  void change(String c, String id, {String? status, String? driverId = 'd1'}) {
    put(c, id, status: status, driverId: driverId);
    watchers[key(c, id)]?.add(docs[key(c, id)]!);
  }

  @override
  Future<JobSnapshot> read(String c, String id) async {
    reads++;
    return docs[key(c, id)] ?? const JobSnapshot(exists: false);
  }

  @override
  Stream<JobSnapshot> watch(String c, String id) =>
      (watchers[key(c, id)] = StreamController<JobSnapshot>.broadcast()).stream;

  @override
  Future<void> writeLocation(ActiveJobKind k, String id, Position p) async {
    if (failWrites) throw Exception('PERMISSION_DENIED');
    writes.add((k, id, p));
  }

  @override
  Future<void> writeProfileLocation(String uid, Position p) async {
    if (failProfileWrites) throw Exception('unavailable');
    profileWrites.add((uid, p));
  }
}

void main() {
  late FakeSource source;
  late FakeStore store;
  late DateTime clock;
  late DriverLocationPublisher pub;

  setUp(() {
    source = FakeSource();
    store = FakeStore();
    clock = DateTime(2026, 10, 13, 12);
    pub = DriverLocationPublisher(
      source: source,
      store: store,
      driverUid: () => 'd1',
      now: () => clock,
      observeLifecycle: false,
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('ownership and status', () {
    test('publishes to an active trip assigned to the driver', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      expect(await pub.startJob(ActiveJobKind.ride, 't1'), isNull);
      source.emit(fix(5.6));
      await settle();
      expect(store.writes.single.$2, 't1');
      expect(pub.activeJob, const ActiveJobRef(ActiveJobKind.ride, 't1'));
    });

    test("refuses another driver's job and does not open GPS", () async {
      store.put('trips', 't1', status: 'tripAccepted', driverId: 'other');
      expect(await pub.startJob(ActiveJobKind.ride, 't1'), isNotNull);
      expect(source.controllers, isEmpty);
      expect(pub.activeJob, isNull);
    });

    test('refuses a missing job', () async {
      expect(await pub.startJob(ActiveJobKind.ride, 'nope'), isNotNull);
      expect(source.controllers, isEmpty);
    });

    for (final kind in ActiveJobKind.values) {
      for (final status in kind.terminalStatuses) {
        test('${kind.name}: does not start for "$status"', () async {
          store.put(kind.collection, 'j', status: status);
          expect(await pub.startJob(kind, 'j'), isNotNull);
          expect(source.controllers, isEmpty);
        });

        test('${kind.name}: stops when the job becomes "$status"', () async {
          store.put(kind.collection, 'j', status: 'active');
          await pub.startJob(kind, 'j');
          store.change(kind.collection, 'j', status: status);
          await settle();
          expect(pub.activeJob, isNull);
          expect(source.listening, 0);
        });
      }
    }

    test('stops when the job is reassigned to another driver', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      store.change('trips', 't1', status: 'tripStarted', driverId: 'other');
      await settle();
      expect(pub.activeJob, isNull);
    });

    test('never writes a status or creates a job', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      source.emit(fix(5.6));
      await settle();
      final fields = jobLocationFields(ActiveJobKind.ride, fix(5.6),
          serverTimestamp: 'ts');
      expect(fields.containsKey('status'), isFalse);
      expect(store.docs.length, 1);
    });
  });

  group('one stream, idempotent', () {
    test('starting the same job again does not open a second stream', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      await pub.startJob(ActiveJobKind.ride, 't1');
      expect(source.controllers.length, 1);
    });

    test('concurrent starts for the same job coalesce', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      await Future.wait([
        pub.startJob(ActiveJobKind.ride, 't1'),
        pub.startJob(ActiveJobKind.ride, 't1'),
      ]);
      expect(source.controllers.length, 1);
      expect(source.listening, 1);
    });

    test('a new job replaces the old stream (never two at once)', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      store.put('trips', 't2', status: 'tripAccepted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      await pub.startJob(ActiveJobKind.ride, 't2');
      expect(source.listening, 1);
      expect(pub.activeJob!.jobId, 't2');
    });

    test('a late fix from the previous job is never written', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      store.put('trips', 't2', status: 'tripAccepted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      final oldStream = source.controllers.first;
      await pub.startJob(ActiveJobKind.ride, 't2');
      clock = clock.add(const Duration(seconds: 10));
      if (!oldStream.isClosed) oldStream.add(fix(1.0)); // stale callback
      await settle();
      expect(store.writes.where((w) => w.$2 == 't1'), isEmpty);
    });

    test('stopJob is safe to call when idle and twice', () async {
      await pub.stopJob();
      await pub.stopJob();
      expect(pub.activeJob, isNull);
    });
  });

  group('cadence and fields', () {
    test('ride writes at most every 2 s, always the latest fix', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      source.emit(fix(5.60));
      await settle();
      clock = clock.add(const Duration(milliseconds: 500));
      source.emit(fix(5.61)); // inside the window: not written
      await settle();
      clock = clock.add(const Duration(seconds: 2));
      source.emit(fix(5.62));
      await settle();
      expect(store.writes.map((w) => w.$3.latitude), [5.60, 5.62]);
    });

    test('delivery and gas keep their 5 s / 15 m cadence', () {
      for (final k in [ActiveJobKind.delivery, ActiveJobKind.gas]) {
        expect(k.cadence.minInterval, const Duration(seconds: 5));
        expect(k.cadence.distanceFilterM, 15);
        expect(k.wakeLock, isFalse);
      }
      expect(
          ActiveJobKind.ride.cadence.minInterval, const Duration(seconds: 2));
      expect(ActiveJobKind.ride.cadence.distanceFilterM, 3);
      expect(ActiveJobKind.ride.wakeLock, isTrue);
    });

    test('ride writes its existing fields only', () {
      final f = jobLocationFields(ActiveJobKind.ride, fix(5.6),
          serverTimestamp: 'ts');
      expect(f.keys.toSet(), {
        'driverCurrentLocation',
        'driverHeading',
        'driverSpeed',
        'lastLocationUpdate',
      });
      expect(f['driverCurrentLocation'], const GeoPoint(5.6, -0.18));
    });

    test('delivery and gas keep the legacy timestamp and add the new one', () {
      for (final k in [ActiveJobKind.delivery, ActiveJobKind.gas]) {
        final f = jobLocationFields(k, fix(5.6), serverTimestamp: 'ts');
        expect(f['driverLocationUpdatedAt'], 'ts');
        expect(f['lastLocationUpdate'], 'ts');
        expect(f.containsKey('driverHeading'), isTrue);
        expect(f.containsKey('driverSpeed'), isFalse);
      }
    });

    test('no heading is written when the fix has none', () {
      final f = jobLocationFields(ActiveJobKind.ride, fix(5.6, heading: 0),
          serverTimestamp: 'ts');
      expect(f.containsKey('driverHeading'), isFalse);
    });

    test('notification wording per service', () {
      expect(ActiveJobKind.ride.notificationText,
          'Sharing your location for the active trip');
      expect(ActiveJobKind.delivery.notificationText,
          'Sharing your location for the active delivery');
      expect(ActiveJobKind.gas.notificationText,
          'Sharing your location for the active gas order');
    });
  });

  group('failures are reported, never hidden', () {
    setUp(() => store.put('trips', 't1', status: 'tripAccepted'));

    test('permission denied', () async {
      source.permission = LocationPermission.deniedForever;
      expect(await pub.startJob(ActiveJobKind.ride, 't1'), isNotNull);
      expect(pub.problem.value, isNotNull);
      expect(source.controllers, isEmpty);
    });

    test('location services off', () async {
      source.serviceEnabled = false;
      expect(await pub.startJob(ActiveJobKind.ride, 't1'), isNotNull);
      expect(pub.problem.value, contains('location services'));
    });

    test('a stream error after start (e.g. refused foreground service)',
        () async {
      await pub.startJob(ActiveJobKind.ride, 't1');
      expect(pub.problem.value, isNull);
      source.controllers.last.addError(Exception(
          'Permission Denial: startForeground requires FOREGROUND_SERVICE'));
      await settle();
      expect(pub.problem.value, contains('Background location sharing'));
    });

    test('a failed write', () async {
      store.failWrites = true;
      await pub.startJob(ActiveJobKind.ride, 't1');
      source.emit(fix(5.6));
      await settle();
      expect(pub.problem.value, contains("isn't reaching"));
    });

    test('a new start clears the previous problem', () async {
      source.serviceEnabled = false;
      await pub.startJob(ActiveJobKind.ride, 't1');
      source.serviceEnabled = true;
      await pub.startJob(ActiveJobKind.ride, 't1');
      expect(pub.problem.value, isNull);
    });
  });

  group('delivery (migrated)', () {
    test('lifecycle: start, publish, stop on completion', () async {
      store.put('deliveries', 'dl1', status: 'pickupEnroute');
      expect(await pub.startJob(ActiveJobKind.delivery, 'dl1'), isNull);
      source.emit(fix(5.6));
      await settle();
      expect(store.writes.single.$1, ActiveJobKind.delivery);
      expect(store.writes.single.$2, 'dl1');
      store.change('deliveries', 'dl1', status: 'completed');
      await settle();
      expect(pub.activeJob, isNull);
      expect(source.listening, 0, reason: 'notification is removed with it');
    });

    test('stops on cancellation by either party', () async {
      for (final status in ['cancelledByDriver', 'cancelledByPassenger']) {
        store.put('deliveries', 'dl1', status: 'packagePicked');
        await pub.startJob(ActiveJobKind.delivery, 'dl1');
        store.change('deliveries', 'dl1', status: status);
        await settle();
        expect(pub.activeJob, isNull, reason: status);
      }
    });

    test('keeps publishing through every non-final stage', () async {
      store.put('deliveries', 'dl1', status: 'driverAssigned');
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      for (final s in [
        'pickupEnroute',
        'arrivedAtPickup',
        'packagePicked',
        'deliveryEnroute',
        'arrivedAtDropoff',
      ]) {
        store.change('deliveries', 'dl1', status: s);
        await settle();
        expect(pub.activeJob, isNotNull, reason: s);
      }
    });

    test('reopening the delivery screen does not add a stream', () async {
      store.put('deliveries', 'dl1', status: 'deliveryEnroute');
      for (var i = 0; i < 3; i++) {
        await pub.startJob(ActiveJobKind.delivery, 'dl1');
      }
      expect(source.controllers.length, 1);
      expect(store.reads, 1, reason: 'ownership verified once per start');
    });

    test('writes at most every 5 s, with both timestamps', () async {
      store.put('deliveries', 'dl1', status: 'deliveryEnroute');
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      source.emit(fix(5.60));
      await settle();
      clock = clock.add(const Duration(seconds: 4));
      source.emit(fix(5.61));
      await settle();
      clock = clock.add(const Duration(seconds: 1));
      source.emit(fix(5.62));
      await settle();
      expect(store.writes.map((w) => w.$3.latitude), [5.60, 5.62]);
      final f = jobLocationFields(ActiveJobKind.delivery, fix(5.62),
          serverTimestamp: 'ts');
      expect(f, containsPair('driverLocationUpdatedAt', 'ts'));
      expect(f, containsPair('lastLocationUpdate', 'ts'));
    });

    test(
        'switching from a ride to a delivery leaves one stream and '
        'no late ride writes', () async {
      store.put('trips', 't1', status: 'tripStarted');
      store.put('deliveries', 'dl1', status: 'driverAssigned');
      await pub.startJob(ActiveJobKind.ride, 't1');
      final rideStream = source.controllers.first;
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      clock = clock.add(const Duration(seconds: 10));
      rideStream.add(fix(1.0));
      source.emit(fix(5.6));
      await settle();
      expect(source.listening, 1);
      expect(store.writes.map((w) => w.$2), ['dl1']);
    });

    test('ride is unaffected: same kind, cadence and notification', () {
      expect(ActiveJobKind.ride.collection, 'trips');
      expect(ActiveJobKind.ride.notificationText,
          'Sharing your location for the active trip');
      expect(ActiveJobKind.delivery.notificationText,
          'Sharing your location for the active delivery');
      expect(ActiveJobKind.delivery.wakeLock, isFalse);
    });

    test('write failure on a delivery is reported', () async {
      store.put('deliveries', 'dl1', status: 'deliveryEnroute');
      store.failWrites = true;
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      source.emit(fix(5.6));
      await settle();
      expect(pub.problem.value, isNotNull);
    });
  });

  group('gas (migrated)', () {
    test('lifecycle: start, publish, stop on delivered', () async {
      store.put('gas_orders', 'g1', status: 'driverEnRoute');
      expect(await pub.startJob(ActiveJobKind.gas, 'g1'), isNull);
      source.emit(fix(5.6));
      await settle();
      expect(store.writes.single.$1, ActiveJobKind.gas);
      expect(store.writes.single.$2, 'g1');
      store.change('gas_orders', 'g1', status: 'delivered');
      await settle();
      expect(pub.activeJob, isNull);
      expect(source.listening, 0, reason: 'notification is removed with it');
    });

    test('stops when the order is cancelled (driver writes "cancelled")',
        () async {
      store.put('gas_orders', 'g1', status: 'driverArrived');
      await pub.startJob(ActiveJobKind.gas, 'g1');
      store.change('gas_orders', 'g1', status: 'cancelled');
      await settle();
      expect(pub.activeJob, isNull);
    });

    test('keeps publishing through both fulfilment routes', () async {
      // Drop-off route, then the pickup-and-return stages.
      store.put('gas_orders', 'g1', status: 'driverAssigned');
      await pub.startJob(ActiveJobKind.gas, 'g1');
      for (final s in [
        'driverEnRoute',
        'driverArrived',
        'pickedUp',
        'atStation',
        'refilling',
        'returning',
      ]) {
        store.change('gas_orders', 'g1', status: s);
        await settle();
        expect(pub.activeJob, isNotNull, reason: s);
      }
    });

    test('does not start for an order still waiting for a driver', () async {
      store.put('gas_orders', 'g1', status: 'pendingApproval', driverId: null);
      expect(await pub.startJob(ActiveJobKind.gas, 'g1'), isNotNull);
      expect(source.controllers, isEmpty);
    });

    test('reassignment stops publishing', () async {
      store.put('gas_orders', 'g1', status: 'driverEnRoute');
      await pub.startJob(ActiveJobKind.gas, 'g1');
      store.change('gas_orders', 'g1',
          status: 'driverEnRoute', driverId: 'other');
      await settle();
      expect(pub.activeJob, isNull);
    });

    test('reopening the gas screen does not add a stream', () async {
      store.put('gas_orders', 'g1', status: 'refilling');
      for (var i = 0; i < 3; i++) {
        await pub.startJob(ActiveJobKind.gas, 'g1');
      }
      expect(source.controllers.length, 1);
    });

    test('writes at most every 5 s with both timestamps', () async {
      store.put('gas_orders', 'g1', status: 'returning');
      await pub.startJob(ActiveJobKind.gas, 'g1');
      source.emit(fix(5.60));
      await settle();
      clock = clock.add(const Duration(seconds: 3));
      source.emit(fix(5.61));
      await settle();
      clock = clock.add(const Duration(seconds: 2));
      source.emit(fix(5.62));
      await settle();
      expect(store.writes.map((w) => w.$3.latitude), [5.60, 5.62]);
      final f = jobLocationFields(ActiveJobKind.gas, fix(5.62),
          serverTimestamp: 'ts');
      expect(f.keys.toSet(), {
        'driverCurrentLocation',
        'driverHeading',
        'lastLocationUpdate',
        'driverLocationUpdatedAt',
      });
    });

    test('ride → delivery → gas: one stream at a time, no late writes',
        () async {
      store.put('trips', 't1', status: 'tripStarted');
      store.put('deliveries', 'dl1', status: 'deliveryEnroute');
      store.put('gas_orders', 'g1', status: 'driverEnRoute');
      await pub.startJob(ActiveJobKind.ride, 't1');
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      await pub.startJob(ActiveJobKind.gas, 'g1');
      clock = clock.add(const Duration(seconds: 10));
      for (final c in source.controllers.take(2)) {
        if (!c.isClosed) c.add(fix(1.0)); // late fixes from earlier jobs
      }
      source.emit(fix(5.6));
      await settle();
      expect(source.listening, 1);
      expect(store.writes.map((w) => w.$2), ['g1']);
      expect(pub.activeJob, const ActiveJobRef(ActiveJobKind.gas, 'g1'));
    });

    test('gas failures are reported like ride and delivery', () async {
      store.put('gas_orders', 'g1', status: 'driverEnRoute');
      source.serviceEnabled = false;
      expect(await pub.startJob(ActiveJobKind.gas, 'g1'), isNotNull);
      expect(pub.problem.value, isNotNull);
      source.serviceEnabled = true;
      store.failWrites = true;
      await pub.startJob(ActiveJobKind.gas, 'g1');
      source.emit(fix(5.6));
      await settle();
      expect(pub.problem.value, contains("isn't reaching"));
    });
  });

  // ── Step 5: online idle + driver profile on one stream ─────────────────
  group('online idle', () {
    test('going online opens one idle stream (no foreground service)',
        () async {
      expect(await pub.startIdle(), isNull);
      expect(pub.isIdleTracking, isTrue);
      expect(pub.subscriptionCount, 1);
      expect(source.kinds.single, isNull, reason: 'idle stream settings');
    });

    test('going online twice does not open a second stream', () async {
      await pub.startIdle();
      await pub.startIdle();
      expect(source.controllers.length, 1);
    });

    test('idle fixes update the profile with the existing fields', () async {
      await pub.startIdle();
      source.emit(fix(5.6));
      await settle();
      expect(store.profileWrites.single.$1, 'd1');
      expect(store.writes, isEmpty, reason: 'no job, no job writes');
      final f = profileLocationFields(fix(5.6), serverTimestamp: 'ts');
      expect(f.keys.toSet(),
          {'location', 'currentLocation', 'lastSeen', 'lastLocationUpdate'});
      expect(f['location'], f['currentLocation']);
    });

    test('going offline stops idle publishing', () async {
      await pub.startIdle();
      await pub.stopIdle();
      expect(pub.subscriptionCount, 0);
      expect(source.listening, 0);
    });

    test('idle does not start without permission or with GPS off', () async {
      source.permission = LocationPermission.deniedForever;
      expect(await pub.startIdle(), isNotNull);
      source.permission = LocationPermission.whileInUse;
      source.serviceEnabled = false;
      expect(await pub.startIdle(), isNotNull);
      expect(source.controllers, isEmpty);
    });

    test('a stream error while idle never fakes a fresh location', () async {
      await pub.startIdle();
      source.controllers.last.addError(Exception('gps lost'));
      await settle();
      expect(store.profileWrites, isEmpty);
    });
  });

  group('profile throttle (30 s or 50 m, whichever first)', () {
    test('pure rule', () {
      final t0 = DateTime(2026);
      const here = (lat: 5.6, lng: -0.18);
      expect(
          shouldWriteProfile(
              now: t0,
              lastWriteAt: null,
              lastWritePos: null,
              lat: 5.6,
              lng: -0.18),
          isTrue,
          reason: 'first fix always written');
      expect(
          shouldWriteProfile(
              now: t0.add(const Duration(seconds: 29)),
              lastWriteAt: t0,
              lastWritePos: here,
              lat: 5.6001, // ~11 m
              lng: -0.18),
          isFalse);
      expect(
          shouldWriteProfile(
              now: t0.add(const Duration(seconds: 30)),
              lastWriteAt: t0,
              lastWritePos: here,
              lat: 5.6,
              lng: -0.18),
          isTrue,
          reason: '30 s elapsed');
      expect(
          shouldWriteProfile(
              now: t0.add(const Duration(seconds: 5)),
              lastWriteAt: t0,
              lastWritePos: here,
              lat: 5.6005, // ~55 m
              lng: -0.18),
          isTrue,
          reason: 'moved 50 m');
    });

    test('distance helper is in metres', () {
      expect(distanceMetres(5.6, -0.18, 5.6005, -0.18), closeTo(55.6, 1));
    });

    test('idle writes follow the throttle', () async {
      await pub.startIdle();
      source.emit(fix(5.6000));
      await settle();
      clock = clock.add(const Duration(seconds: 10));
      source.emit(fix(5.6001)); // 10 s, ~11 m: skipped
      await settle();
      clock = clock.add(const Duration(seconds: 5));
      source.emit(fix(5.6006)); // ~66 m from the last WRITE: written
      await settle();
      expect(store.profileWrites.map((w) => w.$2.latitude), [5.6000, 5.6006]);
    });

    test('a failed profile write is retried on the next fix', () async {
      await pub.startIdle();
      store.failProfileWrites = true;
      source.emit(fix(5.6));
      await settle();
      store.failProfileWrites = false;
      clock = clock.add(const Duration(seconds: 1));
      source.emit(fix(5.6));
      await settle();
      expect(store.profileWrites.length, 1,
          reason: 'failure did not mark the driver as freshly located');
    });

    test('profile throttle never suppresses ride job writes', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      for (var i = 0; i < 6; i++) {
        source.emit(fix(5.6 + i * 0.00001)); // ~1 m apart
        await settle();
        clock = clock.add(const Duration(seconds: 2));
      }
      expect(store.writes.length, 6, reason: 'one job write per 2 s');
      expect(store.profileWrites.length, 1, reason: 'profile throttled');
    });

    test('go-online first fix counts as a profile write', () async {
      pub.noteProfileWritten(5.6, -0.18);
      await pub.startIdle();
      source.emit(fix(5.6));
      await settle();
      expect(store.profileWrites, isEmpty);
    });
  });

  group('idle ↔ active job handoff (one stream)', () {
    test('accepting a job replaces the idle stream; profile keeps updating',
        () async {
      store.put('deliveries', 'dl1', status: 'driverAssigned');
      await pub.startIdle();
      await pub.startJob(ActiveJobKind.delivery, 'dl1');
      expect(pub.subscriptionCount, 1);
      expect(source.listening, 1);
      expect(source.kinds.last, ActiveJobKind.delivery);
      source.emit(fix(5.6));
      await settle();
      expect(store.writes.single.$2, 'dl1');
      expect(store.profileWrites.length, 1);
    });

    for (final (kind, id, end) in [
      (ActiveJobKind.ride, 't1', 'completed'),
      (ActiveJobKind.delivery, 'dl1', 'cancelledByPassenger'),
      (ActiveJobKind.gas, 'g1', 'delivered'),
    ]) {
      test('${kind.name} ends ("$end") → back to idle while online', () async {
        store.put(kind.collection, id, status: 'active');
        await pub.startIdle();
        await pub.startJob(kind, id);
        store.change(kind.collection, id, status: end);
        await settle();
        expect(pub.activeJob, isNull);
        expect(pub.isIdleTracking, isTrue);
        expect(source.listening, 1);
        expect(source.kinds.last, isNull);
      });
    }

    test('reassignment → back to idle while online', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      await pub.startIdle();
      await pub.startJob(ActiveJobKind.ride, 't1');
      store.change('trips', 't1', status: 'tripAccepted', driverId: 'x');
      await settle();
      expect(pub.isIdleTracking, isTrue);
    });

    test('job ends while offline → nothing keeps running', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startJob(ActiveJobKind.ride, 't1');
      store.change('trips', 't1', status: 'completed');
      await settle();
      expect(pub.subscriptionCount, 0);
    });

    test(
        'going offline mid-job keeps the job stream (customer still needs '
        'the driver)', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startIdle();
      await pub.startJob(ActiveJobKind.ride, 't1');
      await pub.stopIdle();
      expect(pub.activeJob, isNotNull);
      store.change('trips', 't1', status: 'completed');
      await settle();
      expect(pub.subscriptionCount, 0, reason: 'offline: no idle after job');
    });

    test('sign-out (stopAll) stops idle and any job', () async {
      store.put('trips', 't1', status: 'tripStarted');
      await pub.startIdle();
      await pub.startJob(ActiveJobKind.ride, 't1');
      await pub.stopAll();
      expect(pub.subscriptionCount, 0);
      expect(source.listening, 0);
      store.change('trips', 't1', status: 'completed');
      await settle();
      expect(pub.subscriptionCount, 0,
          reason: 'no idle restart after sign-out');
    });

    test('a refused job start leaves the idle stream working', () async {
      store.put('trips', 't9', status: 'tripAccepted', driverId: 'other');
      await pub.startIdle();
      expect(await pub.startJob(ActiveJobKind.ride, 't9'), isNotNull);
      expect(pub.isIdleTracking, isTrue);
      source.emit(fix(5.6));
      await settle();
      expect(store.profileWrites.length, 1,
          reason: 'idle callbacks still valid');
    });

    test('late idle fixes after a job took over are ignored', () async {
      store.put('trips', 't1', status: 'tripAccepted');
      await pub.startIdle();
      final idle = source.controllers.first;
      await pub.startJob(ActiveJobKind.ride, 't1');
      clock = clock.add(const Duration(minutes: 1));
      if (!idle.isClosed) idle.add(fix(1.0));
      await settle();
      expect(store.profileWrites.where((w) => w.$2.latitude == 1.0), isEmpty);
    });
  });

  group('app resume', () {
    test('refreshNow publishes one fresh fix without a new stream', () async {
      await pub.startIdle();
      source.emit(fix(5.6));
      await settle();
      source.current = fix(5.6); // same place, within 30 s
      await pub.refreshNow();
      await settle();
      expect(source.controllers.length, 1);
      expect(store.profileWrites.length, 2, reason: 'resume bypasses throttle');
    });

    test('refreshNow restarts idle if it was not running while online',
        () async {
      source.serviceEnabled = false;
      await pub.startIdle(); // fails: GPS off
      expect(pub.subscriptionCount, 0);
      source.serviceEnabled = true;
      await pub.refreshNow();
      expect(pub.isIdleTracking, isTrue);
    });

    test('refreshNow while offline and idle does nothing', () async {
      await pub.refreshNow();
      expect(source.controllers, isEmpty);
    });
  });
}
