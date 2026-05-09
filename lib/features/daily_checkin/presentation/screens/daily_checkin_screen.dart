import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/daily_checkin/data/daily_checkin_repository.dart';
import 'package:hopefulme_flutter/features/daily_checkin/models/daily_checkin_models.dart';

class DailyCheckinScreen extends StatefulWidget {
  const DailyCheckinScreen({
    required this.repository,
    this.firstName,
    this.onOpenConnect,
    this.onOpenGroups,
    this.onOpenQuotes,
    this.onSleepLogout,
    super.key,
  });

  final DailyCheckinRepository repository;
  final String? firstName;
  final Future<void> Function()? onOpenConnect;
  final Future<void> Function()? onOpenGroups;
  final Future<void> Function()? onOpenQuotes;
  final Future<void> Function()? onSleepLogout;

  @override
  State<DailyCheckinScreen> createState() => _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends State<DailyCheckinScreen> {
  static const _moods = <(String, String)>[
    ('Happy', '🙂'),
    ('Calm', '😌'),
    ('Hopeful', '🟣'),
    ('Stressed', '😟'),
    ('Sad', '🙁'),
    ('Lonely', '😔'),
    ('Angry', '😡'),
    ('Anxious', '😰'),
    ('Tired', '🥱'),
  ];
  static const _energyLevels = <String>['low', 'medium', 'high'];
  static const _focusAreas = <String>[
    'peace_of_mind',
    'work_school',
    'faith',
    'health',
    'personal_growth',
    'relationships',
    'business',
    'skill_learning',
  ];
  static const _statuses = <String>[
    'pending',
    'in_progress',
    'completed',
    'skipped',
    'paused',
  ];

  final _goalController = TextEditingController();
  final _contentController = TextEditingController();
  String _mood = 'Hopeful';
  String _energyLevel = 'medium';
  String _focusArea = 'personal_growth';
  String _status = 'in_progress';
  double _progress = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showLanding = false;
  String? _error;
  DailyCheckinEntry? _todayEntry;
  DailyCheckinSummary? _weeklySummary;
  List<DailyCheckinEntry> _history = const <DailyCheckinEntry>[];
  List<String> _suggestions = const <String>[];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _greetingWithName() {
    final raw = (widget.firstName ?? '').trim();
    final first = raw.isEmpty ? 'there' : raw.split(RegExp(r'\s+')).first;
    return '${_greeting()}, $first.';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = await widget.repository.fetchToday();
      final summary = await widget.repository.fetchSummary();
      final history = await widget.repository.fetchHistory(page: 1);
      if (!mounted) return;
      setState(() {
        _todayEntry = today;
        _weeklySummary = summary;
        _history = history;
        _showLanding = today != null;
        if (today != null) {
          _mood = today.mood.isNotEmpty ? today.mood : _mood;
          _energyLevel = today.energyLevel.isNotEmpty ? today.energyLevel : _energyLevel;
          _focusArea = today.focusArea.isNotEmpty ? today.focusArea : _focusArea;
          _status = today.status.isNotEmpty ? today.status : _status;
          _progress = today.progress.clamp(0, 100).toDouble();
          _goalController.text = today.goal;
          _contentController.text = today.content;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.saveCheckin(
        mood: _mood,
        energyLevel: _energyLevel,
        focusArea: _focusArea,
        status: _status,
        progress: _progress.round(),
        goal: _goalController.text.trim(),
        content: _contentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _todayEntry = result.$1;
        _suggestions = result.$3;
        _showLanding = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily check-in saved.')),
      );
      final summary = await widget.repository.fetchSummary();
      final history = await widget.repository.fetchHistory(page: 1);
      if (!mounted) return;
      setState(() {
        _weeklySummary = summary;
        _history = history;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Check-in')),
        body: AppStatusState.fromError(
          error: _error!,
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_showLanding ? 'Daily Check-in' : 'Daily Check-in')),
      body: _showLanding ? _buildLanding(context) : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/checkin.webp',
            width: double.infinity,
            height: 136,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '1. How are you feeling today?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text('Choose your mood', style: TextStyle(color: colors.textMuted)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemCount: _moods.length,
          itemBuilder: (context, i) {
            final item = _moods[i];
            final selected = _mood.toLowerCase() == item.$1.toLowerCase();
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _mood = item.$1),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFF3EEFF) : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? const Color(0xFF6D3FE3) : colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$2, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        const Text(
          '2. What’s your energy level?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _energyLevels
              .map(
                (item) => ChoiceChip(
                  label: Text(item[0].toUpperCase() + item.substring(1)),
                  selected: _energyLevel == item,
                  onSelected: (_) => setState(() => _energyLevel = item),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          '3. What do you want to focus on today?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _focusAreas
              .map(
                (item) => ChoiceChip(
                  label: Text(item.replaceAll('_', ' ')),
                  selected: _focusArea == item,
                  onSelected: (_) => setState(() => _focusArea = item),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          '4. Anything on your mind? (optional)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contentController,
          maxLength: 2000,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Write your thoughts...'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _goalController,
          maxLength: 255,
          decoration: const InputDecoration(hintText: 'Goal for today'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _status,
          items: _statuses
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.replaceAll('_', ' ')),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _status = value);
          },
          decoration: const InputDecoration(labelText: 'Goal status'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Progress', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_progress.round()}%'),
          ],
        ),
        Slider(
          value: _progress,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: const Color(0xFF6D3FE3),
          inactiveColor: const Color(0xFF6D3FE3).withValues(alpha: 0.2),
          onChanged: (v) => setState(() => _progress = v),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6D3FE3),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Check-in'),
        ),
      ],
    );
  }

  Widget _buildLanding(BuildContext context) {
    final colors = context.appColors;
    final entry = _todayEntry;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/checkin.webp',
            width: double.infinity,
            height: 136,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _greetingWithName(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          'You are a special person. Your journey matters. Keep going.',
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: _emojiForMood(entry?.mood),
                  subtitle: entry == null ? 'Not saved yet' : entry.mood,
                  meta: entry == null ? '' : 'Energy: ${entry.energyLevel}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoCard(
                  title: "Today's Focus",
                  subtitle: entry == null ? '-' : entry.focusArea.replaceAll('_', ' '),
                  meta: entry == null ? '' : 'Status: ${entry.status.replaceAll('_', ' ')}',
                  progress: entry?.progress ?? 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showLanding = false),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Update check-in'),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._suggestions.take(3).map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $s'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _GrowthWeekCard(summary: _weeklySummary),
        const SizedBox(height: 10),
        _SimpleMoodTrendCard(entries: _history),
        // What do you need right now? hidden for now until routes are stable.
        const SizedBox(height: 14),
        Text(
          'Daily check-ins are automatically deleted after 30 days for privacy. This feature is still being improved.',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  String _emojiForMood(String? mood) {
    final key = (mood ?? '').toLowerCase();
    if (key.contains('happy')) return '🙂';
    if (key.contains('calm')) return '😌';
    if (key.contains('hope')) return '😊';
    if (key.contains('stress')) return '😟';
    if (key.contains('sad')) return '🙁';
    if (key.contains('lonely')) return '😔';
    if (key.contains('angry')) return '😡';
    if (key.contains('anxious')) return '😰';
    if (key.contains('tired')) return '🥱';
    return '🙂';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.meta = '',
    this.progress,
  });

  final String title;
  final String subtitle;
  final String meta;
  final int? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEmojiTitle = title.runes.length <= 2;
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isEmojiTitle ? 32 : 16,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (meta.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(color: colors.textMuted, fontSize: 11)),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progress!.clamp(0, 100)) / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFF6D3FE3).withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6D3FE3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrowthWeekCard extends StatelessWidget {
  const _GrowthWeekCard({required this.summary});

  final DailyCheckinSummary? summary;

  @override
  Widget build(BuildContext context) {
    final checkins = summary?.checkinsCount ?? 0;
    final completedGoals = summary?.completedGoals ?? 0;
    final commonMood = summary?.commonMood.trim().isNotEmpty == true ? summary!.commonMood : 'N/A';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6D3FE3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Growth This Week',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatPill(value: '$checkins', label: 'Check-ins'),
              const SizedBox(width: 8),
              _StatPill(value: '$completedGoals', label: 'Goals done'),
              const SizedBox(width: 8),
              _StatPill(value: commonMood, label: 'Common mood'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleMoodTrendCard extends StatelessWidget {
  const _SimpleMoodTrendCard({required this.entries});

  final List<DailyCheckinEntry> entries;

  static const _scores = <String, int>{
    'happy': 5,
    'hopeful': 5,
    'calm': 4,
    'tired': 3,
    'stressed': 2,
    'anxious': 2,
    'sad': 1,
    'lonely': 1,
    'angry': 1,
  };

  static const _moodEmoji = <String, String>{
    'happy': '🙂',
    'hopeful': '😊',
    'calm': '😌',
    'tired': '🥱',
    'stressed': '😟',
    'anxious': '😰',
    'sad': '🙁',
    'lonely': '😔',
    'angry': '😡',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final recent = entries.take(7).toList().reversed.toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mood Trend', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: recent.map((entry) {
              final key = entry.mood.trim().toLowerCase();
              final score = _scores[key] ?? 3;
              final emoji = _moodEmoji[key] ?? '🙂';
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Container(
                      height: (score * 10).toDouble(),
                      width: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D3FE3).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              recent.length,
              (index) => Expanded(
                child: Text(
                  'D${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last ${recent.length} check-ins',
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}


