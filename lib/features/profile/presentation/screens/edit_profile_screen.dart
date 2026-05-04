import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/services/app_actions_registry.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/settings_screen.dart';
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
  final _referrerController = TextEditingController();
  final _quoteController = TextEditingController();
  final _secondaryRoleController = TextEditingController();
  final _hobbyController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedBirthDay = '';
  String _selectedBirthMonth = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _emailNotifications = true;
  Object? _error;
  String _gender = 'male';
  String _theme = 'light';
  String _accountEmail = '';
  String _selectedRole = '';
  String _selectedCountry = '';
  String _selectedState = '';
  List<String> _roleOptions = const <String>[];
  List<String> _countryOptions = const <String>[];
  List<String> _stateOptions = const <String>[];
  bool _loadingStates = false;
  bool _hasLoadedStatesForSelectedCountry = false;
  bool _canEditReferrer = true;

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
    _referrerController.dispose();
    _quoteController.dispose();
    _secondaryRoleController.dispose();
    _hobbyController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
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
      _accountEmail = profile.email;
      _referrerController.text = profile.referrerUsername;
      _quoteController.text = profile.quote;
      _secondaryRoleController.text = profile.role2;
      _hobbyController.text = profile.hobby;
      _cityController.text = profile.city;
      _phoneController.text = profile.phoneNumber;
      _gender = profile.gender.isNotEmpty ? profile.gender : 'male';
      _theme = profile.theme.isNotEmpty ? profile.theme : 'light';
      _emailNotifications = profile.emailNotifications;
      _selectedRole = profile.role1;
      _canEditReferrer = profile.referrerUsername.trim().isEmpty;
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
        _countryOptions = <String>[_selectedCountry, ..._countryOptions];
      }

      if (_selectedState.isNotEmpty) {
        _stateOptions = <String>[_selectedState];
      }

      final initialCountry = _selectedCountry;
      final shouldAutoLoadStates = initialCountry.trim().isNotEmpty;
      if (shouldAutoLoadStates) {
        // Auto-load states so the dropdown is ready without requiring a tap.
        _loadingStates = true;
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

    if (mounted && _selectedCountry.trim().isNotEmpty) {
      await _loadStates(_selectedCountry, preserveSelection: true);
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
          if (preserveSelection) {
            _stateOptions = <String>[_selectedState, ..._stateOptions];
          } else {
            _selectedState = '';
          }
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
        email: _accountEmail.trim(),
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
        referrer: _canEditReferrer ? _referrerController.text.trim() : null,
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
              showOnboardingActions: true,
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

  Future<void> _openSettings() async {
    final authController = AuthController.instance;
    if (authController == null) {
      AppToast.error(context, 'Unable to open settings right now.');
      return;
    }
    final username = authController.currentUser?.username.trim() ?? '';
    if (username.isEmpty) {
      AppToast.error(context, 'Unable to open settings right now.');
      return;
    }

    final sharedThemeController = AppActionsRegistry.themeController;
    final themeController = sharedThemeController ?? ThemeController();
    if (sharedThemeController == null) {
      await themeController.restore();
    }
    if (!mounted) {
      if (sharedThemeController == null) {
        themeController.dispose();
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          username: username,
          isVerified: authController.currentUser?.isVerified ?? false,
          currentUser: authController.currentUser,
          authRepository: authController.authRepository,
          profileRepository: widget.repository,
          themeController: themeController,
          onLogout: () async {
            await authController.logout();
            return true;
          },
          onCheckForUpdates: () async {
            final checkForUpdates = AppActionsRegistry.checkForUpdates;
            if (checkForUpdates == null) {
              if (!mounted) return;
              AppToast.error(context, 'Update check is unavailable right now.');
              return;
            }
            await checkForUpdates();
          },
        ),
      ),
    );
    if (sharedThemeController == null) {
      themeController.dispose();
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
        actions: widget.showOnboardingIntro
            ? null
            : [
                TextButton(
                  onPressed: _openSettings,
                  child: const Text('Settings'),
                ),
                const SizedBox(width: 4),
              ],
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
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: colors.borderStrong),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colors.accentSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.badge_outlined,
                                      color: colors.accentSoftText,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Step 2 of 3',
                                          style: TextStyle(
                                            color: colors.brand,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: LinearProgressIndicator(
                                            minHeight: 6,
                                            value: 2 / 3,
                                            backgroundColor: colors.surfaceMuted,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colors.brand,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Let\'s finish your details',
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
                        const SizedBox(height: 18),
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
                                label: 'Role',
                                child: DropdownButtonFormField<String>(
                                  initialValue:
                                      _selectedRole.isNotEmpty &&
                                          _roleOptions.contains(_selectedRole)
                                      ? _selectedRole
                                      : null,
                                  decoration: const InputDecoration(
                                    hintText: 'Select a role...',
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
                                    'Secondary Role (Career, Passion, or Aspiration)',
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
                            const SizedBox(height: 8),
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
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Country is required.';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) async {
                                      if (value == null) {
                                        return;
                                      }
                                      if (value == _selectedCountry) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedCountry = value;
                                        _selectedState = '';
                                        _stateOptions = const <String>[];
                                        _hasLoadedStatesForSelectedCountry =
                                            false;
                                      });
                                      await _loadStates(value);
                                    },
                                  ),
                                );
                                final stateField = _LabeledField(
                                  label: 'State / Region / Team',
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
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'State is required.';
                                      }
                                      return null;
                                    },
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
                                  label:
                                      'Birth Day (Lets celebrate with you! 🎉)',
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
                              label: 'Hobbies & Interests',
                              child: TextFormField(
                                controller: _hobbyController,
                              ),
                            ),
                            _LabeledField(
                              label: 'Favourite Quote',
                              child: TextFormField(
                                controller: _quoteController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Any quote or favourite saying',
                                ),
                              ),
                            ),
                            if (!widget.showOnboardingIntro)
                              _LabeledField(
                                label: 'Invited By (username)',
                                hint: _canEditReferrer
                                    ? 'Optional. Add only if someone invited you.'
                                    : 'Inviter is already set and cannot be changed.',
                                child: TextFormField(
                                  controller: _referrerController,
                                  enabled: _canEditReferrer,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    prefixText: '@',
                                    hintText: 'inviter username',
                                  ),
                                  validator: (value) {
                                    final cleaned = (value ?? '')
                                        .trim()
                                        .replaceFirst('@', '');
                                    if (cleaned.isEmpty) {
                                      return null;
                                    }
                                    if (!RegExp(
                                      r'^[a-zA-Z0-9_-]+$',
                                    ).hasMatch(cleaned)) {
                                      return 'Use a valid username only.';
                                    }
                                    final ownUsername = _usernameController.text
                                        .trim()
                                        .replaceFirst('@', '')
                                        .toLowerCase();
                                    if (cleaned.toLowerCase() == ownUsername) {
                                      return 'You cannot refer yourself.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!widget.showOnboardingIntro) const SizedBox(height: 18),
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
