import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/daily_checkin/data/daily_checkin_repository.dart';
import 'package:hopefulme_flutter/features/daily_checkin/models/daily_checkin_models.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _checkinBannerUrl = 'https://ahopefulme.com/img/misc/checkin.webp';
  static const _moods = <(String, String)>[
    ('Happy', '🙂'),
    ('Calm', '😌'),
    ('Hopeful', '🟣'),
    ('Stressed', '😟'),
    ('Sad', '🙁'),
    ('Lonely', '😔'),
    ('Angry', '😡'),
    ('Anxious', '😰'),
    ('Tired', '😩'),
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
                    color: selected ? const Color(0xFF3252E6) : colors.border,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected ? const Color(0xFF1F2937) : colors.textPrimary,
                      ),
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
          '4. Journal (optional)',
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
        const SizedBox(height: 8),
        const Text(
          '5. Goal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
          activeColor: const Color(0xFF3252E6),
          inactiveColor: const Color(0xFF3252E6).withValues(alpha: 0.2),
          onChanged: (v) => setState(() => _progress = v),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3252E6),
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
        const SizedBox(height: 8),
        Text(
          'Private to you: only you can see your daily check-in. Entries are automatically cleared after 30 days.',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
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
        _checkinBanner(
          title: _greetingWithName(),
          subtitle: 'You are a special person. Your journey matters. Keep going.',
        ),
        const SizedBox(height: 10),
        Text(
          'Today\'s Check-in (Visible only to you)',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
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
                  title: '🎯',
                  subtitle: entry == null ? '-' : entry.focusArea.replaceAll('_', ' '),
                  meta: "Today's focus",
                ),
              ),
            ],
          ),
        ),
        if ((entry?.goal ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _EntryNoteCard(
            title: "Today's Goal",
            content: entry!.goal.trim(),
            icon: Icons.track_changes_outlined,
            meta: 'Status: ${entry.status.replaceAll('_', ' ')}',
            progress: entry.progress,
          ),
        ],
        if ((entry?.content ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _EntryNoteCard(
            title: 'Journal',
            content: entry!.content.trim(),
            icon: Icons.menu_book_outlined,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => setState(() => _showLanding = false),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Update Check-in'),
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
        if (_isSupportMood(entry?.mood ?? _mood)) ...[
          const SizedBox(height: 18),
          _NeedNowSection(
            onOpenGroups: widget.onOpenGroups,
            onOpenQuotes: widget.onOpenQuotes,
            onSleepLogout: widget.onSleepLogout,
          ),
        ],
        const SizedBox(height: 8),
        _GrowthWeekCard(summary: _weeklySummary),
        const SizedBox(height: 10),
        _SimpleMoodTrendCard(entries: _history),
        const SizedBox(height: 10),
        _EntriesSection(
          entries: _history.take(30).toList(),
          moodEmojiFor: _emojiForMood,
          onDelete: _deleteEntry,
        ),
        const SizedBox(height: 14),
        // Text(
        //   'Daily check-ins are automatically deleted after 30 days for privacy. This feature is still being improved.',
        //   style: TextStyle(
        //     color: colors.textMuted,
        //     fontSize: 10,
        //     fontWeight: FontWeight.w500,
        //     height: 1.35,
        //   ),
        // ),
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
    if (key.contains('tired')) return '🫩';
    return '🙂';
  }

  bool _isSupportMood(String mood) {
    final key = mood.trim().toLowerCase();
    return key.contains('stressed') ||
        key.contains('lonely') ||
        key.contains('anxious') ||
        key.contains('tired') ||
        key.contains('sad') ||
        key.contains('angry');
  }

  Widget _checkinBanner({String? title, String? subtitle}) {
    final showOverlayText =
        (title ?? '').trim().isNotEmpty || (subtitle ?? '').trim().isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 136,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _checkinBannerUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Image.asset(
                'assets/images/checkin.webp',
                fit: BoxFit.cover,
              ),
            ),
            if (showOverlayText)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            if (showOverlayText)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if ((title ?? '').trim().isNotEmpty)
                      Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(DailyCheckinEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This will remove this check-in entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (entry.id <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this entry right now.')),
      );
      return;
    }
    try {
      await widget.repository.deleteEntry(entry.id);
      if (!mounted) return;
      setState(() {
        _history = _history.where((item) => item.id != entry.id).toList();
        if (_todayEntry?.id == entry.id) {
          _todayEntry = null;
        }
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }
}

class _EntriesSection extends StatelessWidget {
  const _EntriesSection({
    required this.entries,
    required this.moodEmojiFor,
    required this.onDelete,
  });

  final List<DailyCheckinEntry> entries;
  final String Function(String?) moodEmojiFor;
  final Future<void> Function(DailyCheckinEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Check-ins',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'No past entries yet.',
              style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ...entries.map((entry) {
          final moodText = entry.mood.trim().isEmpty ? '-' : entry.mood.trim();
          final goalText = entry.goal.trim().isEmpty ? 'No goal set' : entry.goal.trim();
          final journal = entry.content.trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _exactDate(entry.checkinDate),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        moodEmojiFor(entry.mood),
                        style: const TextStyle(fontSize: 20),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete(entry);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Mood: $moodText'),
                  const SizedBox(height: 4),
                  Text(
                    'Goal: $goalText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Status: ${entry.status.replaceAll('_', ' ')}',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.progress.clamp(0, 100)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (entry.progress.clamp(0, 100)) / 100,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF3252E6).withValues(alpha: 0.16),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3252E6)),
                    ),
                  ),
                  if (journal.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Journal: $journal',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static String _exactDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final date = parsed.toLocal();
    return '${_weekday(date.weekday)}, ${date.day}${_ordinal(date.day)} ${_month(date.month)}, ${date.year}';
  }

  static String _weekday(int weekday) {
    const names = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  static String _month(int month) {
    const names = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

class _NeedNowSection extends StatelessWidget {
  const _NeedNowSection({
    this.onOpenGroups,
    this.onOpenQuotes,
    this.onSleepLogout,
  });

  final Future<void> Function()? onOpenGroups;
  final Future<void> Function()? onOpenQuotes;
  final Future<void> Function()? onSleepLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you need right now?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            _NeedNowCard(
              emoji: '💜',
              title: 'Encouraging Words',
              background: const Color(0xFFF1EAFE),
              darkBackground: const Color(0xFF2F2546),
              onTap: onOpenQuotes,
            ),
            _NeedNowCard(
              emoji: '👥',
              title: 'Talk to Someone',
              background: const Color(0xFFE7F0FF),
              darkBackground: const Color(0xFF22324A),
              onTap: onOpenGroups,
            ),
            _NeedNowCard(
              emoji: '😴',
              title: 'Rest and Sleep',
              background: const Color(0xFFFFF0DA),
              darkBackground: const Color(0xFF433726),
              onTap: onSleepLogout,
            ),
            _NeedNowCard(
              emoji: '🎵',
              title: 'Listen to Music',
              background: const Color(0xFFEAF7EF),
              darkBackground: const Color(0xFF20392C),
              onTap: () async {
                final uri = Uri.parse('https://open.spotify.com');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedNowCard extends StatelessWidget {
  const _NeedNowCard({
    required this.emoji,
    required this.title,
    required this.background,
    required this.darkBackground,
    this.onTap,
  });

  final String emoji;
  final String title;
  final Color background;
  final Color darkBackground;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap == null ? null : () => onTap!.call(),
      child: Ink(
        decoration: BoxDecoration(
          color: isDark ? darkBackground : background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryNoteCard extends StatelessWidget {
  const _EntryNoteCard({
    required this.title,
    required this.content,
    required this.icon,
    this.meta,
    this.progress,
  });

  final String title;
  final String content;
  final IconData icon;
  final String? meta;
  final int? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 18, color: const Color(0xFF3252E6)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((meta ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta!,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${progress!.clamp(0, 100)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progress!.clamp(0, 100)) / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFF3252E6).withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3252E6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
                backgroundColor: const Color(0xFF3252E6).withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3252E6),
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
        color: const Color(0xFF3252E6),
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
    'tired': '🫩',
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
                        color: const Color(0xFF3252E6).withValues(alpha: 0.85),
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


