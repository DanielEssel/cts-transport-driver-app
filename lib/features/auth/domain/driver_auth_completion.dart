// lib/features/auth/domain/driver_auth_completion.dart
//
// AUTH-08 / AUTH-09: the one path from a verified phone credential to the
// driver's next screen, shared by automatic verification (instant or
// auto-retrieved SMS) and manual OTP entry on login and sign-up.
//
//   sign in → (sign-up only) provision drivers/{uid} → AppFlowResolver
//
// Routing always goes through the resolver, so role, onboarding and approval
// checks are never bypassed. If automatic and manual completion overlap,
// they share one run: the credential is consumed once and the profile is
// provisioned once.

class DriverAuthCompletion<C, R> {
  DriverAuthCompletion({
    required this.signIn,
    required this.provisionDriver,
    required this.resolve,
  });

  /// Signs in with the credential and returns the uid.
  final Future<String> Function(C credential) signIn;

  /// Creates drivers/{uid} if it does not exist (idempotent).
  final Future<void> Function(String phone) provisionDriver;

  /// Decides the next route for uid (AppFlowResolver.resolveDestination).
  final Future<R> Function(String uid) resolve;

  Future<R>? _inFlight;

  Future<R> complete(
    C credential, {
    required bool isSignup,
    required String phone,
  }) {
    return _inFlight ??= _run(credential, isSignup: isSignup, phone: phone)
        .whenComplete(() => _inFlight = null);
  }

  Future<R> _run(C credential,
      {required bool isSignup, required String phone}) async {
    final uid = await signIn(credential);
    if (isSignup) await provisionDriver(phone);
    return resolve(uid);
  }
}
