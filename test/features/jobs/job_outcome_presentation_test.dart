// Presentation of the shared completed / ended screens and the ride detail
// widgets: one dominant action that calls back, readable sizes, no overflow
// on a small phone with large text. No Firebase is involved.

import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/jobs/domain/job_stage_plan.dart';
import 'package:cts_transport_driver_app/features/jobs/widgets/job_stage_panel.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:cts_transport_driver_app/features/trips/widgets/trip_metadata_chips.dart';
import 'package:cts_transport_driver_app/features/trips/widgets/trip_passenger_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.theme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    );

void _smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Smallest font size of any non-icon text under [root].
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
  group('JobCompletedScreen', () {
    Widget screen(VoidCallback onDone) => JobCompletedScreen(
          title: 'Delivery completed',
          message: 'The package was delivered.',
          amountLabel: 'Delivery fare',
          amount: 25,
          details: const [
            ('Parcel', 'Documents'),
            ('Delivered to', 'East Legon, Lagos Avenue, near the junction'),
          ],
          onDone: onDone,
        );

    testWidgets('shows the outcome and one action that calls back',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(_app(screen(() => done++)));

      expect(find.text('Delivery completed'), findsOneWidget);
      expect(find.text('DELIVERY FARE'), findsOneWidget);
      expect(find.text('GH₵ 25.00'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('job-completed-done')));
      expect(done, 1);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('fits a 320 px phone at 1.5× text, nothing under 12 px',
        (tester) async {
      _smallPhone(tester);
      await tester.pumpWidget(_app(screen(() {}), textScale: 1.5));
      expect(tester.takeException(), isNull);
      expect(_smallestFont(tester, find.byType(JobCompletedScreen)),
          greaterThanOrEqualTo(12));
    });
  });

  group('JobEndedScreen', () {
    testWidgets('defaults to Back to home', (tester) async {
      var done = 0;
      await tester.pumpWidget(_app(JobEndedScreen(
        icon: Icons.cancel_rounded,
        color: AppTheme.warning,
        title: 'Delivery cancelled',
        message: 'There is nothing more to do.',
        onDone: () => done++,
      )));
      expect(find.text('Delivery cancelled'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('job-ended-done')));
      expect(done, 1);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('keeps a caller label such as Go Back', (tester) async {
      var done = 0;
      await tester.pumpWidget(_app(JobEndedScreen(
        icon: Icons.cancel_rounded,
        color: AppTheme.danger,
        title: 'Trip Cancelled',
        message: 'Passenger cancelled this trip.',
        doneLabel: 'Go Back',
        doneIcon: Icons.arrow_back_rounded,
        onDone: () => done++,
      )));
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Back to home'), findsNothing);
      await tester.tap(find.text('Go Back'));
      expect(done, 1);
    });

    testWidgets('fits a 320 px phone at 1.5× text', (tester) async {
      _smallPhone(tester);
      await tester.pumpWidget(_app(
        JobEndedScreen(
          icon: Icons.error_outline_rounded,
          color: AppTheme.danger,
          title: "Can't continue this delivery",
          message: 'This delivery has a status this app version does not '
              'recognise ("someNewStatus"). Please update the app or '
              'contact support.',
          onDone: () {},
        ),
        textScale: 1.5,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('JobStageActions', () {
    // Near the drop-off the step is the primary action (far away,
    // navigation is primary; job_stage_actions_test covers that).
    testWidgets('primary step stays a FilledButton with readable text',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: JobStageActions(
          plan: ridePlan(RideStep.complete, metresToTarget: 0),
          busy: false,
          onStep: () {},
          onNavigate: () {},
        ),
      )));
      final step = find.byKey(const ValueKey('job-step-action'));
      expect(
          find.descendant(of: step, matching: find.byType(FilledButton)),
          findsOneWidget);
      expect(_smallestFont(tester, find.byType(JobStageActions)),
          greaterThanOrEqualTo(12));
      expect(tester.getSize(step).height, greaterThanOrEqualTo(56));
    });
  });

  group('Ride detail widgets', () {
    testWidgets('metadata tiles show time, distance and fare', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: TripMetadataChips(eta: '6 min', distanceKm: 2.1, fare: 42.5),
      )));
      expect(find.text('6 min'), findsOneWidget);
      expect(find.text('2.1 km'), findsOneWidget);
      expect(find.text('GHS 42.50'), findsOneWidget);
      expect(_smallestFont(tester, find.byType(TripMetadataChips)),
          greaterThanOrEqualTo(12));
    });

    testWidgets('metadata tiles fit a 320 px phone at 1.5× text',
        (tester) async {
      _smallPhone(tester);
      await tester.pumpWidget(_app(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: TripMetadataChips(
                eta: '< 1 min', distanceKm: 123.4, fare: 1234.5),
          ),
        ),
        textScale: 1.5,
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('passenger call is a 48 px button only with a phone',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: TripPassengerCard(
          name: 'Ama Mensah',
          rating: 4.8,
          phone: '+233200000000',
          onCall: () => calls++,
        ),
      )));
      final call = find.byTooltip('Call passenger');
      expect(call, findsOneWidget);
      expect(tester.getSize(call).height, greaterThanOrEqualTo(48));
      await tester.tap(call);
      expect(calls, 1);
      expect(find.text('4.8'), findsOneWidget);

      await tester.pumpWidget(_app(Scaffold(
        body: TripPassengerCard(name: 'Kofi', rating: 0, onCall: () {}),
      )));
      expect(find.byTooltip('Call passenger'), findsNothing);
      expect(find.text('New'), findsOneWidget);
    });
  });

  test('ride steps keep their order: arrive, start, complete', () {
    expect(ridePlan(RideStep.arrive).stepIndex,
        lessThan(ridePlan(RideStep.start).stepIndex));
    expect(ridePlan(RideStep.start).stepIndex,
        lessThan(ridePlan(RideStep.complete).stepIndex));
  });
}
