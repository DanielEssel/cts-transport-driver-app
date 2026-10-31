// The shared CTSGo green treatment (the Wallet card's greens): brand
// colours, deep-green primary buttons with white text, the gradient on the
// Home online card, and the WCAG contrast of each pairing.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/requests_section.dart';
import 'package:cts_transport_driver_app/features/jobs/widgets/job_stage_panel.dart';
import 'package:cts_transport_driver_app/features/jobs/domain/job_stage_plan.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _brand = Color(0xFF16A34A);
const _deep = Color(0xFF15803D);
const _tint = Color(0xFFDCFCE7);

/// WCAG 2.1 contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [top] (translucent) composited over [bottom].
Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

/// The colours a button actually paints with: its Material's fill and text.
({Color? fill, Color? text}) _painted(WidgetTester tester, Finder button) {
  final material = tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first);
  return (fill: material.color, text: material.textStyle?.color);
}

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

void main() {
  group('Brand tokens', () {
    test('primary stays #16A34A, deep green #15803D, tint #DCFCE7', () {
      expect(AppTheme.primary, _brand);
      expect(AppTheme.primaryDark, _deep);
      expect(AppTheme.primarySubtle, _tint);
      expect(AppTheme.theme.colorScheme.primary, _brand);
      expect(AppTheme.theme.primaryColor, _brand);
    });

    test('the gradient is the Wallet card: #16A34A to #15803D, diagonal', () {
      const g = AppTheme.primaryGradient;
      expect(g.colors, [_brand, _deep]);
      expect(g.begin, Alignment.topLeft);
      expect(g.end, Alignment.bottomRight);
    });

    test('service accents are unchanged', () {
      expect(AppTheme.serviceDelivery, const Color(0xFF0369A1));
      expect(AppTheme.serviceDeliveryTint, const Color(0xFFE0F2FE));
      expect(AppTheme.serviceGas, const Color(0xFFC2410C));
      expect(AppTheme.serviceGasTint, const Color(0xFFFFF1E6));
    });
  });

  group('Contrast', () {
    test('white on the deep-green button passes normal text (4.5:1)', () {
      expect(AppTheme.onPrimary, Colors.white);
      expect(_contrast(Colors.white, _deep), greaterThanOrEqualTo(4.5));
    });

    test('white on #16A34A is below 4.5:1, so buttons do not use it', () {
      expect(_contrast(Colors.white, _brand), lessThan(4.5));
      expect(_contrast(Colors.white, _brand), greaterThanOrEqualTo(3.0));
    });

    test('green text on white uses the deep green (4.5:1)', () {
      expect(_contrast(_deep, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(_deep, AppTheme.background), greaterThanOrEqualTo(4.5));
    });

    test('small white text on the gradient scrim passes at the light end', () {
      for (final g in AppTheme.primaryGradient.colors) {
        expect(
            _contrast(Colors.white, _over(AppTheme.onGradientScrim, g)),
            greaterThanOrEqualTo(4.5),
            reason: '$g');
      }
    });

    test('large white text passes 3:1 anywhere on the gradient', () {
      for (final g in AppTheme.primaryGradient.colors) {
        expect(_contrast(Colors.white, g), greaterThanOrEqualTo(3.0));
      }
    });
  });

  group('Shared primary buttons', () {
    testWidgets('themed Filled and Elevated buttons: deep green, white text',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
        ]),
      )));
      for (final type in [FilledButton, ElevatedButton]) {
        final c = _painted(tester, find.byType(type));
        expect(c.fill, _deep, reason: '$type');
        expect(c.text, Colors.white, reason: '$type');
      }
    });

    testWidgets('job-stage primary action: deep green, white, busy too',
        (tester) async {
      for (final busy in [false, true]) {
        await tester.pumpWidget(_app(Scaffold(
          body: JobStageActions(
            plan: ridePlan(RideStep.complete, metresToTarget: 0),
            busy: busy,
            onStep: () {},
            onNavigate: () {},
          ),
        )));
        final c = _painted(
            tester,
            find.descendant(
                of: find.byKey(const ValueKey('job-step-action')),
                matching: find.byType(FilledButton)));
        expect(c.fill, _deep, reason: 'busy=$busy');
        expect(c.text, Colors.white, reason: 'busy=$busy');
      }
    });

    testWidgets('job-stage navigate action, when primary, is the same',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: JobStageActions(
          plan: ridePlan(RideStep.arrive), // far away: navigate is primary
          busy: false,
          onStep: () {},
          onNavigate: () {},
        ),
      )));
      final c = _painted(
          tester,
          find.descendant(
              of: find.byKey(const ValueKey('job-navigate-action')),
              matching: find.byType(FilledButton)));
      expect(c.fill, _deep);
      expect(c.text, Colors.white);
    });

    testWidgets('completed / ended footer button: deep green, white',
        (tester) async {
      await tester.pumpWidget(_app(JobEndedScreen(
        icon: Icons.cancel_rounded,
        color: AppTheme.warning,
        title: 'Delivery cancelled',
        message: 'There is nothing more to do.',
        onDone: () {},
      )));
      final c = _painted(tester, find.byKey(const ValueKey('job-ended-done')));
      expect(c.fill, _deep);
      expect(c.text, Colors.white);
    });

    testWidgets('confirm dialog: deep green confirm, red when destructive',
        (tester) async {
      for (final destructive in [false, true]) {
        await tester.pumpWidget(_app(Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showJobConfirm(context,
                  title: 'Complete trip?',
                  message: 'This ends the trip.',
                  confirmLabel: 'Yes, complete',
                  destructive: destructive),
              child: const Text('open'),
            ),
          ),
        )));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final c = _painted(tester,
            find.widgetWithText(FilledButton, 'Yes, complete'));
        expect(c.fill, destructive ? AppTheme.danger : _deep);
        expect(c.text, Colors.white);
        expect(_contrast(c.text!, c.fill!), greaterThanOrEqualTo(4.5));
        await tester.tap(find.text('Go back'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('request Accept button: deep green, white', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pendingRequestsProvider.overrideWith((ref, driver) => AsyncValue.data([
                AvailableRequest(
                  id: 't1',
                  passengerId: 'p',
                  type: RequestType.ride,
                  status: 'searching',
                  pickupAddress: 'Osu',
                  dropoffAddress: 'Airport',
                  pickupLocation: const GeoPoint(5.6, -0.18),
                  dropoffLocation: const GeoPoint(5.61, -0.17),
                  fare: 20,
                  createdAt: DateTime.now(),
                  collection: 'trips',
                ),
              ])),
        ],
        child: _app(Scaffold(
          body: SingleChildScrollView(
            child: RequestsSection(
              // Eligible to take requests, so the cards are shown.
              driver: const DriverProfile(
                uid: 'd',
                service: DriverServiceType.ride,
                role: 'driver_hailing',
                serviceType: 'taxi',
                vehicleType: DriverVehicleType.taxi,
                vehicleTypeRaw: 'taxi',
                isApproved: true,
                isOnline: true,
                isAvailable: true,
                dispatchLocation: GeoPoint(5.6037, -0.187),
              ),
              isOnline: true,
              onGoOnline: () {},
            ),
          ),
        )),
      ));
      final c =
          _painted(tester, find.widgetWithText(FilledButton, 'Accept Ride'));
      expect(c.fill, _deep);
      expect(c.text, Colors.white);
    });
  });

  group('Home status card', () {
    testWidgets('online uses the Wallet gradient and glow', (tester) async {
      await tester.pumpWidget(
          _app(Scaffold(body: HomeStatusCard(isOnline: true, onToggle: () {}))));
      final box = tester
          .widget<Container>(find.byKey(const ValueKey('home-status-card')))
          .decoration! as BoxDecoration;
      expect(box.gradient, AppTheme.primaryGradient);
      expect(box.boxShadow!.first.color, _brand.withValues(alpha: 0.35));

      // Go Offline: white button with deep-green text.
      final c = _painted(tester, find.widgetWithText(OutlinedButton, 'Go Offline'));
      expect(c.fill, Colors.white);
      expect(_contrast(c.text!, Colors.white), greaterThanOrEqualTo(4.5));
    });

    testWidgets('offline is white with a deep-green Go Online', (tester) async {
      await tester.pumpWidget(
          _app(Scaffold(body: HomeStatusCard(isOnline: false, onToggle: () {}))));
      final box = tester
          .widget<Container>(find.byKey(const ValueKey('home-status-card')))
          .decoration! as BoxDecoration;
      expect(box.gradient, isNull);
      expect(box.color, AppTheme.surface);
      final c = _painted(tester, find.widgetWithText(FilledButton, 'Go Online'));
      expect(c.fill, _deep);
      expect(c.text, Colors.white);
    });

    testWidgets('online card fits 320 px at 1.5× text', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeStatusCard(isOnline: true, onToggle: () {}),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  test('ride steps keep their order', () {
    expect(ridePlan(RideStep.arrive).stepIndex, 0);
    expect(ridePlan(RideStep.start).stepIndex, 1);
    expect(ridePlan(RideStep.complete).stepIndex, 2);
    expect(ridePlan(RideStep.complete).step.guard, JobGuard.complete);
  });
}
