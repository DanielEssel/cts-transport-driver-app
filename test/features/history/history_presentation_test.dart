// History screen presentation: status and service labels per record type,
// fields the record lacks are left out rather than shown as zero, the
// summary's honest label, empty-state copy per tab, and small screens.

import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/trip_history_screen.dart';
import 'package:cts_transport_driver_app/features/jobs/data/driver_jobs_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummary _job({
  JobType type = JobType.ride,
  TripStatus status = TripStatus.completed,
  String name = 'Ama Mensah',
  double km = 7.4,
  int minutes = 18,
  double fare = 32.5,
  double rating = 4.5,
  String payment = 'MoMo',
  String pickup = 'Osu Oxford Street',
  String dropoff = 'Kotoka Airport',
}) =>
    TripSummary(
      id: 'j1',
      jobType: type,
      passengerName: name,
      passengerAvatar: 'AM',
      pickupAddress: pickup,
      dropoffAddress: dropoff,
      dateTime: DateTime(2026, 10, 18, 14, 5),
      distanceKm: km,
      durationMinutes: minutes,
      fareGhs: fare,
      rating: rating,
      status: status,
      paymentMethod: payment,
    );

Widget _app(Widget child) => MaterialApp(
    theme: AppTheme.theme,
    home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('Job card', () {
    testWidgets('completed ride: Ride badge, Completed, deep-green fare',
        (tester) async {
      await tester.pumpWidget(_app(HistoryJobCard(trip: _job())));
      expect(find.text('Ama Mensah'), findsOneWidget);
      expect(find.text('Ride'), findsOneWidget);
      expect(find.text('Passenger'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('2:05 PM · 18 Oct 2026'), findsOneWidget);
      final fare = tester.widget<Text>(find.text('GH₵ 32.50'));
      expect(fare.style?.color, AppTheme.primaryDark);
      expect(fare.style?.decoration, isNull);
      expect(find.text('7.4 km'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('MoMo'), findsOneWidget);
      expect(find.bySemanticsLabel('Rated 4.5 of 5'), findsOneWidget);
    });

    testWidgets('cancelled delivery: Cancelled, fare struck through',
        (tester) async {
      await tester.pumpWidget(_app(HistoryJobCard(
          trip: _job(
              type: JobType.delivery,
              status: TripStatus.cancelled,
              name: 'Kofi Boateng'))));
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      final fare = tester.widget<Text>(find.text('GH₵ 32.50'));
      expect(fare.style?.decoration, TextDecoration.lineThrough);
      expect(fare.style?.color, AppTheme.textSecondary);
    });

    testWidgets('gas order keeps its own labels', (tester) async {
      await tester.pumpWidget(_app(HistoryJobCard(
          trip: _job(type: JobType.gas, name: 'Gas delivery'))));
      expect(find.text('Gas'), findsOneWidget);
      expect(find.text('Gas order'), findsOneWidget);
      expect(find.byIcon(Icons.local_gas_station_rounded), findsWidgets);
    });

    testWidgets('fields the record lacks are left out, not shown as zero',
        (tester) async {
      await tester.pumpWidget(_app(HistoryJobCard(
          trip: _job(km: 0, minutes: 0, payment: '—', rating: 0))));
      expect(find.text('0.0 km'), findsNothing);
      expect(find.text('0 min'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('GH₵ 32.50'), findsOneWidget);
    });

    testWidgets('status pills are readable', (tester) async {
      await tester.pumpWidget(_app(Column(children: [
        HistoryJobCard(trip: _job()),
        HistoryJobCard(trip: _job(status: TripStatus.cancelled)),
      ])));
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final label in ['Completed', 'Cancelled']) {
        final text = tester.widget<Text>(find.text(label));
        final pill = tester.widget<Container>(
            find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
        final bg = (pill.decoration! as BoxDecoration).color!;
        expect(contrast(text.style!.color!, bg), greaterThanOrEqualTo(4.5),
            reason: label);
      }
    });
  });

  testWidgets('summary: labelled as fares, with counts and distance',
      (tester) async {
    await tester.pumpWidget(_app(const HistorySummaryCard(
      totalEarnings: 1520.75,
      totalDistance: 212.4,
      completedCount: 40,
      totalCount: 46,
      isDeliveryDriver: false,
    )));
    expect(find.text('Completed fares'), findsOneWidget);
    expect(find.text('GH₵ 1,520.75'), findsOneWidget);
    expect(find.text('Total trips'), findsOneWidget);
    expect(find.text('46'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('212 km'), findsOneWidget);
    expect(find.textContaining('Total fares on the completed trips'),
        findsOneWidget);

    await tester.pumpWidget(_app(const HistorySummaryCard(
      totalEarnings: 0,
      totalDistance: 0,
      completedCount: 0,
      totalCount: 0,
      isDeliveryDriver: true,
    )));
    expect(find.text('Total orders'), findsOneWidget);
  });

  test('empty-state copy follows search, tab and role', () {
    String title(String q, bool delivery, int tab, bool any) => historyEmptyCopy(
            query: q, isDeliveryDriver: delivery, tabIndex: tab, hasAny: any)
        .title;

    expect(title('', false, 0, false), 'No trips yet');
    expect(title('', true, 0, false), 'No orders yet');
    expect(title('osu', false, 0, true), 'No results found');
    expect(title('', false, 1, true), 'No completed trips');
    expect(title('', true, 2, true), 'No cancelled orders');
    // Nothing loaded at all: the tab doesn't matter.
    expect(title('', false, 2, false), 'No trips yet');
  });

  testWidgets('cards fit 320 px at 1.5× text', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const HistorySummaryCard(
              totalEarnings: 123456.78,
              totalDistance: 9876,
              completedCount: 140,
              totalCount: 150,
              isDeliveryDriver: true,
            ),
            HistoryJobCard(
                trip: _job(
                    name: 'A customer with a very long name indeed',
                    fare: 12345.67,
                    km: 123.4,
                    minutes: 145,
                    payment: 'Wallet',
                    pickup: 'A very long pickup address near the junction',
                    dropoff: 'Another long drop-off address by the market')),
            HistoryJobCard(
                trip: _job(
                    type: JobType.gas,
                    status: TripStatus.cancelled,
                    fare: 999.99)),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
