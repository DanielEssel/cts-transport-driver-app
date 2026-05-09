// utils/helpers.dart
import 'package:flutter/material.dart';
import 'dart:async'; 
import 'package:flutter/services.dart'; // Add this line

class Debouncer {
  final Duration delay;
  Timer? _timer;
  
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
  
  void dispose() {
    _timer?.cancel();
  }
}

class Throttler {
  final Duration delay;
  DateTime? _lastCall;
  
  Throttler({this.delay = const Duration(milliseconds: 300)});
  
  bool call(VoidCallback action) {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) >= delay) {
      _lastCall = now;
      action();
      return true;
    }
    return false;
  }
}

class DeviceUtils {
  static Future<void> vibrate({
    VibrateType type = VibrateType.medium,
  }) async {
    switch (type) {
      case VibrateType.light:
        await HapticFeedback.lightImpact();
        break;
      case VibrateType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case VibrateType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case VibrateType.selection:
        await HapticFeedback.selectionClick();
        break;
    }
  }
  
  static Future<bool> isKeyboardVisible(BuildContext context) async {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
  
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}

enum VibrateType {
  light,
  medium,
  heavy,
  selection,
}

class RequestDeduplicator {
  final Set<String> _processingIds = {};
  final Set<String> _processedIds = {};
  
  bool canProcess(String id) {
    if (_processingIds.contains(id) || _processedIds.contains(id)) {
      return false;
    }
    _processingIds.add(id);
    return true;
  }
  
  void markProcessed(String id) {
    _processingIds.remove(id);
    _processedIds.add(id);
    // Clean up old processed ids after delay
    Future.delayed(const Duration(seconds: 5), () {
      _processedIds.remove(id);
    });
  }
  
  void clear() {
    _processingIds.clear();
    _processedIds.clear();
  }
}