// Presentation of the Home status card and the incoming request feed.
// The feed is driven through pendingRequestsProvider, so no Firebase is
// touched; accept buttons are found but never tapped.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/requests_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// An approved, online, available Delivery driver with a location: the list
// shows a driver nothing otherwise (requestListBlock).
const _driver = DriverProfile(
  uid: 'driver-1',
  service: DriverServiceType.delivery,
  role: 'driver_delivery',
  vehicleType: DriverVehicleType.motorbike,
  vehicleTypeRaw: 'motorcycle',
  isApproved: true,
  isOnline: true,
  isAvailable: true,
  currentLocation: GeoPoint(5.6037, -0.1870),
  dispatchLocation: GeoPoint(5.6037, -0.1870),
);

const _longPickup =
    'Accra Mall, Spintex Road, Tetteh Quarshie Interchange, Greater Accra '
    'Region, opposite the main taxi rank beside the pedestrian footbridge';
const _longDropoff =
    'Kotoka International Airport Terminal 3 Departures, Airport Residential '
    'Area, Liberation Road, Accra, near the short-stay car park entrance';

AvailableRequest _ride({String? serviceType, int passengers = 1}) =>
    AvailableRequest(
      id: 'trip-1',
      passengerId: 'p1',
      type: RequestType.ride,
      status: 'searching',
      pickupAddress: _longPickup,
      dropoffAddress: _longDropoff,
      pickupLocation: const GeoPoint(5.6200, -0.1730),
      dropoffLocation: const GeoPoint(5.6050, -0.1680),
      fare: 42.5,
      createdAt: DateTime.now(),
      collection: 'trips',
      passengerCount: passengers,
      serviceType: serviceType,
    );

final _delivery = AvailableRequest(
  id: 'del-1',
  passengerId: 'p1',
  type: RequestType.delivery,
  status: 'pending',
  pickupAddress: 'Osu Oxford Street',
  dropoffAddress: 'East Legon, Lagos Avenue',
  pickupLocation: const GeoPoint(5.6040, -0.1875),
  dropoffLocation: const GeoPoint(5.6350, -0.1550),
  fare: 25,
  createdAt: DateTime.now(),
  collection: 'deliveries',
  packageDescription: 'Documents',
  weightTier: 'Small',
  recipientName: 'Ama Mensah',
  recipientPhone: '+233 20 000 0000',
);

final _gas = AvailableRequest(
  id: 'gas-1',
  passengerId: 'p1',
  type: RequestType.gas,
  status: 'pendingApproval',
  pickupAddress: 'Goil Filling Station, Ring Road',
  dropoffAddress: 'Kaneshie, First Light',
  pickupLocation: const GeoPoint(5.5700, -0.2100),
  dropoffLocation: const GeoPoint(5.5680, -0.2300),
  fare: 15,
  createdAt: DateTime.now(),
  collection: 'gas_orders',
  refillType: 'refill',
  cylinderSize: '14.5 kg',
  cylinderQuantity: 1,
  deliveryFee: 15,
);

Widget _feed(
  AsyncValue<List<AvailableRequest>> value, {
  bool online = true,
  VoidCallback? onGoOnline,
  double textScale = 1.0,
}) =>
    ProviderScope(
      // A new scope per pump: Riverpod keeps the first override otherwise.
      key: UniqueKey(),
      overrides: [
        pendingRequestsProvider.overrideWith((ref, driver) => value),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RequestsSection(
                driver: _driver,
                isOnline: online,
                onGoOnline: onGoOnline ?? () {},
              ),
            ),
          ),
        ),
      ),
    );

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// Smallest font size of any text painted under [root]. Icon glyphs are
/// skipped: they are drawn as text but are not read.
double _smallestFont(WidgetTester tester, Finder root) {
  final iconGlyphs = tester
      .widgetList<RichText>(find.descendant(
          of: find.descendant(of: root, matching: find.byType(Icon)),
          matching: find.byType(RichText)))
      .toSet();
  var smallest = double.infinity;
  void visit(InlineSpan span, double inherited) {
    final size = span.style?.fontSize ?? inherited;
    if (span is TextSpan) {
      if ((span.text ?? '').trim().isNotEmpty && size < smallest) {
        smallest = size;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, size);
      }
    }
  }

  for (final rich in tester.widgetList<RichText>(
      find.descendant(of: root, matching: find.byType(RichText)))) {
    if (iconGlyphs.contains(rich)) continue;
    visit(rich.text, 14);
  }
  return smallest;
}

