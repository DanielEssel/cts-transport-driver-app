import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/driver/services/driver_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'app/app_routes.dart';
import 'features/driver/models/driver_types.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/otp_verification_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'features/driver/presentation/driver_documents_screens.dart';
import 'features/driver/presentation/driver_vehicle_setup_screen.dart';
import 'features/driver_auth/presentation/screens/driver_phone_screen.dart';
import 'features/driver_auth/presentation/screens/driver_account_setup_screen.dart';
import 'features/driver_auth/presentation/screens/driver_forgot_password_screen.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/driver/presentation/driver_pending_screen.dart';
import 'features/root/driver_root_shell.dart';
import 'features/trips/presentation/active_trip_screen.dart';
import 'features/driver/presentation/driver_notifications_screen.dart';
import 'features/driver/presentation/driver_support_screen.dart';
import 'features/driver/presentation/driver_settings_screen.dart';
import 'features/driver/presentation/withdrawal_screen.dart';
import 'features/driver/presentation/trip_history_screen.dart';
import 'features/earnings/presentation/screens/earning_screen.dart';
import 'features/jobs/screens/active_delivery_screen.dart';
import 'features/jobs/screens/active_gas_order_screen.dart';
import 'features/wallet/presentation/screens/driver_wallet_screen.dart';
import 'features/profile/presentation/screens/driver_profile_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/services/pricing_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PricingService.instance.fetch();

  final title = message.data['title'] as String?;
  final body = message.data['body'] as String?;
  if (title == null || body == null) return;

  final local = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await local.initialize(const InitializationSettings(android: androidInit));

  final channelId = _channelIdForType(message.data['type'] as String? ?? '');

  await local.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelNameFor(channelId),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: message.data['route'] as String?,
  );

  debugPrint('📩 Background FCM: ${message.messageId}, title=$title');
}

String _channelIdForType(String type) {
  switch (type) {
    case 'ride':
    case 'delivery':
    case 'gas':
    case 'NEW_RIDE_REQUEST':
    case 'NEW_DELIVERY_REQUEST':
    case 'NEW_GAS_REQUEST':
      return 'driver_trips';
    case 'documentExpiry':
    case 'account_approved':
    case 'documents_rejected':
      return 'driver_alerts';
    default:
      return 'CTSDriver_general';
  }
}

String _channelNameFor(String channelId) => switch (channelId) {
      'driver_trips' => 'Trip Requests',
      'driver_alerts' => 'Driver Alerts',
      _ => 'General Notifications',
    };

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Fix Firestore connectivity on Android
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await FirebaseMessaging.instance.requestPermission();

  // Initialize driver notification service
  final navigatorKey = GlobalKey<NavigatorState>();

  await DriverNotificationService.instance.initialize(navigatorKey);

  runApp(ProviderScope(child: DriverApp(navigatorKey: navigatorKey)));
}

class DriverApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const DriverApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CTS Go Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,

      // ── Static routes (no arguments needed) ───────────────────────────────
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.otpVerification: (_) => const OtpVerificationScreen(),
        AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.driverForgotPassword: (_) =>
            const DriverForgotPasswordScreen(),
        AppRoutes.driverPending: (_) => const DriverPendingScreen(),
        AppRoutes.driverVehicleSetup: (_) => const DriverVehicleSetupScreen(),
        AppRoutes.driverDocuments: (_) => const DriverDocumentsScreen(),
        AppRoutes.notifications: (_) => const DriverNotificationsScreen(),
        AppRoutes.support: (_) => const DriverSupportScreen(),
        AppRoutes.settings: (_) => const DriverSettingsScreen(),
        AppRoutes.earnings: (_) => const EarningsScreen(),
        AppRoutes.driverWallet: (_) => const DriverWalletScreen(),
        AppRoutes.withdrawal: (_) => const WithdrawalScreen(),
        AppRoutes.tripHistory: (_) => const TripHistoryScreen(),
      },

      // ── Dynamic routes (require typed arguments) ───────────────────────────
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
          case AppRoutes.driverShell:
            if (args is DriverProfile) {
              return _route(DriverRootShell(profile: args));
            }
            assert(false,
                'driverShell requires DriverProfile, got: ${args.runtimeType}');
            return _unknownRoute(settings.name);

          case AppRoutes.driverProfile:
            if (args is DriverProfile) {
              return _route(DriverProfileScreen(profile: args)); // ✅
            }
            return _unknownRoute(settings.name);

          case AppRoutes.driverPhone:
            String phone = '';
            if (args is Map<String, dynamic>) {
              phone = args['phone'] as String? ?? '';
            } else if (args is String) {
              phone = args;
            }
            return _route(DriverPhoneScreen(verifiedPhone: phone));

          case AppRoutes.driverAccountSetup:
            final phone = args is String ? args : '';
            return _route(DriverAccountSetupScreen(phone: phone));

          case AppRoutes.activeTrip:
            final tripId = args is Map<String, dynamic>
                ? args['tripId'] as String? ?? ''
                : args is String
                    ? args
                    : '';
            return _route(ActiveTripScreen(tripId: tripId));

          case AppRoutes.activeDelivery:
            final deliveryId = args is Map<String, dynamic>
                ? args['deliveryId'] as String? ?? ''
                : '';
            return _route(ActiveDeliveryScreen(deliveryId: deliveryId));

          case AppRoutes.activeGas:
            final orderId = args is Map<String, dynamic>
                ? args['orderId'] as String? ?? ''
                : '';
            return _route(ActiveGasOrderScreen(orderId: orderId));

          default:
            return _unknownRoute(settings.name);
        }
      },
    );
  }

  static MaterialPageRoute _route(Widget screen) =>
      MaterialPageRoute(builder: (_) => screen);

  static MaterialPageRoute _unknownRoute(String? name) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not Found')),
          body: Center(
            child: Text(
              'No route defined for "$name"',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
}
