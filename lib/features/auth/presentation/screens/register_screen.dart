import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/widgets/auth_page_footer.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.authController,
    required this.profileRepository,
    super.key,
  });

  static const routeName = '/register';

  final AuthController authController;
  final ProfileRepository profileRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _UsernameAvailability { idle, checking, available, taken, invalid }

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Timer? _usernameDebounce;

  String _gender = 'male';
  String _selectedRole = '';
  bool _showPassword = false;
  bool _loadingRoles = true;
  _UsernameAvailability _usernameState = _UsernameAvailability.idle;
  List<String> _roleOptions = const <String>[];

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    unawaited(_loadRoleOptions());
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _normalizedUsername =>
      _usernameController.text.trim().replaceFirst('@', '');

  bool get _usernameBlocksSubmit =>
      _usernameState == _UsernameAvailability.checking ||
      _usernameState == _UsernameAvailability.taken ||
      _usernameState == _UsernameAvailability.invalid;

  Color? _usernameAccentColor(AppThemeColors colors) {
    switch (_usernameState) {
      case _UsernameAvailability.available:
        return Colors.green.shade600;
      case _UsernameAvailability.taken:
      case _UsernameAvailability.invalid:
        return Colors.red.shade500;
      case _UsernameAvailability.checking:
        return colors.brand;
      case _UsernameAvailability.idle:
        return null;
    }
  }

  void _onUsernameChanged() {
    final normalized = _normalizedUsername;
    final currentText = _usernameController.text;
    if (currentText.startsWith('@')) {
      _usernameController.value = _usernameController.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    _usernameDebounce?.cancel();

    if (normalized.isEmpty || normalized.length < 3) {
      if (mounted) {
        setState(() {
          _usernameState = _UsernameAvailability.idle;
        });
      }
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(normalized)) {
      if (mounted) {
        setState(() {
          _usernameState = _UsernameAvailability.invalid;
        });
      }
      return;
    }

    setState(() {
      _usernameState = _UsernameAvailability.checking;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final snapshot = _normalizedUsername;
      try {
        final available = await widget.authController.authRepository
            .checkUsernameAvailability(snapshot);
        if (!mounted || snapshot != _normalizedUsername) {
          return;
        }
        setState(() {
          _usernameState = available
              ? _UsernameAvailability.available
              : _UsernameAvailability.taken;
        });
      } catch (_) {
        if (!mounted || snapshot != _normalizedUsername) {
          return;
        }
        setState(() {
          _usernameState = _UsernameAvailability.idle;
        });
      }
    });
  }

  Future<void> _loadRoleOptions() async {
    try {
      final roles = await widget.authController.authRepository
          .fetchRegistrationRoles();
      if (!mounted) {
        return;
      }
      setState(() {
        _roleOptions = roles;
        if (_selectedRole.isEmpty && _roleOptions.isNotEmpty) {
          _selectedRole = _roleOptions.first;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_selectedRole.isEmpty) {
          _selectedRole = 'Hopeful Member';
        }
        _roleOptions = const <String>['Hopeful Member'];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoles = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _usernameBlocksSubmit) {
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await widget.authController.register(
      fullname: _fullnameController.text.trim(),
      username: _normalizedUsername,
      email: _emailController.text.trim(),
      role1: _selectedRole.trim(),
      gender: _gender,
      password: _passwordController.text,
    );

    if (!mounted || !success) {
      return;
    }

    final username = widget.authController.currentUser?.username ?? _normalizedUsername;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => EditProfileScreen(
          username: username,
          repository: widget.profileRepository,
          showOnboardingIntro: true,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sign up'),
      ),
      body: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) {
          final errorText = widget.authController.errorMessage;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 60,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'STEP 1 OF 3',
                                style: TextStyle(
                                  color: colors.accentSoftText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            Text(
                              'Create your account',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A quick start, then we will finish your profile in simple steps.',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.dangerSoft,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colors.dangerText.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  errorText,
                                  style: TextStyle(
                                    color: colors.dangerText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'Username',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required.';
                                }
                                final cleaned = value.trim().replaceFirst('@', '');
                                if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cleaned)) {
                                  return 'Letters, numbers, _ and - only.';
                                }
                                if (_usernameState == _UsernameAvailability.taken) {
                                  return 'Already taken.';
                                }
                                if (_usernameState == _UsernameAvailability.invalid) {
                                  return 'Letters, numbers, _ and - only.';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hintText: 'username',
                                prefixText: '@',
                                suffixIcon: _usernameSuffixIcon(colors),
                                accentColor: _usernameAccentColor(colors),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _UsernameStatusText(state: _usernameState),
                            const SizedBox(height: 18),
                            Text(
                              'Full Name',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _fullnameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Full name is required.';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hintText: 'Your full name',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required.';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email.';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hintText: 'Your email',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value:
                                  _selectedRole.isNotEmpty &&
                                      _roleOptions.contains(_selectedRole)
                                  ? _selectedRole
                                  : null,
                              items: _roleOptions
                                  .map(
                                    (role) => DropdownMenuItem<String>(
                                      value: role,
                                      child: Text(
                                        role,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _loadingRoles
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedRole = value ?? '';
                                      });
                                    },
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Role is required.';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hintText: _loadingRoles
                                    ? 'Loading roles...'
                                    : 'Select any role...',
                              ),
                              isExpanded: true,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _GenderChip(
                                    label: 'Male',
                                    value: 'male',
                                    selectedValue: _gender,
                                    onSelected: _selectGender,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _GenderChip(
                                    label: 'Female',
                                    value: 'female',
                                    selectedValue: _gender,
                                    onSelected: _selectGender,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required.';
                                }
                                if (value.length < 8) {
                                  return 'Minimum 8 characters.';
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hintText: 'Min. 8 characters',
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'By creating an account you agree to the Terms of Service and Privacy Policy.',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: colors.brandGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.brand.withValues(alpha: 0.28),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: widget.authController.isSubmitting ||
                                          _usernameBlocksSubmit
                                      ? null
                                      : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: widget.authController.isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign up',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: Wrap(
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.authController.isSubmitting
                                        ? null
                                        : () {
                                            widget.authController.clearError();
                                            Navigator.of(context)
                                                .pushReplacementNamed(
                                                  LoginScreen.routeName,
                                                );
                                          },
                                    child: Text(
                                      'Sign in',
                                      style: TextStyle(
                                        color: colors.brand,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const AuthPageFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _usernameSuffixIcon(AppThemeColors colors) {
    switch (_usernameState) {
      case _UsernameAvailability.checking:
        return Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.textMuted,
            ),
          ),
        );
      case _UsernameAvailability.available:
        return Icon(Icons.check_circle_rounded, color: Colors.green.shade600);
      case _UsernameAvailability.taken:
      case _UsernameAvailability.invalid:
        return Icon(Icons.cancel_rounded, color: Colors.red.shade500);
      case _UsernameAvailability.idle:
        return const SizedBox.shrink();
    }
  }

  void _selectGender(String value) {
    setState(() {
      _gender = value;
    });
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? prefixText,
    Widget? suffixIcon,
    Color? accentColor,
  }) {
    final colors = context.appColors;
    final borderColor = accentColor ?? colors.border;
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surfaceMuted.withValues(alpha: 0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: accentColor ?? colors.brand, width: 1.4),
      ),
    );
  }
}

class _UsernameStatusText extends StatelessWidget {
  const _UsernameStatusText({required this.state});

  final _UsernameAvailability state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String text = 'Your public community handle';
    Color color = colors.textMuted;
    IconData? icon;

    switch (state) {
      case _UsernameAvailability.available:
        text = 'Username available';
        color = Colors.green.shade600;
        icon = Icons.check_circle_rounded;
        break;
      case _UsernameAvailability.taken:
        text = 'Already taken';
        color = Colors.red.shade500;
        icon = Icons.cancel_rounded;
        break;
      case _UsernameAvailability.invalid:
        text = 'Letters, numbers, _ and - only';
        color = Colors.red.shade500;
        icon = Icons.error_rounded;
        break;
      case _UsernameAvailability.checking:
        text = 'Checking availability...';
        color = colors.brand;
        icon = Icons.hourglass_top_rounded;
        break;
      case _UsernameAvailability.idle:
        break;
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: state == _UsernameAvailability.idle
                ? FontWeight.w500
                : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSelected = selectedValue == value;

    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? colors.accentSoft : colors.surface,
          border: Border.all(
            color: isSelected ? colors.brand : colors.border,
            width: 1.6,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? colors.brand : colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