void main() {
  group('HomeStatusCard', () {
    Future<int> pumpCard(WidgetTester tester, bool online) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: HomeStatusCard(isOnline: online, onToggle: () => taps++),
        ),
      ));
      await tester.tap(find.text(online ? 'Go Offline' : 'Go Online'));
      return taps;
    }

    testWidgets('offline: says so, power icon, green Go Online action',
        (tester) async {
      expect(await pumpCard(tester, false), 1);
      expect(find.text("You're Offline"), findsOneWidget);
      expect(find.text('Go online to start earning'), findsOneWidget);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Go Online'), findsOneWidget);
      expect(find.text('Go Offline'), findsNothing);
    });

    testWidgets('online: says so, live icon, outlined Go Offline action',
        (tester) async {
      expect(await pumpCard(tester, true), 1);
      expect(find.text("You're Online"), findsOneWidget);
      expect(find.text('Ready to receive requests'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Go Offline'), findsOneWidget);
      expect(find.text('Go Online'), findsNothing);
    });

    testWidgets('fits a 320 px screen at 1.3× text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final online in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeStatusCard(isOnline: online, onToggle: () {}),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('RequestsSection states', () {
    testWidgets('offline shows the go-online card and calls back',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_feed(const AsyncValue.data([]),
          online: false, onGoOnline: () => taps++));
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      await tester.tap(find.text('Go Online'));
      expect(taps, 1);
    });

    testWidgets('loading and empty both show the searching state',
        (tester) async {
      await tester.pumpWidget(_feed(const AsyncValue.loading()));
      expect(find.text('Searching for requests nearby...'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      await tester.pumpWidget(_feed(const AsyncValue.data([])));
      expect(find.text('Searching for requests nearby...'), findsOneWidget);
    });

    testWidgets('error shows the retry state', (tester) async {
      await tester.pumpWidget(
          _feed(AsyncValue.error(Exception('x'), StackTrace.empty)));
      expect(find.text('Could not load requests.\nCheck your connection.'),
          findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });
  });

  group('Request cards', () {
    testWidgets('each service has its own label, icon and accent',
        (tester) async {
      await tester.pumpWidget(_feed(AsyncValue.data(
          [_ride(serviceType: 'okada', passengers: 2), _delivery, _gas])));

      expect(find.text('Ride'), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
      expect(_colorOf(tester, 'Ride'), AppTheme.primaryDark);
      expect(find.textContaining('Okada'), findsOneWidget);

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
      expect(_colorOf(tester, 'Delivery'), const Color(0xFF0369A1));

      expect(find.text('Gas Order'), findsOneWidget);
      expect(find.byIcon(Icons.propane_tank_rounded), findsWidgets);
      expect(_colorOf(tester, 'Gas Order'), const Color(0xFFC2410C));
    });

    testWidgets('ride icon follows the request service type', (tester) async {
      for (final (type, icon) in [
        ('taxi', Icons.local_taxi_rounded),
        ('pragyia', Icons.electric_rickshaw_rounded),
        (null, Icons.directions_car_rounded),
      ]) {
        await tester.pumpWidget(
            _feed(AsyncValue.data([_ride(serviceType: type)])));
        expect(find.byIcon(icon), findsOneWidget, reason: '$type');
      }
    });

    testWidgets('fare, distance and details are shown', (tester) async {
      await tester.pumpWidget(_feed(AsyncValue.data(
          [_ride(passengers: 2), _delivery, _gas])));

      expect(find.text('GH₵ 42.50'), findsOneWidget);
      expect(find.text('GH₵ 25.00'), findsOneWidget);
      expect(find.text('GH₵ 15.00'), findsOneWidget);
      expect(find.text('Est. fare'), findsNWidgets(2));
      // Release v5: a Gas request shows its verified order total.
      expect(find.text('Order total'), findsOneWidget);

      expect(find.textContaining(RegExp(r'^\d+\.\d km to pickup$')),
          findsOneWidget); // ride
      expect(find.textContaining(RegExp(r'^~\d+ m to pickup$')),
          findsOneWidget); // delivery, under 1 km, approximate (offer point)
      expect(find.textContaining(RegExp(r'km to station$')), findsOneWidget);

      expect(find.text('2 passengers'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('SMALL'), findsOneWidget);
      expect(find.text('Ama Mensah'), findsOneWidget);
      expect(find.text('14.5 kg × 1'), findsOneWidget);
      expect(find.text('Station'), findsOneWidget);
      expect(find.text('Pickup'), findsNWidgets(2));
      expect(find.text('Dropoff'), findsNWidgets(3));

      expect(find.widgetWithText(FilledButton, 'Accept Ride'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Accept Delivery'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept Gas Order'),
          findsOneWidget);
    });

    // A driver without a location can neither be offered nor accept
    // anything (dispatch_policy.js driver_location_invalid), so no cards.
    testWidgets('no cards, and why, when the driver location is unknown',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pendingRequestsProvider
              .overrideWith((ref, driver) => AsyncValue.data([_ride()])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RequestsSection(
                driver: const DriverProfile(
                  uid: 'driver-1',
                  service: DriverServiceType.ride,
                  role: 'driver_hailing',
                  serviceType: 'taxi',
                  vehicleType: DriverVehicleType.taxi,
                  vehicleTypeRaw: 'taxi',
                  isApproved: true,
                  isOnline: true,
                  isAvailable: true,
                ),
                isOnline: true,
                onGoOnline: () {},
              ),
            ),
          ),
        ),
      ));
      expect(find.textContaining('to pickup'), findsNothing);
      expect(find.text('Accept Ride'), findsNothing);
      expect(
          find.text(
              'Waiting for your location. Check that location access is on.'),
          findsOneWidget);
    });

    testWidgets('no text under 12 px', (tester) async {
      await tester.pumpWidget(_feed(AsyncValue.data(
          [_ride(serviceType: 'okada', passengers: 3), _delivery, _gas])));
      expect(_smallestFont(tester, find.byType(RequestsSection)),
          greaterThanOrEqualTo(12));

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: HomeStatusCard(isOnline: true, onToggle: () {}),
        ),
      ));
      expect(_smallestFont(tester, find.byType(HomeStatusCard)),
          greaterThanOrEqualTo(12));
    });

    testWidgets('long addresses fit a 320 px screen at 1.3× text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_feed(
        AsyncValue.data([_ride(serviceType: 'pragyia', passengers: 4), _delivery, _gas]),
        textScale: 1.3,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Accept Ride'), findsOneWidget);
    });
  });
}
