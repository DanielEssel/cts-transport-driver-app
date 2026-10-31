// The map-first tracking layout: the sheet collapses to a compact summary
// and expands to the full details, the stage's actions stay pinned and
// usable in every position, dragging never presses an action, and the
// layout fits small phones with large text.

import 'package:cts_transport_driver_app/features/jobs/domain/job_stage_plan.dart';
import 'package:cts_transport_driver_app/features/jobs/widgets/job_map_layout.dart';
import 'package:cts_transport_driver_app/features/jobs/widgets/job_stage_panel.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _step = find.byKey(const ValueKey('job-step-action'));
final _sheet = find.byKey(const ValueKey('job-sheet'));
final _handle = find.byKey(const ValueKey('job-sheet-handle'));
final _toggle = find.byKey(const ValueKey('job-sheet-toggle'));
final _recenter = find.byKey(const ValueKey('job-map-recenter'));
final _detail = find.byKey(const ValueKey('test-detail'));
final _map = find.byKey(const ValueKey('test-map'));

Future<void> _settle(WidgetTester tester) =>
    tester.runAsync(() => Future<void>.delayed(
        JobStageActions.settleTime + const Duration(milliseconds: 50)));

void main() {
  late int steps;
  late int recenters;
  late int mapBuilds;
  late EdgeInsets mapPadding;

  setUp(() {
    steps = 0;
    recenters = 0;
    mapBuilds = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    JobStagePlan plan, {
    Size size = const Size(390, 844),
    double textScale = 1,
    String? eta,
    String? destination = '12 Ring Road, Accra',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: JobMapLayout(
          plan: plan,
          destinationLabel: 'Pickup',
          destination: destination,
          eta: eta,
          onBack: () {},
          onCall: () {},
          onRecenter: () => recenters++,
          mapBuilder: (context, padding) {
            mapBuilds++;
            mapPadding = padding;
            return const ColoredBox(
              key: ValueKey('test-map'),
              color: Color(0xFFE5E7EB),
            );
          },
          details: [
            Container(
              key: const ValueKey('test-detail'),
              height: 400,
              color: Colors.white,
              child: const Text('Passenger: Ama'),
            ),
          ],
          actions: JobStageActions(
            plan: plan,
            busy: false,
            onStep: () => steps++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double sheetTop(WidgetTester tester) => tester.getTopLeft(_sheet).dy;

  bool visible(WidgetTester tester, Finder f) {
    final rect = tester.getRect(f);
    final sheet = tester.getRect(_sheet);
    final screenBottom = tester.getTopLeft(_step).dy; // above pinned actions
    return rect.top < screenBottom && rect.bottom > sheet.top;
  }

  testWidgets('opens at the middle: summary, map and pinned action visible',
      (tester) async {
    await pump(tester, ridePlan(RideStep.start));
    expect(find.text('Wait for the passenger'), findsOneWidget);
    expect(find.text('STEP 2 OF 3 · PICK UP'), findsOneWidget);
    expect(find.text('Pickup · 12 Ring Road, Accra'), findsOneWidget);
    expect(_map, findsOneWidget);
    expect(_step, findsOneWidget);
    // The map reaches up under the sheet; its padding keeps the camera's
    // framing clear of the sheet.
    expect(mapPadding.bottom, greaterThan(300));
    final top = sheetTop(tester);
    expect(top, greaterThan(844 * 0.3));
    expect(top, lessThan(844 * 0.7));
  });

  testWidgets('collapses to the summary for a near full-screen map',
      (tester) async {
    await pump(tester, ridePlan(RideStep.start));
    final mid = sheetTop(tester);

    await tester.tap(_handle);
    await tester.pumpAndSettle();

    expect(sheetTop(tester), greaterThan(mid + 150));
    expect(find.text('Wait for the passenger'), findsOneWidget);
    expect(visible(tester, find.text('Wait for the passenger')), isTrue);
    expect(visible(tester, _detail), isFalse);
    // Re-centre follows the sheet down and still works.
    await tester.tap(_recenter);
    expect(recenters, 1);

    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(sheetTop(tester), moreOrLessEquals(mid, epsilon: 1));
  });

  testWidgets('expands to the full details and back', (tester) async {
    await pump(tester, ridePlan(RideStep.start));
    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    // Fully open, the sheet stops below the floating back button.
    expect(sheetTop(tester), greaterThan(24 + 12 + 48));
    expect(sheetTop(tester), lessThan(844 * 0.2));
    expect(visible(tester, _detail), isTrue);
    expect(find.text('Passenger: Ama'), findsOneWidget);
    // Re-centre is hidden while the details cover the map.
    expect(
      tester.widget<IgnorePointer>(find.ancestor(
          of: _recenter, matching: find.byType(IgnorePointer)).first).ignoring,
      isTrue,
    );

    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(visible(tester, _detail), isFalse);
  });

  testWidgets('dragging the sheet snaps and never presses the action',
      (tester) async {
    await pump(tester, ridePlan(RideStep.start));
    await _settle(tester);
    final mid = sheetTop(tester);

    await tester.drag(find.text('Wait for the passenger'),
        const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(sheetTop(tester), lessThan(mid - 200));

    await tester.drag(find.text('Wait for the passenger'),
        const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(sheetTop(tester), greaterThan(mid));
    expect(steps, 0);

    // The pinned action still works after dragging.
    await tester.tap(_step);
    expect(steps, 1);
  });

  testWidgets('dragging does not rebuild the map', (tester) async {
    await pump(tester, ridePlan(RideStep.start));
    final builds = mapBuilds;
    await tester.drag(find.text('Wait for the passenger'),
        const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(mapBuilds, builds);
  });

  testWidgets('ETA shows only when given', (tester) async {
    await pump(tester, ridePlan(RideStep.arrive));
    expect(find.byKey(const ValueKey('job-sheet-eta')), findsNothing);

    await pump(tester, ridePlan(RideStep.arrive), eta: '6 min · 2.1 km');
    expect(find.text('6 min · 2.1 km'), findsOneWidget);
  });

  testWidgets('delivery and gas stages show their own summary',
      (tester) async {
    final delivery = deliveryPlan('packagePicked')!;
    await pump(tester, delivery);
    expect(find.text(delivery.title), findsOneWidget);
    expect(_step, findsOneWidget);

    final gas = gasPlan('driverEnRoute', refillType: 'swap')!;
    await pump(tester, gas);
    expect(find.text(gas.title), findsOneWidget);
    expect(
      find.text('STEP ${gas.stepIndex + 1} OF ${gas.steps.length}'
          ' · ${gas.steps[gas.stepIndex].toUpperCase()}'),
      findsOneWidget,
    );
  });

  for (final (name, size, scale) in [
    ('small phone', const Size(320, 568), 1.0),
    ('small phone, large text', const Size(320, 568), 2.0),
    ('landscape', const Size(740, 360), 1.0),
  ]) {
    testWidgets('fits a $name in every sheet position', (tester) async {
      await pump(
        tester,
        deliveryPlan('arrivedAtDropoff', hasOtp: true)!,
        size: size,
        textScale: scale,
        destination: 'A very long drop-off address that will certainly not '
            'fit on one line of a small phone screen, Accra',
      );
      expect(tester.takeException(), isNull);
      expect(_step, findsOneWidget);

      await tester.tap(_handle);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(visible(tester, _toggle), isTrue);

      await tester.tap(_toggle);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _settle(tester);
      await tester.tap(_step);
      expect(steps, 1);
    });
  }
}
