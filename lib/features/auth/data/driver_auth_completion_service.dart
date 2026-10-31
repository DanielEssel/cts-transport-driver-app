// lib/features/auth/data/driver_auth_completion_service.dart
//
// Firebase wiring for DriverAuthCompletion. Screens call
// driverAuthCompletion.complete(credential, isSignup: ..., phone: ...)
// and navigate to the returned destination.

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/driver_flow_resolver.dart';
import '../../../core/services/driver_service.dart';
import '../domain/driver_auth_completion.dart';

final driverAuthCompletion =
    DriverAuthCompletion<PhoneAuthCredential, RouteDestination>(
  signIn: (credential) async {
    final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    return user.uid;
  },
  provisionDriver: DriverService.createDriverDocument,
  resolve: AppFlowResolver.resolveDestination,
);
