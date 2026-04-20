// app/app_routes.dart

class AppRoutes {
  // ───────────────── AUTH FLOW ─────────────────
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const otpVerification = '/otp-verification';
  static const roleSelection = '/role-selection';
  static const String driverPhone = '/driver-phone';
  static const String driverAccountSetup = '/driver-account-setup';
  static const String driverLogin = '/driver-login';
  static const String driverForgotPassword = '/driver-forgot-password';

  // ───────────── DRIVER ONBOARDING FLOW ─────────────
  static const driverVehicleSetup = '/driver-vehicle-setup';
  static const driverDocuments = '/driver-documents';
  static const driverPending = '/driver-pending';

  // ───────────── APP SHELLS ─────────────
  // These are navigated using MaterialPageRoute
  // DriverRootShell(driverType)
  // RiderRootShell()
  static const driverShell = '/driver-shell';

  // ───────────── DRIVER FULLSCREEN SCREENS ─────────────
  static const activeRide = '/active-ride';
  static const activeDelivery = '/active-delivery';

  // ───────────── PROFILE SCREENS ─────────────
  static const editProfile = '/edit-profile';
  static const savedPlaces = '/saved-places';
  static const paymentMethods = '/payment-methods';
  static const promotions = '/promotions';
  static const privacySecurity = '/privacy-security';
  static const helpSupport = '/help-support';
  static const about = '/about';

  // ───────────── WALLET / EARNINGS ─────────────
  static const transactionDetail = '/transaction-detail';
  static const tripHistory = '/trip-history';
  static const withdrawal = '/withdrawal';

  static const earnings = 'earnings';
  static const driverWallet = 'driver-wallet';
}
