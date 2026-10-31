import 'package:flutter_test/flutter_test.dart';

import 'package:cts_transport_driver_app/core/startup/firebase_emulators.dart';

void main() {
  String? guard({
    bool use = true,
    bool release = false,
    String project = 'demo-ctsgo-driver',
    String host = '127.0.0.1',
  }) =>
      emulatorGuardError(
          useEmulators: use, releaseMode: release, projectId: project, host: host);

  group('emulatorGuardError', () {
    test('prod build without the switch starts', () {
      expect(guard(use: false, project: 'ctstransportapp'), isNull);
    });

    test('emulator build without the switch refuses', () {
      expect(guard(use: false), contains('USE_FIREBASE_EMULATORS=true'));
      expect(guard(use: false, project: 'demo-other'), isNotNull);
    });

    test('switch on with the production project refuses', () {
      expect(guard(project: 'ctstransportapp'), contains('--flavor emulator'));
    });

    test('switch on with another demo project refuses', () {
      expect(guard(project: 'demo-ctsgo-payments'), isNotNull);
    });

    test('switch on in a release build refuses', () {
      expect(guard(release: true), contains('release'));
    });

    test('switch on with a non-loopback host refuses', () {
      expect(guard(host: '10.0.2.2'), contains('loopback'));
      expect(guard(host: '192.168.1.20'), contains('loopback'));
    });

    test('switch on, debug, demo-ctsgo-driver, loopback starts', () {
      expect(guard(), isNull);
      expect(guard(host: 'localhost'), isNull);
    });
  });

  group('emulatorHubError', () {
    const all = '{"hub":{"port":4400},"auth":{"port":9099},'
        '"firestore":{"port":8080},"functions":{"port":5001},'
        '"storage":{"port":9199}}';

    test('every emulator on its port passes', () {
      expect(emulatorHubError(all), isNull);
    });

    test('a missing emulator fails', () {
      expect(emulatorHubError(all.replaceFirst('"storage"', '"database"')),
          'The storage emulator is not running.');
    });

    test('an emulator on another port fails', () {
      expect(emulatorHubError(all.replaceFirst('8080', '8188')),
          'The firestore emulator runs on port 8188, not 8080.');
    });

    test('a body that is not a list of emulators fails', () {
      expect(emulatorHubError('not json'), isNotNull);
      expect(emulatorHubError('[]'), isNotNull);
    });
  });
}
