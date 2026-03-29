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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'Write something kind, honest, and uplifting.',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Write your inspiration here...',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Presets',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoadingPresets)
                  const CircularProgressIndicator()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets
                        .map(
                          (preset) => ChoiceChip(
                            label: Text(preset),
                            selected: _selectedPreset == preset,
                            onSelected: (_) {
                              setState(() {
                                _selectedPreset = _selectedPreset == preset
                                    ? null
                                    : preset;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value;
                    });
                  },
                  title: const Text('Send anonymously'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  title: const Text('Make public on profile'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSending ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
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
    );
  }
}
