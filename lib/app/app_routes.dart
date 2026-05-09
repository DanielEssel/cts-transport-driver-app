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
  static const String driverForgotPassword = '/driver-forgot-password';

  // ───────────── DRIVER ONBOARDING FLOW ─────────────
  static const driverVehicleSetup = '/driver-vehicle-setup';
  static const driverDocuments = '/driver-documents';
  static const driverPending = '/driver-pending';

  // ───────────── APP SHELLS ─────────────
  // These are navigated using MaterialPageRoute
  // DriverRootShell(profile)
  // RiderRootShell()
  static const driverShell = '/driver-shell';
  static const String shell = '/shell'; // rider IndexedStack shell

  // ───────────── DRIVER FULLSCREEN SCREENS ─────────────
  static const activeRide = '/active-ride';
  static const activeDelivery = '/active-delivery';
  static const activeTrip = '/active-trip'; // ← active trip tracker screen

  // ───────────── PROFILE SCREENS ─────────────
  static const editProfile = '/edit-profile';
  static const driverProfile = '/driver-profile'; // ← driver's own profile page
  static const savedPlaces = '/saved-places';
  static const paymentMethods = '/payment-methods';
  static const promotions = '/promotions';
  static const privacySecurity = '/privacy-security';
  static const helpSupport = '/help-support';
  static const support = '/support'; // ← in-app support / chat
  static const about = '/about';
  static const settings = '/settings'; // ← driver settings screen

  // ───────────── NOTIFICATIONS ─────────────
  static const notifications = '/notifications'; // ← notifications centre

  // ───────────── WALLET / EARNINGS ─────────────
  static const transactionDetail = '/transaction-detail';
  static const tripHistory = '/trip-history';
  static const withdrawal = '/withdrawal';

  static const earnings = '/earnings';
  static const driverWallet = '/driver-wallet';
}
