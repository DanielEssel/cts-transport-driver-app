// driver_app/lib/main.dart

import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'app/app_routes.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/otp_verification_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'features/driver/presentation/driver_documents_screens.dart';
import 'features/driver/models/driver_type.dart';
import 'features/driver/presentation/driver_vehicle_setup_screen.dart';
import 'features/driver_auth/presentation/screens/driver_phone_screen.dart';
import 'features/driver_auth/presentation/screens/driver_account_setup_screen.dart';
import 'features/driver_auth/presentation/screens/driver_login_screen.dart';
import 'features/driver_auth/presentation/screens/driver_forgot_password_screen.dart';
import '../../../features/root/driver_root_shell.dart'; // Import the driver shell
import 'features/driver/presentation/driver_pending_screen.dart';

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
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signup: (context) => const SignupScreen(),
        AppRoutes.otpVerification: (context) => const OtpVerificationScreen(),
        AppRoutes.roleSelection: (context) => const RoleSelectionScreen(),
        AppRoutes.driverPhone: (context) => const DriverPhoneScreen(),
        AppRoutes.driverPending: (context) => const DriverPendingScreen(),
        AppRoutes.driverShell: (context) {
          final driverType =
              ModalRoute.of(context)!.settings.arguments as DriverType;
          return DriverRootShell(driverType: driverType);
        },
        AppRoutes.driverAccountSetup: (context) {
          final phone = ModalRoute.of(context)!.settings.arguments as String;
          return DriverAccountSetupScreen(phone: phone);
        },
        AppRoutes.driverLogin: (context) => const DriverLoginScreen(),
        AppRoutes.driverForgotPassword: (context) =>
            const DriverForgotPasswordScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle routes that need arguments
        if (settings.name == AppRoutes.driverDocuments) {
          final driverType = settings.arguments as DriverType;
          return MaterialPageRoute(
            builder: (context) => DriverDocumentsScreen(driverType: driverType),
          );
        }

        // Handle driver vehicle setup if needed
        if (settings.name == AppRoutes.driverVehicleSetup) {
          return MaterialPageRoute(
            builder: (context) => const DriverVehicleSetupScreen(),
          );
        }

        if (settings.name == AppRoutes.driverShell) {
          final driverType = settings.arguments as DriverType;
          return MaterialPageRoute(
            builder: (_) => DriverRootShell(driverType: driverType),
          );
        }

        // If no route matches
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
      },
    );
  }
}
