import 'dart:async';

import 'package:hopefulme_flutter/core/network/api_exception.dart';

class AppErrorText {
  const AppErrorText._();

  static bool isTimeout(Object? error) => error is TimeoutException;

  static bool isOffline(Object? error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('connection refused') ||
        text.contains('network') ||
        text.contains('internet') ||
        text.contains('xmlhttprequest error');
  }

  static String title(Object? error) {
    if (isTimeout(error)) {
      return 'This page is taking too long';
    }
    if (isOffline(error)) {
      return 'You are offline';
    }
    if (error is ApiException && error.statusCode == 401) {
      return 'Session expired';
    }
    return 'Something went wrong';
  }

  static String message(Object? error) {
    if (isTimeout(error)) {
      return 'The request did not finish in time. You can retry or come back in a moment.';
    }
    if (isOffline(error)) {
      return 'It looks like you\'ve lost your internet connection. We\'ll be here when you\'re back online';
    }
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is ApiException && error.statusCode == 401) {
      return 'Please sign in again to continue.';
    }
    return 'We could not load this page right now. Please try again.';
  }
}
