import 'package:flutter/material.dart';

class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  ModalRoute<void>? _currentRoute;

  String? get currentRouteName => _currentRoute?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is ModalRoute<void>) {
      _currentRoute = route;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is ModalRoute<void>) {
      _currentRoute = previousRoute;
      return;
    }
    _currentRoute = null;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is ModalRoute<void>) {
      _currentRoute = newRoute;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_currentRoute == route) {
      if (previousRoute is ModalRoute<void>) {
        _currentRoute = previousRoute;
      } else {
        _currentRoute = null;
      }
    }
  }
}

final AppRouteObserver appRouteObserver = AppRouteObserver();
