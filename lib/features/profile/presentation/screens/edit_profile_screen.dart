import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/home_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';

const List<String> _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.username,
    required this.repository,
    this.showOnboardingIntro = false,
    super.key,
  });

  final String username;
  final ProfileRepository repository;
  final bool showOnboardingIntro;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _quoteController = TextEditingController();
  final _secondaryRoleController = TextEditingController();
  final _hobbyController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedBirthDay = '';
  String _selectedBirthMonth = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _emailNotifications = true;
  Object? _error;
  String _gender = 'male';
  String _theme = 'light';
  String _selectedRole = '';
  String _selectedCountry = '';
  String _selectedState = '';
  List<String> _roleOptions = const <String>[];
  List<String> _countryOptions = const <String>[];
  List<String> _stateOptions = const <String>[];
  bool _loadingStates = false;
  bool _hasLoadedStatesForSelectedCountry = false;

  bool get _showLegacyOnboardingNote => false;

  static List<String> _uniqueOptions(List<String> values) {
    final seen = <String>{};
    final items = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      items.add(trimmed);
    }
    return items;
  }

  static String _normalizeNumericDropdownValue(
    String rawValue,
    int min,
    int max,
  ) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < min || parsed > max) {
      return '';
    }
    return parsed.toString();
  }

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
    _secondaryRoleController.dispose();
    _hobbyController.dispose();
    _cityController.dispose();
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
      final results = await Future.wait<Object>([
        widget.repository.fetchProfile(widget.username),
        widget.repository.fetchEditOptions(),
      ]);
      final dashboard = results[0] as ProfileDashboard;
      final options = results[1] as ProfileEditOptions;
      final profile = dashboard.profile;

      _fullnameController.text = profile.fullname;
      _usernameController.text = profile.username;
      _emailController.text = profile.email;
      _quoteController.text = profile.quote;
      _secondaryRoleController.text = profile.role2;
      _hobbyController.text = profile.hobby;
      _cityController.text = profile.city;
      _phoneController.text = profile.phoneNumber;
      _gender = profile.gender.isNotEmpty ? profile.gender : 'male';
      _theme = profile.theme.isNotEmpty ? profile.theme : 'light';
      _emailNotifications = profile.emailNotifications;
      _selectedRole = profile.role1;
      _selectedCountry = profile.location;
      _selectedState = profile.state;
      final birthdayParts = profile.birthday.split('-');
      _selectedBirthDay = birthdayParts.isNotEmpty
          ? _normalizeNumericDropdownValue(birthdayParts.first, 1, 31)
          : '';
      _selectedBirthMonth = birthdayParts.length > 1
          ? _normalizeNumericDropdownValue(birthdayParts[1], 1, 12)
          : '';
      _roleOptions = _uniqueOptions(options.roles);
      _countryOptions = _uniqueOptions(options.countries);

      if (_selectedRole.isNotEmpty && !_roleOptions.contains(_selectedRole)) {
        _selectedRole = '';
      }
      if (_selectedCountry.isNotEmpty &&
          !_countryOptions.contains(_selectedCountry)) {
        _selectedCountry = '';
      }

      if (_selectedState.isNotEmpty) {
        _stateOptions = <String>[_selectedState];
      }
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

  Future<void> _loadStates(
    String country, {
    bool preserveSelection = false,
  }) async {
    setState(() {
      _loadingStates = true;
      if (!preserveSelection) {
        _selectedState = '';
      }
      _stateOptions = const <String>[];
      _hasLoadedStatesForSelectedCountry = false;
    });

    try {
      final states = await widget.repository.fetchStatesForCountry(country);
      if (!mounted) {
        return;
      }
      setState(() {
        _stateOptions = _uniqueOptions(states);
        _hasLoadedStatesForSelectedCountry = true;
        if (_selectedState.isNotEmpty &&
            !_stateOptions.contains(_selectedState)) {
          _selectedState = '';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates = false;
        });
      }
    }
  }

  Future<void> _loadStatesOnDemand() async {
    if (_selectedCountry.isEmpty ||
        _loadingStates ||
        _hasLoadedStatesForSelectedCountry) {
      return;
    }

    await _loadStates(_selectedCountry, preserveSelection: true);
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
        role1: _selectedRole.trim(),
        role2: _secondaryRoleController.text.trim(),
        location: _selectedCountry.trim(),
        city: _cityController.text.trim(),
        state: _selectedState.trim(),
        birthDay: _selectedBirthDay.trim(),
        birthMonth: _selectedBirthMonth.trim(),
        phoneNumber: _phoneController.text.trim(),
        emailNotifications: _emailNotifications,
        theme: _theme,
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (widget.showOnboardingIntro) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => EditProfileMediaScreen(
              username: widget.username,
              repository: widget.repository,
            ),
          ),
        );
        if (!mounted) {
          return;
        }
        await Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(HomeScreen.routeName, (route) => false);
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
        title: Text(
          widget.showOnboardingIntro ? 'Complete Profile' : 'Edit Profile',
        ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showOnboardingIntro) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.brand.withValues(alpha: 0.16),
                                colors.accentSoft,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Step 2 of 3',
                                  style: TextStyle(
                                    color: colors.brand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Let\'s finish setting up your profile',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 24,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A few personal details help us personalize your experience and make HopefulMe feel more like home.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.5,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.showOnboardingIntro &&
                          _showLegacyOnboardingNote) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to HopefulMe! 🎉',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Divider(color: colors.borderStrong, height: 1),
                              const SizedBox(height: 10),
                              Text(
                                'You are special to us every day 💙. Please update your profile info and photo next, to personalize your experience on our app.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!widget.showOnboardingIntro) ...[
                        const _CardTitle(
                          title: 'Basic Info',
                          subtitle:
                              'This is how others will recognize you on HopefulMe',
                        ),
                        const SizedBox(height: 10),
                        _EditCard(
                          child: Column(
                            children: [
                              _LabeledField(
                                label: 'Full Name',
                                child: TextFormField(
                                  controller: _fullnameController,
                                  validator: _required(
                                    'Full name is required.',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              _LabeledField(
                                label: 'Username',
                                child: TextFormField(
                                  controller: _usernameController,
                                  validator: _required('Username is required.'),
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    prefixText: '@',
                                  ),
                                ),
                              ),
                              _LabeledField(
                                label: 'Gender',
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ChoiceChip(
                                        label: 'Male',
                                        selected: _gender == 'male',
                                        onTap: () =>
                                            setState(() => _gender = 'male'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ChoiceChip(
                                        label: 'Female',
                                        selected: _gender == 'female',
                                        onTap: () =>
                                            setState(() => _gender = 'female'),
                                      ),
                                    ),
                                   
                                  ],
                                ),
                              ),
                              _LabeledField(
                                label: 'Email',
                                hint: 'Visible only to you.',
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
                                child: DropdownButtonFormField<String>(
                                  initialValue:
                                      _selectedRole.isNotEmpty &&
                                          _roleOptions.contains(_selectedRole)
                                      ? _selectedRole
                                      : null,
                                  decoration: const InputDecoration(
                                    hintText: 'Select your role...',
                                  ),
                                  items: _roleOptions
                                      .map(
                                        (role) => DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(role),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value ?? '';
                                    });
                                  },
                                ),
                              ),
                              _LabeledField(
                                label:
                                    'Secondary Role (Your work, career, dream, or aspiration)',
                                child: TextFormField(
                                  controller: _secondaryRoleController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Enter role that reflects your career',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const _CardTitle(
                        title: 'Personal Details',
                        subtitle: 'Tell us a bit more about yourself.',
                      ),
                      const SizedBox(height: 10),
                      _EditCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            _LabeledField(
                              label: 'Hobbies & Interests',
                              child: TextFormField(
                                controller: _hobbyController,
                              ),
                            ),
                            if (widget.showOnboardingIntro)
                              _LabeledField(
                                label:
                                    'Secondary Role (Your work, career, dream, or aspiration)',
                                child: TextFormField(
                                  controller: _secondaryRoleController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    hintText: '',
                                  ),
                                ),
                              ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 620;
                                final countryField = _LabeledField(
                                  label: 'Country',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue:
                                        _selectedCountry.isNotEmpty &&
                                            _countryOptions.contains(
                                              _selectedCountry,
                                            )
                                        ? _selectedCountry
                                        : null,
                                    decoration: const InputDecoration(
                                      hintText: 'Select country...',
                                    ),
                                    items: _countryOptions
                                        .map(
                                          (country) => DropdownMenuItem<String>(
                                            value: country,
                                            child: Text(
                                              country,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) async {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedCountry = value;
                                        _selectedState = '';
                                        _stateOptions = const <String>[];
                                        _hasLoadedStatesForSelectedCountry =
                                            false;
                                      });
                                    },
                                  ),
                                );
                                final stateField = _LabeledField(
                                  label: 'State / Region',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue:
                                        _selectedState.isNotEmpty &&
                                            _stateOptions.contains(
                                              _selectedState,
                                            )
                                        ? _selectedState
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: _loadingStates
                                          ? 'Loading...'
                                          : _selectedCountry.isEmpty
                                          ? 'Select country first'
                                          : 'Select state...',
                                    ),
                                    onTap: _loadStatesOnDemand,
                                    items: _stateOptions
                                        .map(
                                          (state) => DropdownMenuItem<String>(
                                            value: state,
                                            child: Text(
                                              state,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged:
                                        _selectedCountry.isEmpty ||
                                            _loadingStates
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedState = value ?? '';
                                            });
                                          },
                                  ),
                                );

                                return isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: countryField),
                                          const SizedBox(width: 12),
                                          Expanded(child: stateField),
                                        ],
                                      )
                                    : Column(
                                        children: [countryField, stateField],
                                      );
                              },
                            ),
                            _LabeledField(
                              label: 'City',
                              child: TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  hintText: 'Your city',
                                ),
                              ),
                            ),
                            _LabeledField(
                              label: 'Phone Number',
                              hint: 'Visible only to you..',
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 620;
                                final dayField = _LabeledField(
                                  label: 'Birth Day',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedBirthDay.isNotEmpty
                                        ? _selectedBirthDay
                                        : null,
                                    decoration: const InputDecoration(
                                      hintText: 'Day',
                                    ),
                                    items:
                                        List<DropdownMenuItem<String>>.generate(
                                          31,
                                          (index) {
                                            final day = '${index + 1}';
                                            return DropdownMenuItem<String>(
                                              value: day,
                                              child: Text(day),
                                            );
                                          },
                                        ),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedBirthDay = value ?? '';
                                      });
                                    },
                                  ),
                                );
                                final monthField = _LabeledField(
                                  label: 'Birth Month',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedBirthMonth.isNotEmpty
                                        ? _selectedBirthMonth
                                        : null,
                                    decoration: const InputDecoration(
                                      hintText: 'Month',
                                    ),
                                    items:
                                        List<DropdownMenuItem<String>>.generate(
                                          _monthLabels.length,
                                          (index) {
                                            final month = '${index + 1}';
                                            return DropdownMenuItem<String>(
                                              value: month,
                                              child: Text(_monthLabels[index]),
                                            );
                                          },
                                        ),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedBirthMonth = value ?? '';
                                      });
                                    },
                                  ),
                                );

                                return isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: dayField),
                                          const SizedBox(width: 12),
                                          Expanded(child: monthField),
                                        ],
                                      )
                                    : Column(children: [dayField, monthField]);
                              },
                            ),
                            _LabeledField(
                              label: 'Favourite Quote',
                              child: TextFormField(
                                controller: _quoteController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText:
                                      'A short line that reflects your mindset or story',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.showOnboardingIntro) ...[
                        const SizedBox(height: 16),
                        const _CardTitle(
                          title: 'Security',
                          subtitle:
                              'Leave password blank if you are not changing it.',
                        ),
                        const SizedBox(height: 10),
                        _EditCard(
                          child: Column(
                            children: [
                              _LabeledField(
                                label: 'New Password',
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _error!.toString(),
                                      style: TextStyle(
                                        color: colors.dangerText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (!widget.showOnboardingIntro) ...[
                        const SizedBox(height: 16),
                        const _CardTitle(
                          title: 'Preferences',
                          subtitle:
                              'Manage how you receive updates and notifications',
                        ),
                        const SizedBox(height: 10),
                        _EditCard(
                          child: SwitchListTile.adaptive(
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
                        ),
                        const SizedBox(height: 18),
                      ],
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
                              : Text(
                                  widget.showOnboardingIntro
                                      ? 'Save & Continue to Photo'
                                      : 'Save Changes',
                                ),
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
  const _LabeledField({required this.label, required this.child, this.hint});

  final String label;
  final Widget child;
  final String? hint;

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
          if (hint != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint!,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          border: Border.all(color: selected ? colors.brand : colors.border),
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
