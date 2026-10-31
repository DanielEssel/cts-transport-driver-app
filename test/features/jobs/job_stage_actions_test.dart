// The shared tracking actions: one primary action, navigation never changes
// the status, busy and freshly shown stages ignore taps, and confirmations
// close only themselves.

import 'package:cts_transport_driver_app/features/jobs/domain/job_stage_plan.dart';
import 'package:cts_transport_driver_app/features/jobs/widgets/job_stage_panel.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _step = find.byKey(const ValueKey('job-step-action'));
final _nav = find.byKey(const ValueKey('job-navigate-action'));

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _settle(WidgetTester tester) =>
    tester.runAsync(() => Future<void>.delayed(
        JobStageActions.settleTime + const Duration(milliseconds: 50)));

bool _isPrimary(WidgetTester tester, Finder button) => find
    .descendant(of: button, matching: find.byType(FilledButton))
    .evaluate()
    .isNotEmpty;

void main() {
  late int steps;
  late int navigations;

  Widget actions(JobStagePlan plan, {bool busy = false}) => _host(
        JobStageActions(
          plan: plan,
          busy: busy,
          onStep: () => steps++,
          onNavigate: () => navigations++,
        ),
      );

  setUp(() {
    steps = 0;
    navigations = 0;
  });

  testWidgets('far from the pickup: Navigate is primary and shown first',
      (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.arrive)));
    expect(_isPrimary(tester, _nav), isTrue);
    expect(_isPrimary(tester, _step), isFalse);
    expect(tester.getTopLeft(_nav).dy, lessThan(tester.getTopLeft(_step).dy));
    expect(find.text('Navigate to pickup'), findsOneWidget);
    expect(find.text('Opens Google Maps'), findsOneWidget);
  });

  testWidgets('near the pickup: I\'ve arrived becomes primary', (tester) async {
    await tester
        .pumpWidget(actions(ridePlan(RideStep.arrive, metresToTarget: 60)));
    expect(_isPrimary(tester, _step), isTrue);
    expect(_isPrimary(tester, _nav), isFalse);
  });

  testWidgets('waiting at the pickup shows Start trip only', (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.start)));
    expect(_nav, findsNothing);
    expect(find.text('Start trip'), findsOneWidget);
    expect(_isPrimary(tester, _step), isTrue);
  });

  testWidgets('navigating never applies a status step', (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.arrive)));
    await _settle(tester);
    await tester.tap(_nav);
    await tester.pump();
    expect(navigations, 1);
    expect(steps, 0);
  });

  testWidgets('a tap right as a stage appears is ignored', (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.start)));
    await tester.tap(_step);
    expect(steps, 0);
    await _settle(tester);
    await tester.tap(_step);
    expect(steps, 1);
  });

  testWidgets('a double tap does not carry into the next stage',
      (tester) async {
    await tester.pumpWidget(
        actions(deliveryPlan('pickupEnroute', metresToTarget: 20)!));
    await _settle(tester);
    await tester.tap(_step); // I've arrived at pickup
    expect(steps, 1);
    // The stored status moves on; the second tap lands on the next stage.
    await tester.pumpWidget(actions(deliveryPlan('arrivedAtPickup')!));
    await tester.tap(_step); // would be "I have the parcel"
    expect(steps, 1);
  });

  testWidgets('while a step is being written, taps are ignored',
      (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.start), busy: true));
    await _settle(tester);
    await tester.tap(_step);
    expect(steps, 0);
    expect(find.text('Updating…'), findsOneWidget);
  });

  testWidgets('the step button is large enough to tap comfortably',
      (tester) async {
    await tester.pumpWidget(actions(ridePlan(RideStep.arrive)));
    expect(tester.getSize(_step).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(_nav).height, greaterThanOrEqualTo(48));
  });

  testWidgets('progress is announced as a step count', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
        _host(const JobStepProgress(steps: deliverySteps, current: 1)));
    expect(find.bySemanticsLabel('Step 2 of 4: Collect'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('every stage fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final plans = <JobStagePlan>[
      for (final s in RideStep.values) ...[
        ridePlan(s),
        ridePlan(s, metresToTarget: 10),
      ],
      for (final s in [
        'driverAssigned',
        'pickupEnroute',
        'arrivedAtPickup',
        'packagePicked',
        'deliveryEnroute',
        'arrivedAtDropoff',
      ])
        deliveryPlan(s, hasOtp: true)!,
      for (final s in [
        'driverAssigned',
        'driverEnRoute',
        'driverArrived',
        'pickedUp',
        'atStation',
        'refilling',
        'returning',
      ])
        gasPlan(s, refillType: 'pickupAndReturn')!,
    ];

    for (final plan in plans) {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: JobStageHeader(plan: plan),
                  ),
                ),
                JobActionFooter(
                  child: JobStageActions(
                    plan: plan,
                    busy: false,
                    onStep: () {},
                    onNavigate: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: plan.step.label);
    }
  });

  group('confirmations', () {
    Future<bool?> openConfirm(
        WidgetTester tester, Future<bool> Function(BuildContext) open) async {
      bool? result;
      await tester.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await open(context),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('going back returns false and keeps the screen',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showJobConfirm(context,
              title: 'Cancel this trip?',
              message: 'm',
              confirmLabel: 'Cancel trip',
              keepLabel: 'Keep trip',
              destructive: true),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep trip'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('open'), findsOneWidget); // screen still there
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('arrival far from the target asks first', (tester) async {
      await openConfirm(
          tester,
          (c) => confirmArrival(c,
              place: 'pickup', whoIsTold: 'passenger', metresToTarget: 1400));
      expect(find.text('Are you at the pickup?'), findsOneWidget);
      expect(find.textContaining('1.4 km'), findsOneWidget);
    });

    testWidgets('arrival near the target does not ask', (tester) async {
      await openConfirm(
          tester,
          (c) => confirmArrival(c,
              place: 'pickup', whoIsTold: 'passenger', metresToTarget: 40));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
