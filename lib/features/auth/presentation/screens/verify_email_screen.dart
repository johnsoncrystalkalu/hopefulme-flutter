import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/widgets/auth_page_footer.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.authRepository,
    required this.verificationUri,
    super.key,
  });

  final AuthRepository authRepository;
  final Uri verificationUri;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSubmitting = false;
  bool _isVerified = false;
  String? _errorText;

  int? get _userId {
    final segments = widget.verificationUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 3) {
      return null;
    }
    if (segments.first.toLowerCase() != 'verify-email') {
      return null;
    }
    return int.tryParse(segments[1]);
  }

  String get _hash {
    final segments = widget.verificationUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 3) {
      return '';
    }
    return Uri.decodeComponent(segments[2]).trim();
  }

  String get _expires =>
      widget.verificationUri.queryParameters['expires'] ?? '';

  String get _signature =>
      widget.verificationUri.queryParameters['signature'] ?? '';

  bool get _hasValidLink =>
      _userId != null &&
      _userId! > 0 &&
      _hash.isNotEmpty &&
      _expires.trim().isNotEmpty &&
      _signature.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_hasValidLink || _isSubmitting || _isVerified) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final message = await widget.authRepository.verifyEmailFromLink(
        userId: _userId!,
        hash: _hash,
        expires: _expires,
        signature: _signature,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isVerified = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Could not verify your email right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: _hasValidLink
                    ? _buildValidBody(context)
                    : _buildInvalidBody(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidBody(BuildContext context) {
    final colors = context.appColors;
    final description = _isVerified
        ? 'Your email is now verified. You can continue to sign in and use the app.'
        : 'Tap the button below to securely verify your email address.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isVerified ? 'Email verified' : 'Verify your email',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 18),
          _FeedbackBox(
            message: _errorText!,
            backgroundColor: colors.dangerSoft,
            borderColor: colors.dangerText,
            textColor: colors.dangerText,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_isSubmitting || _isVerified) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isVerified ? 'Email Verified' : 'Verify Email',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(LoginScreen.routeName),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Go to Sign In',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const AuthPageFooter(),
      ],
    );
  }

  Widget _buildInvalidBody(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification link unavailable',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This verification link looks incomplete. Please request a new verification email and try again.',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(LoginScreen.routeName),
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const AuthPageFooter(),
      ],
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}
