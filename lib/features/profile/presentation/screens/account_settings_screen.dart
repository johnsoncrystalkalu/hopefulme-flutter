import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    required this.username,
    required this.repository,
    super.key,
  });

  final String username;
  final ProfileRepository repository;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _accountFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _emailNotifications = true;
  bool _isLoading = true;
  bool _isSavingAccount = false;
  bool _isChangingPassword = false;
  Object? _loadError;
  Object? _accountError;
  Object? _passwordError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _accountError = null;
      _passwordError = null;
    });
    try {
      final dashboard = await widget.repository.fetchProfile(widget.username);
      final profile = dashboard.profile;
      _emailController.text = profile.email;
      _emailNotifications = profile.emailNotifications;
    } catch (error) {
      _loadError = error;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAccountChanges() async {
    if (!_accountFormKey.currentState!.validate() || _isSavingAccount) {
      return;
    }
    setState(() {
      _isSavingAccount = true;
      _accountError = null;
    });

    try {
      await widget.repository.updateAccountSettings(
        email: _emailController.text.trim(),
        emailNotifications: _emailNotifications,
      );
      if (!mounted) return;
      AppToast.success(context, 'Account settings updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _accountError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAccount = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate() || _isChangingPassword) {
      return;
    }
    setState(() {
      _isChangingPassword = true;
      _passwordError = null;
    });

    try {
      await widget.repository.updateAccountSettings(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        newPasswordConfirmation: _confirmPasswordController.text.trim(),
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      AppToast.success(context, 'Password changed successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Account Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? AppStatusState.fromError(
              error: _loadError!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsCard(
                      title: 'Email & Preferences',
                      subtitle: 'Update your email and notification preferences.',
                      child: Form(
                        key: _accountFormKey,
                        child: Column(
                          children: [
                            _FieldBlock(
                              label: 'Email',
                              hint: 'Used for login and account notifications.',
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'Email is required.';
                                  }
                                  if (!trimmed.contains('@')) {
                                    return 'Enter a valid email.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _emailNotifications,
                              activeThumbColor: colors.brand,
                              activeTrackColor: colors.brand.withValues(
                                alpha: 0.35,
                              ),
                              title: Text(
                                'Email Notifications',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'Receive important emails like account updates and reminders.',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _emailNotifications = value;
                                });
                              },
                            ),
                            if (_accountError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _accountError.toString(),
                                    style: TextStyle(
                                      color: colors.dangerText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSavingAccount
                                    ? null
                                    : _saveAccountChanges,
                                child: _isSavingAccount
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      title: 'Password',
                      subtitle: 'Change your password securely.',
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          children: [
                            _FieldBlock(
                              label: 'Current Password',
                              child: TextFormField(
                                controller: _currentPasswordController,
                                obscureText: true,
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'Enter your current password.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            _FieldBlock(
                              label: 'New Password',
                              hint: 'Must be at least 8 characters.',
                              child: TextFormField(
                                controller: _newPasswordController,
                                obscureText: true,
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'Enter a new password.';
                                  }
                                  if (trimmed.length < 8) {
                                    return 'Password must be at least 8 characters.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            _FieldBlock(
                              label: 'Confirm New Password',
                              child: TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                validator: (value) {
                                  final confirm = (value ?? '').trim();
                                  final next = _newPasswordController.text
                                      .trim();
                                  if (confirm.isEmpty) {
                                    return 'Confirm your new password.';
                                  }
                                  if (confirm != next) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (_passwordError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _passwordError.toString(),
                                    style: TextStyle(
                                      color: colors.dangerText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isChangingPassword
                                    ? null
                                    : _changePassword,
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Change Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
