import 'package:flutter/foundation.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthRepository get authRepository => _authRepository;

  bool _isLoading = false;
  bool _isBootstrapping = true;
  bool _isAuthenticated = false;
  String? _errorMessage;
  User? _currentUser;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  Future<void> restoreSession() async {
    _isBootstrapping = true;
    _setLoading(true);
    _errorMessage = null;

    try {
      final hasToken = await _authRepository.hasToken();
      if (!hasToken) {
        _isAuthenticated = false;
        return;
      }

      _currentUser = await _authRepository.currentUser();
      _isAuthenticated = true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _isAuthenticated = false;
      await _authRepository.logout();
    } finally {
      _isBootstrapping = false;
      _setLoading(false);
    }
  }

  Future<bool> login({required String login, required String password}) async {
    return _runAuthAction(() async {
      try {
        _currentUser = await _authRepository.login(
          login: login,
          password: password,
        );
        _isAuthenticated = true;
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
    required String gender,
    required String password,
  }) async {
    return _runAuthAction(() async {
      _currentUser = await _authRepository.register(
        fullname: fullname,
        username: username,
        email: email,
        gender: gender,
        password: password,
      );
      _isAuthenticated = true;
    });
  }

  Future<void> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authRepository.logout();
      _currentUser = null;
      _isAuthenticated = false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
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
}
