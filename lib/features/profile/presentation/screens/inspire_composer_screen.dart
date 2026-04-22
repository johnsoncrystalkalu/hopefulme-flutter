import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';

class InspireComposerScreen extends StatefulWidget {
  const InspireComposerScreen({
    required this.profile,
    required this.repository,
    super.key,
  });

  final ProfileSummary profile;
  final ProfileRepository repository;

  @override
  State<InspireComposerScreen> createState() => _InspireComposerScreenState();
}

class _InspireComposerScreenState extends State<InspireComposerScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _presets = const <String>[];
  String? _selectedPreset;
  bool _isAnonymous = false;
  bool _isPublic = false;
  bool _isLoadingPresets = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await widget.repository.fetchInspirationPresets();
      if (!mounted) return;
      setState(() {
        _presets = presets;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPresets = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.length < 5 || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.repository.sendInspiration(
        username: widget.profile.username,
        message: text,
        isAnonymous: _isAnonymous,
        isPublic: _isPublic,
        preset: _selectedPreset,
      );
      if (!mounted) return;
      AppToast.success(context, 'Your inspiration has been sent.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
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
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Text('Inspire ${widget.profile.displayName}'),
      ),
      body: Center(
        child: Transform.translate(
          offset: const Offset(8, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
      // Hero Section
      Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        colors.brand.withValues(alpha: 0.95),
        colors.brand.withValues(alpha: 0.85),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(28),
  ),
  child: Stack(
    children: [
      // Dotted pattern overlay
      Positioned.fill(
        child: CustomPaint(
          painter: _DottedPatternPainter(
            dotColor: Colors.white.withValues(alpha: 0.06),
            dotSpacing: 20,
          ),
        ),
      ),

      // Decorative glow
      Positioned(
        top: 0,
        right: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.brand.withValues(alpha: 0.2),
                colors.brand.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),

      // Content (FIXED)
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // vertical center
            crossAxisAlignment: CrossAxisAlignment.center, // horizontal center
            children: [
              const Text('💙', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'A Gift of Hope',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send some encouragement to ${widget.profile.displayName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 24),
      // Main Form Card
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.borderStrong),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Send encouragement',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Write something inspiring and uplifting. (max 500 characters)',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Text Input
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _controller,
                minLines: 8,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Write your inspiration here...',
                  hintStyle: TextStyle(color: colors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Presets Section
            Text(
              'Quick picks',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingPresets)
              SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.brand,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presets
                    .map(
                      (preset) => FilterChip(
                        label: Text(preset),
                        selected: _selectedPreset == preset,
                        onSelected: (_) {
                          setState(() {
                            _selectedPreset = _selectedPreset == preset
                                ? null
                                : preset;
                            if (_selectedPreset == preset &&
                                _controller.text.trim().isEmpty) {
                              _controller.text = preset;
                              _controller.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: preset.length),
                              );
                            }
                          });
                        },
                        backgroundColor: colors.surfaceMuted,
                        selectedColor: colors.brand.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: _selectedPreset == preset
                              ? colors.brand
                              : colors.border,
                        ),
                        labelStyle: TextStyle(
                          color: _selectedPreset == preset
                              ? colors.brand
                              : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            // Options Section
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _OptionSwitch(
                    icon: Icons.visibility_off_outlined,
                    title: 'Send anonymously',
                    subtitle: 'Your name won\'t be shown',
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                      });
                    },
                  ),
                  Divider(
                    height: 1,
                    color: colors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _OptionSwitch(
                    icon: Icons.public,
                    title: 'Make public on profile',
                    subtitle: 'Others can see this message',
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Send Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Inspiration'),
              ),
            ),
          ],
        ),
      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.brand,
          ),
        ],
      ),
    );
  }
}

class _DottedPatternPainter extends CustomPainter {
  _DottedPatternPainter({required this.dotColor, this.dotSpacing = 28.0});

  final Color dotColor;
  final double dotSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const dotRadius = 1.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPatternPainter oldDelegate) => false;
}
