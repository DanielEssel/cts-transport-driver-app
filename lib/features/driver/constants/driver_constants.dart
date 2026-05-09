// constants/driver_constants.dart
import 'package:flutter/material.dart';

class DriverConstants {
  // Profile defaults
  static const String defaultDriverPhotoUrl = '';
  static const double defaultDriverRating = 5.0;
  static const String defaultServiceType = 'ride';
  
  // Timeout values (in seconds)
  static const int locationTimeoutSeconds = 8;
  static const int requestTimeoutSeconds = 30;
  static const int networkTimeoutSeconds = 15;
  
  // Refresh intervals (in milliseconds)
  static const int locationUpdateIntervalMs = 5000;
  static const int statsRefreshIntervalMs = 30000;
  static const int earningsRefreshIntervalMs = 60000;
  
  // UI Constants
  static const double appBarHeightOffset = 100.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 10.0;
  static const double shimmerBorderRadius = 12.0;
  
  // Animation durations (in milliseconds)
  static const int switchAnimationDuration = 400;
  static const int cardAnimationDuration = 600;
  static const int pulseAnimationDuration = 1500;
  
  // Grid layouts
  static const int quickActionsCrossAxisCount = 3;
  static const double quickActionsAspectRatio = 1.05;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int requestsPageSize = 10;
  
  // Location settings
  static const double locationAccuracy = 100.0; // meters
  static const int locationDistanceFilter = 10; // meters
  
  // Cache durations
  static const Duration profileCacheDuration = Duration(minutes: 5);
  static const Duration statsCacheDuration = Duration(minutes: 2);
  static const Duration earningsCacheDuration = Duration(minutes: 1);
  
  // Retry settings
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2;
  
  // Distance thresholds
  static const double maxRequestDistanceKm = 10.0;
  static const double minDriverDistanceKm = 0.5;
  
  // Offline support
  static const int maxOfflineRequests = 50;
  static const Duration offlineSyncInterval = Duration(minutes: 15);
  
  // Analytics events
  static const String analyticsScreenName = 'driver_home';
  static const String analyticsOnlineToggle = 'driver_online_toggle';
  static const String analyticsAcceptRequest = 'driver_accept_request';
  static const String analyticsDeclineRequest = 'driver_decline_request';
  
  // Notifications
  static const int maxUnreadNotifications = 99;
  static const String notificationBadgeText = '9+';
  
  // Deep linking
  static const String deeplinkAcceptRequest = '/accept-request/';
  static const String deeplinkViewEarnings = '/earnings';
  static const String deeplinkViewTrip = '/trip/';
}

class AnimationConstants {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration long = Duration(milliseconds: 600);
  static const Duration extraLong = Duration(milliseconds: 1000);
  
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.easeOutBack;
  static const Curve elasticCurve = Curves.elasticOut;
}



class RadiusConstants {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(sm));
}