class DailyCheckinEntry {
  const DailyCheckinEntry({
    required this.id,
    required this.userId,
    required this.checkinDate,
    required this.content,
    required this.mood,
    required this.energyLevel,
    required this.focusArea,
    required this.status,
    required this.goal,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final String checkinDate;
  final String content;
  final String mood;
  final String energyLevel;
  final String focusArea;
  final String status;
  final String goal;
  final int progress;
  final String createdAt;
  final String updatedAt;

  factory DailyCheckinEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DailyCheckinEntry(
      id: parseInt(json['id']),
      userId: parseInt(json['user_id']),
      checkinDate: json['checkin_date']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mood: json['mood']?.toString() ?? '',
      energyLevel: json['energy_level']?.toString() ?? '',
      focusArea: json['focus_area']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      goal: json['goal']?.toString() ?? '',
      progress: parseInt(json['progress']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class DailyCheckinSummary {
  const DailyCheckinSummary({
    required this.checkinsCount,
    required this.completedGoals,
    required this.commonMood,
    required this.encouragement,
  });

  final int checkinsCount;
  final int completedGoals;
  final String commonMood;
  final String encouragement;

  factory DailyCheckinSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DailyCheckinSummary(
      checkinsCount: parseInt(json['checkins_count']),
      completedGoals: parseInt(json['completed_goals']),
      commonMood: json['common_mood']?.toString() ?? '',
      encouragement: json['encouragement']?.toString() ?? '',
    );
  }
}
