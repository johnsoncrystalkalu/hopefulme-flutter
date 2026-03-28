import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.username,
    required this.repository,
    super.key,
  });

  final String username;
  final ProfileRepository repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _quoteController = TextEditingController();
  final _hobbyController = TextEditingController();
  final _roleController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;
  String _gender = 'male';
  String _theme = 'light';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _quoteController.dispose();
    _hobbyController.dispose();
    _roleController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dashboard = await widget.repository.fetchProfile(widget.username);
      final profile = dashboard.profile;
      _fullnameController.text = profile.fullname;
      _usernameController.text = profile.username;
      _emailController.text = profile.email;
      _quoteController.text = profile.quote;
      _hobbyController.text = profile.hobby;
      _roleController.text = profile.role1;
      _cityController.text = profile.city;
      _stateController.text = profile.state;
      _phoneController.text = profile.phoneNumber;
      _gender = profile.gender.isNotEmpty ? profile.gender : 'male';
      _theme = profile.theme.isNotEmpty ? profile.theme : 'light';
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final profile = await widget.repository.updateProfile(
        fullname: _fullnameController.text.trim(),
        username: _usernameController.text.trim().replaceFirst('@', ''),
        email: _emailController.text.trim(),
        gender: _gender,
        quote: _quoteController.text.trim(),
        hobby: _hobbyController.text.trim(),
        role1: _roleController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        theme: _theme,
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _EditCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LabeledField(
                              label: 'Full Name',
                              child: TextFormField(
                                controller: _fullnameController,
                                validator: _required('Full name is required.'),
                              ),
                            ),
                            _LabeledField(
                              label: 'Username',
                              child: TextFormField(
                                controller: _usernameController,
                                validator: _required('Username is required.'),
                              ),
                            ),
                            _LabeledField(
                              label: 'Email',
                              child: TextFormField(
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
                              ),
                            ),
                            _LabeledField(
                              label: 'Role / Title',
                              child: TextFormField(controller: _roleController),
                            ),
                            _LabeledField(
                              label: 'Personal Quote',
                              child: TextFormField(
                                controller: _quoteController,
                                minLines: 2,
                                maxLines: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Gender'),
                            Wrap(
                              spacing: 10,
                              children: [
                                _ChoiceChip(
                                  label: 'Male',
                                  selected: _gender == 'male',
                                  onTap: () => setState(() => _gender = 'male'),
                                ),
                                _ChoiceChip(
                                  label: 'Female',
                                  selected: _gender == 'female',
                                  onTap: () => setState(() => _gender = 'female'),
                                ),
                                _ChoiceChip(
                                  label: 'Other',
                                  selected: _gender == 'other',
                                  onTap: () => setState(() => _gender = 'other'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _LabeledField(
                              label: 'Hobbies',
                              child: TextFormField(controller: _hobbyController),
                            ),
                            _LabeledField(
                              label: 'City',
                              child: TextFormField(controller: _cityController),
                            ),
                            _LabeledField(
                              label: 'State / Region',
                              child: TextFormField(controller: _stateController),
                            ),
                            _LabeledField(
                              label: 'Phone Number',
                              child: TextFormField(controller: _phoneController),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Theme'),
                            Wrap(
                              spacing: 10,
                              children: [
                                _ChoiceChip(
                                  label: 'Light',
                                  selected: _theme == 'light',
                                  onTap: () => setState(() => _theme = 'light'),
                                ),
                                _ChoiceChip(
                                  label: 'Dark',
                                  selected: _theme == 'dark',
                                  onTap: () => setState(() => _theme = 'dark'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _LabeledField(
                              label: 'New Password',
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!.toString(),
                                style: TextStyle(
                                  color: colors.dangerText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
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
            ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.brand : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.brand : colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
