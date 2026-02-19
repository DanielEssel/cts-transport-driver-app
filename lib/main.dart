// driver_app/lib/main.dart

import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/routes/app_routes.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';  // ✅ ADD THIS
import 'features/driver/presentation/driver_home_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/otp_verification_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';

void main() {
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CTS Transport - Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        // Auth Routes
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),  // ✅ ADD THIS
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signup: (context) => const SignupScreen(),
        AppRoutes.otpVerification: (context) => const OtpVerificationScreen(),
        AppRoutes.roleSelection: (context) => const RoleSelectionScreen(),
        
        // Driver Routes
        AppRoutes.driverHome: (context) => const DriverHomeScreen(),
      },
    );
  }
}