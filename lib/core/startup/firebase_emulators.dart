// lib/core/startup/firebase_emulators.dart
//
// Local Firebase emulators for the `emulator` Android flavor (project
// demo-ctsgo-driver, android/app/src/emulator/google-services.json).
// Switched on only by --dart-define=USE_FIREBASE_EMULATORS=true. Any mismatch
// between that switch, the build mode, the Firebase project and the running
// emulators stops the app; it never falls back to a real project.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const bool kUseFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const String kFirebaseEmulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');

/// The only project the emulator build may use (a demo- project has no
/// real backend, so nothing it does can reach Google resources).
const String kEmulatorProjectId = 'demo-ctsgo-driver';

/// Ports from the emulators' firebase.json (emulator/firebase.json).
const Map<String, int> kEmulatorPorts = {
  'auth': 9099,
  'firestore': 8080,
  'functions': 5001,
  'storage': 9199,
};
const int kEmulatorHubPort = 4400;

/// Why this combination must not start, or null when it may.
///
/// Without the switch the project must be a real one (a demo- project is
/// only served by the emulators); with it the build must be debug, the
/// project [kEmulatorProjectId] and the host loopback (reached through
/// `adb reverse`; the emulator flavor allows plain HTTP to loopback only).
String? emulatorGuardError({
  required bool useEmulators,
  required bool releaseMode,
  required String projectId,
  required String host,
}) {
  if (!useEmulators) {
    return projectId.startsWith('demo-')
        ? 'This build uses $projectId, which exists only on the local '
            'emulators. Run it with --dart-define=USE_FIREBASE_EMULATORS=true.'
        : null;
  }
  if (releaseMode) {
    return 'Firebase emulators are not allowed in a release build.';
  }
  if (projectId != kEmulatorProjectId) {
    return 'USE_FIREBASE_EMULATORS=true needs project $kEmulatorProjectId '
        '(build with --flavor emulator), not $projectId.';
  }
  if (host != '127.0.0.1' && host != 'localhost') {
    return 'The emulator host must be loopback (127.0.0.1 over adb reverse), '
        'not $host.';
  }
  return null;
}

/// Why the hub's list of running emulators ([body] of GET /emulators) is not
/// what this app connects to, or null when every one runs on its port.
String? emulatorHubError(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return 'The emulator hub did not answer with a list of emulators.';
  }
  if (decoded is! Map) {
    return 'The emulator hub did not answer with a list of emulators.';
  }
  for (final e in kEmulatorPorts.entries) {
    final info = decoded[e.key];
    final port = info is Map ? info['port'] : null;
    if (port != e.value) {
      return info == null
          ? 'The ${e.key} emulator is not running.'
          : 'The ${e.key} emulator runs on port $port, not ${e.value}.';
    }
  }
  return null;
}

/// Checks the switch, then (when on) the running emulators, and points
/// Auth, Firestore, Functions and Storage at them. Throws [StateError]
/// instead of continuing on any mismatch. Call after Firebase.initializeApp
/// and before any other Firebase use, in every isolate that uses Firebase.
Future<void> connectFirebaseEmulators() async {
  final projectId = Firebase.app().options.projectId;
  final error = emulatorGuardError(
    useEmulators: kUseFirebaseEmulators,
    releaseMode: kReleaseMode,
    projectId: projectId,
    host: kFirebaseEmulatorHost,
  );
  if (error != null) throw StateError(error);
  if (!kUseFirebaseEmulators) return;

  await _requireRunningEmulators();

  const host = kFirebaseEmulatorHost;
  // automaticHostMapping would turn loopback into 10.0.2.2, which is the
  // host only from an Android emulator, not from a phone over adb reverse.
  await FirebaseAuth.instance.useAuthEmulator(host, kEmulatorPorts['auth']!,
      automaticHostMapping: false);
  FirebaseFirestore.instance.useFirestoreEmulator(
      host, kEmulatorPorts['firestore']!,
      automaticHostMapping: false);
  for (final functions in [
    FirebaseFunctions.instance,
    FirebaseFunctions.instanceFor(region: 'europe-west2'),
  ]) {
    functions.useFunctionsEmulator(host, kEmulatorPorts['functions']!,
        automaticHostMapping: false);
  }
  await FirebaseStorage.instance.useStorageEmulator(
      host, kEmulatorPorts['storage']!,
      automaticHostMapping: false);
  debugPrint('Firebase emulators: $projectId at $host');
}

Future<void> _requireRunningEmulators() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .getUrl(Uri.parse(
            'http://$kFirebaseEmulatorHost:$kEmulatorHubPort/emulators'))
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    final body = await response.transform(utf8.decoder).join();
    final error = response.statusCode == 200
        ? emulatorHubError(body)
        : 'The emulator hub answered ${response.statusCode}.';
    if (error != null) throw StateError(error);
  } on StateError {
    rethrow;
  } catch (e) {
    throw StateError('Cannot reach the Firebase emulators at '
        '$kFirebaseEmulatorHost:$kEmulatorHubPort ($e). Start them and run '
        'adb reverse first.');
  }
}

/// Shown instead of the app when [connectFirebaseEmulators] refuses to start.
class FirebaseEmulatorErrorApp extends StatelessWidget {
  final Object error;
  const FirebaseEmulatorErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = error is StateError ? (error as StateError).message : '$error';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFB91C1C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Firebase emulator check failed',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(message,
                    key: const Key('emulator-error'),
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
