// The notification bell counts the signed-in driver's unread notifications
// by the `isRead` flag the backend writes (there is no `read` field). It
// updates as notifications are read, hides at zero, never counts another
// driver's notifications, and picks the driver up when sign-in completes
// after the bell was built. Count streams are fakes: no Firebase.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/data/datasources/driver_remote_datasource.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/providers/driver_home_providers.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/driver_app_bar.dart';
import 'package:cts_transport_driver_app/features/driver_auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _driver = DriverProfile(
  uid: 'd1',
  service: DriverServiceType.delivery,
  vehicleType: DriverVehicleType.motorbike,
  currentLocation: GeoPoint(5.6037, -0.1870),
);

/// The signed-in driver, as authStateProvider would report it.
final _signedIn = StateProvider<String?>((_) => null);

class _Counts {
  final requested = <String>[];
  final _controllers = <String, StreamController<int>>{};

  StreamController<int> of(String driverId) =>
      _controllers.putIfAbsent(driverId, StreamController<int>.broadcast);

  Stream<int> source(String driverId) {
    requested.add(driverId);
    return of(driverId).stream;
  }

  void close() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}

Future<ProviderContainer> _pumpBell(WidgetTester t, _Counts counts,
    {String? signedIn}) async {
  final container = ProviderContainer(overrides: [
    driverIdProvider.overrideWith((ref) => ref.watch(_signedIn)),
    unreadNotificationCountSourceProvider.overrideWithValue(counts.source),
  ]);
  addTearDown(container.dispose);
  addTearDown(counts.close);
  container.read(_signedIn.notifier).state = signedIn;
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        appBar: DriverAppBar(
          onlineStatus: true,
          unreadNotifications: 0,
          profile: _driver,
          onProfileTap: () {},
          onNotificationsTap: () {},
        ),
      ),
    ),
  ));
  await t.pump();
  return container;
}

/// A new count, then the frames for the provider and the bell to rebuild.
Future<void> _emit(WidgetTester t, _Counts counts, String driverId, int n) async {
  counts.of(driverId).add(n);
  await t.pump();
  await t.pump();
}

Finder _badge(String text) =>
    find.descendant(of: find.byType(DriverAppBar), matching: find.text(text));

void main() {
  test('the unread flag is the one the backend writes', () {
    expect(DriverRemoteDataSource.notificationIsRead, 'isRead');
  });

  testWidgets('unread notifications show a count on the bell', (t) async {
    final counts = _Counts();
    await _pumpBell(t, counts, signedIn: 'd1');
    await _emit(t, counts, 'd1', 3);
    expect(_badge('3'), findsOneWidget);
  });

  testWidgets('reading notifications updates the badge, and zero hides it',
      (t) async {
    final counts = _Counts();
    await _pumpBell(t, counts, signedIn: 'd1');
    await _emit(t, counts, 'd1', 2);
    expect(_badge('2'), findsOneWidget);

    await _emit(t, counts, 'd1', 1); // one marked read
    expect(_badge('1'), findsOneWidget);
    expect(_badge('2'), findsNothing);

    await _emit(t, counts, 'd1', 0); // all read
    expect(_badge('0'), findsNothing);
    expect(_badge('1'), findsNothing);
  });

  testWidgets("another driver's notifications are never counted", (t) async {
    final counts = _Counts();
    await _pumpBell(t, counts, signedIn: 'd1');
    counts.of('d2').add(9);
    await _emit(t, counts, 'd1', 1);
    expect(counts.requested.toSet(), {'d1'});
    expect(_badge('1'), findsOneWidget);
    expect(_badge('9'), findsNothing);
  });

  testWidgets('a bell built before sign-in picks up the driver afterwards',
      (t) async {
    final counts = _Counts();
    final container = await _pumpBell(t, counts);
    expect(counts.requested, isEmpty, reason: 'no query without a driver');
    expect(find.descendant(
            of: find.byType(DriverAppBar), matching: find.textContaining(RegExp(r'^\d'))),
        findsNothing);

    container.read(_signedIn.notifier).state = 'd1';
    await t.pump();
    await _emit(t, counts, 'd1', 4);
    expect(counts.requested, ['d1'], reason: 'one listener');
    expect(_badge('4'), findsOneWidget);

    // Signing out drops the count.
    container.read(_signedIn.notifier).state = null;
    await t.pump();
    await t.pump();
    expect(_badge('4'), findsNothing);
  });
}
