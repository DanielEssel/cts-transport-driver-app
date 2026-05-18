// lib/core/startup/startup_resolver.dart

import 'package:firebase_auth/firebase_auth.dart';

import '../../app/app_routes.dart';
import '../services/local/onboarding_local_service.dart';
import '../services/driver_flow_resolver.dart';

class StartupResolver {
  static Future<RouteDestination> resolve() async {
    /// 1️⃣ First open → show walkthrough
    final seenWalkthrough = await OnboardingLocalService.isCompleted();
    if (!seenWalkthrough) {
      return const RouteDestination(AppRoutes.onboarding);
    }

    /// 2️⃣ Not logged in → login
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const RouteDestination(AppRoutes.login);
    }

    /// 3️⃣ Logged in → resolve full driver flow with typed arguments
    return AppFlowResolver.resolveDestination(user.uid);
  }
}