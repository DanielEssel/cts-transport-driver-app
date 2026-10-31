// The request list re-filters whenever anything eligibility reads changes
// (location, vehicle, service, job, approval), and a failed query is shown
// as an error, never as an empty "searching" list.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/requests_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _accra = GeoPoint(5.6037, -0.187);
const _kumasi = GeoPoint(6.69, -1.62);

DriverProfile _bike({GeoPoint? at = _accra, String vehicle = 'motorcycle', String? job}) =>
    DriverProfile.fromFirestore({
      'role': 'driver_delivery',
      'vehicleType': vehicle,
      'isApproved': true,
      'signupStep': 'approved',
      'isOnline': true,
      'isAvailable': true,
      if (job != null) 'currentTripId': job,
      if (at != null) 'location': at,
    }, 'd1');

AvailableRequest _delivery(String id, String vehicle, String tier) => AvailableRequest(
      id: id,
      passengerId: 'p',
      type: RequestType.delivery,
      status: 'pending',
      pickupAddress: 'A',
      dropoffAddress: 'B',
      pickupLocation: _accra,
      dropoffLocation: _accra,
      fare: 10,
      createdAt: DateTime(2026, 10, 1),
      collection: 'deliveries',
      bookedVehicle: vehicle,
      weightTier: tier,
    );

final _small = _delivery('small', 'Okada', 'Small');
final _large = _delivery('large', 'Aboboya', 'Large');

void main() {
  group('profile equality covers everything eligibility reads', () {
    test('a location change is a different profile (the list re-filters)', () {
      expect(_bike(), isNot(equals(_bike(at: _kumasi))));
    });
    test('a vehicle change is a different profile', () {
      expect(_bike(), isNot(equals(_bike(vehicle: 'tricycle'))));
    });
    test('taking a job is a different profile', () {
      expect(_bike(), isNot(equals(_bike(job: 'g1'))));
    });
    test('an unchanged profile is equal (no needless re-subscription)', () {
      expect(_bike(), equals(_bike()));
    });
  });

  group('the list follows the driver', () {
    test('moving out of the radius hides the request; moving back shows it', () {
      expect(eligibleRequests(_bike(), [_small, _large]).map((r) => r.id), ['small']);
      expect(eligibleRequests(_bike(at: _kumasi), [_small, _large]), isEmpty);
      expect(eligibleRequests(_bike(at: null), [_small, _large]), isEmpty);
    });

    test('a vehicle change swaps which parcels are shown', () {
      expect(eligibleRequests(_bike(vehicle: 'tricycle'), [_small, _large]).map((r) => r.id),
          ['large']);
    });

    test('a driver on a job sees nothing', () {
      expect(eligibleRequests(_bike(job: 'g1'), [_small, _large]), isEmpty);
    });

    test('the query key ignores location, so moving does not re-subscribe', () {
      expect(RequestQuery.of(_bike()), RequestQuery.of(_bike(at: _kumasi)));
      expect(RequestQuery.of(_bike()), isNot(RequestQuery.of(_bike(vehicle: 'tricycle'))));
    });
  });

  group('the list widget', () {
    Widget section(DriverProfile driver, AsyncValue<List<AvailableRequest>> value) =>
        ProviderScope(
          key: UniqueKey(),
          overrides: [pendingRequestsProvider.overrideWith((ref, d) => value)],
          child: MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RequestsSection(driver: driver, isOnline: true, onGoOnline: () {}),
              ),
            ),
          ),
        );

    testWidgets('a failed query shows which list failed and a retry', (tester) async {
      await tester.pumpWidget(section(_bike(),
          const AsyncValue.error(RequestsLoadError(['gas orders'], 'x'), StackTrace.empty)));
      expect(find.text('Could not load gas orders.\nCheck your connection.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.text('Searching for requests nearby...'), findsNothing);
    });

    testWidgets('a rules refusal is not reported as a connection problem', (tester) async {
      // Driver 1.0.3 against rules without the offer collections (stage 1):
      // both offer listeners are refused.
      final refused = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      await tester.pumpWidget(section(_bike(),
          AsyncValue.error(RequestsLoadError(const ['deliveries', 'gas orders'], refused), StackTrace.empty)));
      expect(find.text('Could not load deliveries, gas orders: access was refused.\n'
          'Contact support if this continues.'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });

    testWidgets('a driver on a job is told why the list is empty', (tester) async {
      await tester.pumpWidget(section(_bike(job: 'g1'), const AsyncValue.data([])));
      expect(find.text('Finish your current job to see new requests.'), findsOneWidget);
      expect(find.text('Searching for requests nearby...'), findsNothing);
    });

    testWidgets('a driver without a location is told why', (tester) async {
      await tester.pumpWidget(section(_bike(at: null), const AsyncValue.data([])));
      expect(find.text('Waiting for your location. Check that location access is on.'),
          findsOneWidget);
    });

    testWidgets('an unknown vehicle shows nothing and says so (not a motorbike)', (tester) async {
      await tester.pumpWidget(section(_bike(vehicle: 'van'), const AsyncValue.data([])));
      expect(find.textContaining('not set up for requests'), findsOneWidget);
      expect(eligibleRequests(_bike(vehicle: 'van'), [_small]), isEmpty);
    });
  });

  group('acceptance refusals', () {
    test('every server reason has a message for the driver', () {
      for (final r in ['order_not_found', 'order_unavailable', 'order_already_assigned',
          'driver_not_found', 'vehicle_not_eligible', 'driver_on_job', 'outside_radius',
          'driver_not_eligible']) {
        expect(acceptRefusalMessage(r, null), isNot('This request could not be accepted.'),
            reason: r);
      }
      expect(acceptRefusalMessage('outside_radius', 'driver_location_invalid'),
          contains('location'));
    });

    test('each service accepts through its own callable', () {
      expect(acceptCallableFor('trips'), ('acceptRide', 'tripId'));
      expect(acceptCallableFor('deliveries'), ('acceptDelivery', 'deliveryId'));
      expect(acceptCallableFor('gas_orders'), ('acceptGasOrder', 'orderId'));
    });
  });

  group('requestsErrorMessage', () {
    test('a rules refusal names the lists and asks for support, not a better network', () {
      final refused = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      expect(requestsErrorMessage(RequestsLoadError(const ['gas orders'], refused)),
          'Could not load gas orders: access was refused.\nContact support if this continues.');
    });

    test('other failures keep the connection advice', () {
      final offline = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      expect(requestsErrorMessage(RequestsLoadError(const ['deliveries'], offline)),
          'Could not load deliveries.\nCheck your connection.');
      expect(requestsErrorMessage(const RequestsLoadError(['rides'], 'x')),
          'Could not load rides.\nCheck your connection.');
      expect(requestsErrorMessage(StateError('x')), 'Could not load requests.\nCheck your connection.');
    });
  });
}
