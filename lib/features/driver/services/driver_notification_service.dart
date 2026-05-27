// lib/features/driver/services/driver_notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> driverBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Driver background: ${message.notification?.title}');
}

class DriverNotificationService {
  DriverNotificationService._();
  static final DriverNotificationService instance =
      DriverNotificationService._();

  final _fcm       = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _local     = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  StreamSubscription<String>?        _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<User?>?         _authSub;

  static const _tripChannel = AndroidNotificationChannel(
    'driver_trips', 'Trip Requests',
    description: 'New trip and delivery requests',
    importance:  Importance.max,
    playSound:   true,
  );
  static const _alertChannel = AndroidNotificationChannel(
    'driver_alerts', 'Driver Alerts',
    description: 'Important driver notifications',
    importance:  Importance.high,
    playSound:   true,
  );
  static const _generalChannel = AndroidNotificationChannel(
    'ctsride_general', 'General Notifications',
    description: 'General notifications',
    importance:  Importance.high,
    playSound:   true,
  );

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(driverBackgroundMessageHandler);

      await _fcm.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      await _initLocalNotifications(navigatorKey);
      _listenForeground();
      _listenTaps(navigatorKey);
      await _handleInitialMessage(navigatorKey);

      // Save token whenever driver logs in
      _authSub = _auth.authStateChanges().listen((user) async {
        if (user != null) await _saveToken();
      });

      // Save on token refresh
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((token) async {
        if (_auth.currentUser != null) await _persistToken(token);
      });

      debugPrint('DriverNotificationService ready');
    } catch (e) {
      _initialized = false;
      debugPrint('DriverNotificationService failed: $e');
    }
  }

  // v17 API — positional arguments
  Future<void> _initLocalNotifications(
      GlobalKey<NavigatorState> navigatorKey) async {

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(route);
        }
      },
    );

    final android = _local
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

if (android != null) {
  await android.createNotificationChannel(_tripChannel);
  await android.createNotificationChannel(_alertChannel);
  await android.createNotificationChannel(_generalChannel);
}
  }

  void _listenForeground() {
    _foregroundSub = FirebaseMessaging.onMessage.listen((msg) async {
      final notif = msg.notification;
      if (notif == null) return;

      final channel = _channelForType(msg.data['type'] as String? ?? '');

      await _local.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority:   Priority.high,
            playSound:  true,
            icon:       '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: msg.data['route'] as String?,
      );
    });
  }

  void _listenTaps(GlobalKey<NavigatorState> navigatorKey) {
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _navigate(navigatorKey, msg.data['route'] as String?);
    });
  }

  Future<void> _handleInitialMessage(
      GlobalKey<NavigatorState> navigatorKey) async {
    final msg = await _fcm.getInitialMessage();
    if (msg == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate(navigatorKey, msg.data['route'] as String?);
    });
  }

  void _navigate(GlobalKey<NavigatorState> nav, String? route) {
    if (route == null || route.isEmpty) return;
    nav.currentState?.pushNamed(route);
  }

  Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _persistToken(token);
    } catch (e) {
      debugPrint('Driver FCM token fetch failed: $e');
    }
  }

  // Saves to drivers/{uid} — not users/{uid}
  Future<void> _persistToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('drivers').doc(uid).set({
      'fcmToken':          token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'platform':          defaultTargetPlatform.name,
    }, SetOptions(merge: true));
    debugPrint('Driver FCM token saved for uid: $uid');
  }

  Future<void> clearToken() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('drivers').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('Driver token clear failed: $e');
    }
  }

  AndroidNotificationChannel _channelForType(String type) {
    switch (type) {
      case 'ride':
      case 'delivery':
      case 'gas':
        return _tripChannel;
      case 'documentExpiry':
      case 'account_approved':
      case 'documents_rejected':
        return _alertChannel;
      default:
        return _generalChannel;
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _authSub?.cancel();
    _initialized = false;
  }
}
