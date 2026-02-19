// riders_app/lib/core/routes/app_routes.dart

class AppRoutes {
  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otpVerification = '/otp';
  
  // Rider Routes ONLY
  static const String riderHome = '/rider-home';
  static const String bookRide = '/book-ride';
  static const String activeRide = '/active-ride';
  static const String rideHistory = '/ride-history';
  static const String riderWallet = '/rider-wallet';
  
  // Delivery Routes ONLY
  static const String bookDelivery = '/book-delivery';
  static const String activeDelivery = '/active-delivery';
  static const String deliveryHistory = '/delivery-history';
}