import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/register_screen.dart';

class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({required this.authController, super.key});

  static const routeName = '/welcome';
  final AuthController authController;

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  void _openLogin() {
    Navigator.of(context).pushNamed(LoginScreen.routeName);
  }

  void _openRegister() {
    Navigator.of(context).pushNamed(RegisterScreen.routeName);
  }

  // Refined slide data using your brand's core palette
  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      title: 'Welcome to\nHopefulMe.',
      description:
          'An inspirational social network community, built just for you.',
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFF2563EB), // Primary Brand Blue
    ),
    _OnboardingSlideData(
      title: 'Connect and meet\nnew friends.',
      description:
          'Chat, share photos, publish articles, join groups, play games and connect with inspiring people across the globe.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF4F46E5), // Indigo Accent
    ),
    _OnboardingSlideData(
      title: 'Join our physical\nevents and hangouts.',
      description:
          'Attend exciting meetups, life-changing programs, and city tours. HopefulMe organizes several events and conferences across multiple locations.',
      icon: Icons.event_available_rounded,
      accent: Color(0xFF059669), // Emerald Accent
    ),
    _OnboardingSlideData(
      title: 'Be part of our Outreach programs.',
      description:
          'Get involved in meaningful community projects and outreach initiatives that change lives.',
      icon: Icons.handshake_rounded,
      accent: Color(0xFFDB2777), // Rose Accent
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Stack(
        children: [
          // Background soft glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brand.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Minimalist Top Nav
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _openLogin,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: RepaintBoundary(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (i) => _pageIndex.value = i,
                      itemBuilder: (context, i) =>
                          _RefinedSlide(data: _slides[i]),
                    ),
                  ),
                ),

                // Footer Actions
                RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pageIndex,
                    builder: (context, pageIndex, _) {
                      final isLastPage = pageIndex == _slides.length - 1;
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _slides.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  height: 6,
                                  width: pageIndex == index ? 32 : 6,
                                  decoration: BoxDecoration(
                                    color: pageIndex == index
                                        ? colors.brand
                                        : colors.borderStrong,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                  color: colors.brand,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.brand.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isLastPage
                                      ? _openRegister
                                      : () => _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 380,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.brand,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    isLastPage
                                        ? 'Create Free Account'
                                        : 'Continue',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isLastPage) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colors.brand.withValues(alpha: 0.14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.shadow.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: _openLogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.textPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: colors.brand.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.login_rounded,
                                          color: colors.brand,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Already a member?',
                                              style: TextStyle(
                                                color: colors.textMuted,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Sign in to your account',
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: colors.brand,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefinedSlide extends StatelessWidget {
  final _OnboardingSlideData data;
  const _RefinedSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(data.icon, size: 36, color: data.accent),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: colors.textPrimary,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            style: TextStyle(
              fontSize: 17,
              color: colors.textMuted,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlideData {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;

  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });
}
