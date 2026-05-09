// services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_service.g.dart';

@Riverpod(keepAlive: true)
class NavigationService extends _$NavigationService {
  late final GlobalKey<NavigatorState> _navigatorKey;
  
  @override
  GlobalKey<NavigatorState> build() {
    _navigatorKey = GlobalKey<NavigatorState>();
    return _navigatorKey;
  }
  
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  
  BuildContext get context => _navigatorKey.currentContext!;
  
  void push(String routeName, {Object? extra}) {
    context.push(routeName, extra: extra);
  }
  
  void pushReplacement(String routeName, {Object? extra}) {
    context.pushReplacement(routeName, extra: extra);
  }
  
  void pop<T extends Object?>([T? result]) {
    context.pop(result);
  }
  
  void go(String routeName, {Object? extra}) {
    context.go(routeName, extra: extra);
  }
  
  bool canPop() => context.canPop();
}