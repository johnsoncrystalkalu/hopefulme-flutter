import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/auth_welcome_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authController, super.key});

  static const routeName = '/login';

  final AuthController authController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    try {
      final success = await widget.authController.login(
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      if (widget.authController.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) {
          final errorText = widget.authController.errorMessage;

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showHero = constraints.maxWidth >= 980;

                return Row(
                  children: [
                    if (showHero) const Expanded(child: _AuthHeroPanel()),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: showHero ? 40 : 20,
                            vertical: 24,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!showHero)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 24,
                                      ),
                                      child: Text(
                                        'HopefulMe.',
                                        style: TextStyle(
                                          color: colors.brand,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                InkWell(
                                  onTap: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                        AuthWelcomeScreen.routeName,
                                        (route) => route.isFirst,
                                      ),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_back,
                                          size: 18,
                                          color: colors.textMuted,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Back to welcome',
                                          style: TextStyle(
                                            color: colors.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(40),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.shadow,
                                        blurRadius: 60,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome back!',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Sign in to your account to continue.',
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: colors.dangerText
                                                    .withOpacity(0.35),
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
                                          'Email or Username',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _loginController,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Please enter your email address or username.';
                                            }
                                            return null;
                                          },
                                          decoration: _inputDecoration(
                                            hintText:
                                                'Username, email or phone',
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Password',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.4,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Forgot password?',
                                              style: TextStyle(
                                                color: colors.brand,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: !_showPassword,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your password.';
                                            }
                                            return null;
                                          },
                                          decoration: _inputDecoration(
                                            hintText: '........',
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _showPassword =
                                                      !_showPassword;
                                                });
                                              },
                                              icon: Icon(
                                                _showPassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: colors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: true,
                                              onChanged: (_) {},
                                              activeColor: colors.brand,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            Text(
                                              'Remember me',
                                              style: TextStyle(
                                                color: colors.textMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: colors.brandGradient,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colors.brand
                                                      .withOpacity(0.28),
                                                  blurRadius: 30,
                                                  offset: Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed:
                                                  widget
                                                      .authController
                                                      .isSubmitting
                                                  ? null
                                                  : _submit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 18,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              child:
                                                  widget
                                                      .authController
                                                      .isSubmitting
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Sign In',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        Center(
                                          child: Wrap(
                                            children: [
                                              Text(
                                                'New here? ',
                                                style: TextStyle(
                                                  color: colors.textMuted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap:
                                                    widget
                                                        .authController
                                                        .isSubmitting
                                                    ? null
                                                    : () {
                                                        widget.authController
                                                            .clearError();
                                                        Navigator.of(
                                                          context,
                                                        ).pushNamed(
                                                          RegisterScreen
                                                              .routeName,
                                                        );
                                                      },
                                                child: Text(
                                                  'Create an account',
                                                  style: TextStyle(
                                                    color: colors.brand,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Default API URL is configured from app environment.',
                                  style: TextStyle(
                                    color: colors.textMuted.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final colors = context.appColors;
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surfaceMuted.withOpacity(0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.brand),
      ),
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/login-community.jpg', fit: BoxFit.cover),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.fromRGBO(15, 23, 42, 0.92),
                Color.fromRGBO(15, 23, 42, 0.58),
                Color.fromRGBO(15, 23, 42, 0.12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(79, 70, 229, 0.3),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'JOIN HOPEFULME COMMUNITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 2.1,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Inspire\nThe World\nAround You.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 82,
                child: Divider(thickness: 6, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Meet new friends, attend our hangouts, share inspiring posts..',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.9),
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
