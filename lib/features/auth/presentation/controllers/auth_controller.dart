import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository {
    _active = this;
  }

  static AuthController? _active;
  static AuthController? get instance => _active;

  final AuthRepository _authRepository;

  AuthRepository get authRepository => _authRepository;

  bool _isLoading = false;
  bool _isBootstrapping = true;
  bool _isAuthenticated = false;
  bool _isImpersonating = false;
  String? _errorMessage;
  User? _currentUser;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticated => _isAuthenticated;
  bool get isImpersonating => _isImpersonating;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  Future<void> restoreSession() async {
    _isBootstrapping = true;
    _setLoading(true);
    _errorMessage = null;

    try {
      final hasToken = await _authRepository.hasToken();
      if (!hasToken) {
        _currentUser = null;
        _isAuthenticated = false;
        _isImpersonating = false;
        return;
      }

      final cachedUser = await _authRepository.readCachedUser();
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _isAuthenticated = true;
        _isImpersonating = await _authRepository.hasImpersonationBackup();
        _isBootstrapping = false;
        _setLoading(false);
        unawaited(_refreshSessionInBackground());
        return;
      }

      _currentUser = await _authRepository.currentUser();
      _isAuthenticated = true;
      _isImpersonating = await _authRepository.hasImpersonationBackup();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      final cachedUser = await _authRepository.readCachedUser();
      final isUnauthorized = error.statusCode == 401 || error.statusCode == 403;

      if (cachedUser != null && !isUnauthorized) {
        _currentUser = cachedUser;
        _isAuthenticated = true;
        _isImpersonating = await _authRepository.hasImpersonationBackup();
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _isImpersonating = false;
        await _authRepository.clearLocalSession();
      }
    } finally {
      _isBootstrapping = false;
      _setLoading(false);
    }
  }

  Future<void> _refreshSessionInBackground() async {
    try {
      _currentUser = await _authRepository.currentUser();
      _isAuthenticated = true;
      _isImpersonating = await _authRepository.hasImpersonationBackup();
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      final isUnauthorized = error.statusCode == 401 || error.statusCode == 403;
      if (isUnauthorized) {
        _currentUser = null;
        _isAuthenticated = false;
        _isImpersonating = false;
        await _authRepository.clearLocalSession();
      }
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login({required String login, required String password}) async {
    debugPrint('Attempting login for: $login');
    return _runAuthAction(() async {
      try {
        _currentUser = await _authRepository.login(
          login: login,
          password: password,
        );
        _isAuthenticated = true;
        _isImpersonating = false;
        debugPrint('Login successful for: $login');
      } catch (e, stackTrace) {
        debugPrint('Login error: $e\n$stackTrace');
        rethrow;
      }
    });
  }

  Future<bool> register({
    required String fullname,
    required String username,
    required String email,
    required String role1,
    required String gender,
    required String password,
    String? referrer,
  }) async {
    return _runAuthAction(() async {
      _currentUser = await _authRepository.register(
        fullname: fullname,
        username: username,
        email: email,
        role1: role1,
        gender: gender,
        password: password,
        referrer: referrer,
      );
      _isAuthenticated = true;
      _isImpersonating = false;
    });
  }

  Future<void> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authRepository.logout();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      // The repository clears the local token in a `finally`, so the app
      // should always leave the signed-in state immediately.
      _currentUser = null;
      _isAuthenticated = false;
      _isImpersonating = false;
      _setLoading(false);
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      final user = await _authRepository.currentUser();
      _currentUser = user;
      _isAuthenticated = true;
      _isImpersonating = await _authRepository.hasImpersonationBackup();
      _errorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> forceLocalLogout() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authRepository.clearLocalSession();
    } finally {
      _currentUser = null;
      _isAuthenticated = false;
      _isImpersonating = false;
      _setLoading(false);
    }
  }

  Future<bool> impersonateAsUser(String username) async {
    final normalized = username.trim().replaceFirst('@', '');
    if (normalized.isEmpty) {
      _errorMessage = 'User is invalid.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      _currentUser = await _authRepository.loginAsUser(username: normalized);
      _isAuthenticated = true;
      _isImpersonating = true;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> switchBackToAdmin() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _currentUser = await _authRepository.switchBackFromImpersonation();
      _isAuthenticated = true;
      _isImpersonating = false;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await action();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _isAuthenticated = false;
      _isImpersonating = false;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (identical(_active, this)) {
      _active = null;
    }
    super.dispose();
  }
}
