class UserProfile {
  const UserProfile({
    required this.heightCm,
    required this.weightKg,
    required this.hasDisease,
    required this.exerciseMinutes,
    required this.equipments,
    this.gender = 'unknown',
    this.goal = '',
    this.notes = '',
    this.trainingHistorySummary = '',
    this.targetMinutesIncludesRest = true,
  });

  final double heightCm;
  final double weightKg;
  final bool hasDisease;
  final int exerciseMinutes;
  final List<String> equipments;
  final String gender;
  final String goal;
  final String notes;
  final String trainingHistorySummary;
  final bool targetMinutesIncludesRest;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      hasDisease: json['has_disease'] as bool? ?? false,
      exerciseMinutes: (json['exercise_minutes'] as num?)?.toInt() ?? 0,
      equipments: (json['equipments'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      gender: json['gender'] as String? ?? 'unknown',
      goal: json['goal'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      trainingHistorySummary: json['training_history_summary'] as String? ?? '',
      targetMinutesIncludesRest:
          json['target_minutes_includes_rest'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'has_disease': hasDisease,
      'exercise_minutes': exerciseMinutes,
      'equipments': equipments,
      'gender': gender,
      'goal': goal,
      'notes': notes,
      'training_history_summary': trainingHistorySummary,
      'target_minutes_includes_rest': targetMinutesIncludesRest,
    };
  }
}

class DailyHealthMetrics {
  const DailyHealthMetrics({
    required this.weightKg,
    required this.systolic,
    required this.diastolic,
    required this.date,
  });

  final double weightKg;
  final int systolic;
  final int diastolic;
  final DateTime date;

  factory DailyHealthMetrics.fromJson(Map<String, dynamic> json) {
    final bloodPressure = json['blood_pressure'] as Map<String, dynamic>? ?? {};
    return DailyHealthMetrics(
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      systolic: (bloodPressure['systolic'] as num?)?.toInt() ?? 0,
      diastolic: (bloodPressure['diastolic'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight_kg': weightKg,
      'blood_pressure': {'systolic': systolic, 'diastolic': diastolic},
    };
  }
}

class DailyHealthSnapshot {
  const DailyHealthSnapshot({
    required this.date,
    required this.weightKg,
    required this.systolic,
    required this.diastolic,
  });

  final DateTime date;
  final double weightKg;
  final int systolic;
  final int diastolic;

  factory DailyHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final bloodPressure = json['blood_pressure'] as Map<String, dynamic>? ?? {};
    return DailyHealthSnapshot(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      systolic: (bloodPressure['systolic'] as num?)?.toInt() ?? 0,
      diastolic: (bloodPressure['diastolic'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight_kg': weightKg,
      'blood_pressure': {'systolic': systolic, 'diastolic': diastolic},
    };
  }
}

class ComponentContract {
  const ComponentContract();

  Map<String, dynamic> toJson() {
    return {
      'timer_button': {
        'states': ['idle', 'running', 'paused', 'completed'],
        'supports_countdown_seconds': true,
      },
      'completion_feedback': {
        'effects': ['checkmark_scale', 'particles', 'pulse'],
        'supports_message': true,
      },
      'risk_banner': {'collapsible': true, 'supports_expand': true},
    };
  }
}

class TrainingItem {
  const TrainingItem({
    required this.title,
    required this.durationMinutes,
    required this.intensity,
    required this.equipment,
    required this.instructions,
    this.type = 'exercise',
    this.durationSeconds,
    this.displayTitle,
  });

  final String type;
  final String title;
  final String? displayTitle;
  final int durationMinutes;
  final int? durationSeconds;
  final String intensity;
  final String equipment;
  final String instructions;

  int get normalizedDurationSeconds {
    if (durationSeconds != null && durationSeconds! > 0) {
      return durationSeconds!;
    }
    return durationMinutes <= 0 ? 1 : durationMinutes * 60;
  }

  String get effectiveTitle {
    final raw = displayTitle?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return title;
  }

  factory TrainingItem.fromJson(Map<String, dynamic> json) {
    final seconds = (json['duration_seconds'] as num?)?.toInt();
    final minutes = (json['duration_minutes'] as num?)?.toInt() ?? 0;
    final normalizedSeconds = seconds ?? (minutes > 0 ? minutes * 60 : 0);
    final normalizedMinutes = minutes > 0
        ? minutes
        : normalizedSeconds > 0
        ? (normalizedSeconds / 60).ceil()
        : 0;

    return TrainingItem(
      type: json['type'] as String? ?? 'exercise',
      title: json['title'] as String? ?? '未命名训练',
      displayTitle: json['display_title'] as String?,
      durationMinutes: normalizedMinutes,
      durationSeconds: normalizedSeconds > 0 ? normalizedSeconds : null,
      intensity: json['intensity'] as String? ?? '中等',
      equipment: json['equipment'] as String? ?? '无器械',
      instructions: json['instructions'] as String? ?? '保持动作标准，注意呼吸。',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'display_title': displayTitle,
      'duration_minutes': durationMinutes,
      'duration_seconds': normalizedDurationSeconds,
      'intensity': intensity,
      'equipment': equipment,
      'instructions': instructions,
    };
  }
}

class TrainingPlan {
  const TrainingPlan({
    required this.items,
    required this.components,
    required this.dietAdvice,
    required this.hydrationAdvice,
    required this.warning,
    required this.hydrationTargetMl,
  });

  final List<TrainingItem> items;
  final List<TrainingComponentConfig> components;
  final String dietAdvice;
  final String hydrationAdvice;
  final String warning;
  final int hydrationTargetMl;

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    final rawItems = json['training_items'] as List<dynamic>? ?? const [];
    final rawComponents = json['components'] as List<dynamic>? ?? const [];
    return TrainingPlan(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TrainingItem.fromJson)
          .toList(growable: false),
      components: rawComponents
          .whereType<Map<String, dynamic>>()
          .map(TrainingComponentConfig.fromJson)
          .toList(growable: false),
      dietAdvice: json['diet_advice'] as String? ?? '今天保持优质蛋白和复合碳水。',
      hydrationAdvice:
          json['hydration_advice'] as String? ?? '训练前后分次补水，总量约 2L。',
      warning: json['warning'] as String? ?? '若出现头晕/胸闷请立即停止训练。',
      hydrationTargetMl: (json['hydration_target_ml'] as num?)?.toInt() ?? 2000,
    );
  }

  int get totalDurationSeconds =>
      items.fold<int>(0, (sum, item) => sum + item.normalizedDurationSeconds);

  int get restDurationSeconds => items
      .where((item) => item.type == 'rest')
      .fold<int>(0, (sum, item) => sum + item.normalizedDurationSeconds);

  Map<String, dynamic> toJson() {
    return {
      'training_items': items
          .map((item) => item.toJson())
          .toList(growable: false),
      'components': components
          .map((component) => component.toJson())
          .toList(growable: false),
      'diet_advice': dietAdvice,
      'hydration_advice': hydrationAdvice,
      'warning': warning,
      'hydration_target_ml': hydrationTargetMl,
    };
  }
}

class TrainingComponentConfig {
  const TrainingComponentConfig({required this.component, required this.props});

  final String component;
  final Map<String, dynamic> props;

  factory TrainingComponentConfig.fromJson(Map<String, dynamic> json) {
    return TrainingComponentConfig(
      component: json['component'] as String? ?? 'training_card',
      props: json['props'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {'component': component, 'props': props};
  }
}

class PlanDigest {
  const PlanDigest({
    required this.itemCount,
    required this.totalTargetSeconds,
    this.restTargetSeconds = 0,
  });

  final int itemCount;
  final int totalTargetSeconds;
  final int restTargetSeconds;

  factory PlanDigest.fromJson(Map<String, dynamic> json) {
    return PlanDigest(
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      totalTargetSeconds: (json['total_target_seconds'] as num?)?.toInt() ?? 0,
      restTargetSeconds: (json['rest_target_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_count': itemCount,
      'total_target_seconds': totalTargetSeconds,
      'rest_target_seconds': restTargetSeconds,
    };
  }
}

class TrainingItemRecord {
  const TrainingItemRecord({
    required this.itemIndex,
    required this.title,
    required this.durationTargetSec,
    required this.actualElapsedSec,
    this.startedAt,
    this.completedAt,
  });

  final int itemIndex;
  final String title;
  final int durationTargetSec;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int actualElapsedSec;

  factory TrainingItemRecord.fromJson(Map<String, dynamic> json) {
    return TrainingItemRecord(
      itemIndex: (json['item_index'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      durationTargetSec: (json['duration_target_sec'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      actualElapsedSec: (json['actual_elapsed_sec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_index': itemIndex,
      'title': title,
      'duration_target_sec': durationTargetSec,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'actual_elapsed_sec': actualElapsedSec,
    };
  }
}

class DailyCheckinRecord {
  const DailyCheckinRecord({
    required this.date,
    required this.planDigest,
    required this.itemRecords,
    required this.completed,
  });

  final String date;
  final PlanDigest planDigest;
  final List<TrainingItemRecord> itemRecords;
  final bool completed;

  factory DailyCheckinRecord.fromJson(Map<String, dynamic> json) {
    return DailyCheckinRecord(
      date: json['date'] as String? ?? '',
      planDigest: PlanDigest.fromJson(
        json['plan_digest'] as Map<String, dynamic>? ?? const {},
      ),
      itemRecords: (json['item_records'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TrainingItemRecord.fromJson)
          .toList(growable: false),
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'plan_digest': planDigest.toJson(),
      'item_records': itemRecords
          .map((record) => record.toJson())
          .toList(growable: false),
      'completed': completed,
    };
  }
}

class SessionState {
  const SessionState({
    required this.planId,
    required this.currentIndex,
    required this.completedIndexes,
    required this.startedAtByIndex,
    required this.completedAtByIndex,
    required this.elapsedSecByIndex,
    required this.updatedAt,
    this.riskExpanded = false,
  });

  final String planId;
  final int currentIndex;
  final List<int> completedIndexes;
  final Map<int, DateTime> startedAtByIndex;
  final Map<int, DateTime> completedAtByIndex;
  final Map<int, int> elapsedSecByIndex;
  final DateTime updatedAt;
  final bool riskExpanded;

  factory SessionState.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String) {
        return null;
      }
      return DateTime.tryParse(value);
    }

    Map<int, DateTime> parseDateMap(dynamic value) {
      if (value is! Map<String, dynamic>) {
        return const {};
      }
      final result = <int, DateTime>{};
      for (final entry in value.entries) {
        final key = int.tryParse(entry.key);
        final date = parseDate(entry.value);
        if (key != null && date != null) {
          result[key] = date;
        }
      }
      return result;
    }

    Map<int, int> parseIntMap(dynamic value) {
      if (value is! Map<String, dynamic>) {
        return const {};
      }
      final result = <int, int>{};
      for (final entry in value.entries) {
        final key = int.tryParse(entry.key);
        final intValue = (entry.value as num?)?.toInt();
        if (key != null && intValue != null) {
          result[key] = intValue;
        }
      }
      return result;
    }

    return SessionState(
      planId: json['plan_id'] as String? ?? '',
      currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
      completedIndexes:
          (json['completed_indexes'] as List<dynamic>? ?? const [])
              .map((entry) => (entry as num?)?.toInt())
              .whereType<int>()
              .toList(growable: false),
      startedAtByIndex: parseDateMap(json['started_at_by_index']),
      completedAtByIndex: parseDateMap(json['completed_at_by_index']),
      elapsedSecByIndex: parseIntMap(json['elapsed_sec_by_index']),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      riskExpanded: json['risk_expanded'] as bool? ?? false,
    );
  }

  SessionState copyWith({
    int? currentIndex,
    List<int>? completedIndexes,
    Map<int, DateTime>? startedAtByIndex,
    Map<int, DateTime>? completedAtByIndex,
    Map<int, int>? elapsedSecByIndex,
    DateTime? updatedAt,
    bool? riskExpanded,
  }) {
    return SessionState(
      planId: planId,
      currentIndex: currentIndex ?? this.currentIndex,
      completedIndexes: completedIndexes ?? this.completedIndexes,
      startedAtByIndex: startedAtByIndex ?? this.startedAtByIndex,
      completedAtByIndex: completedAtByIndex ?? this.completedAtByIndex,
      elapsedSecByIndex: elapsedSecByIndex ?? this.elapsedSecByIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      riskExpanded: riskExpanded ?? this.riskExpanded,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> dateMap(Map<int, DateTime> source) {
      return source.map(
        (key, value) => MapEntry('$key', value.toIso8601String()),
      );
    }

    Map<String, dynamic> intMap(Map<int, int> source) {
      return source.map((key, value) => MapEntry('$key', value));
    }

    return {
      'plan_id': planId,
      'current_index': currentIndex,
      'completed_indexes': completedIndexes,
      'started_at_by_index': dateMap(startedAtByIndex),
      'completed_at_by_index': dateMap(completedAtByIndex),
      'elapsed_sec_by_index': intMap(elapsedSecByIndex),
      'updated_at': updatedAt.toIso8601String(),
      'risk_expanded': riskExpanded,
    };
  }
}

class HistoricalTrainingPlan {
  const HistoricalTrainingPlan({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.planVersion,
    required this.plan,
    this.profileSnapshot,
    this.isFavorite = false,
    this.lastTrainedAt,
    this.timesTrained = 0,
  });

  final String id;
  final DateTime createdAt;
  final String source;
  final String planVersion;
  final TrainingPlan plan;
  final UserProfile? profileSnapshot;
  final bool isFavorite;
  final DateTime? lastTrainedAt;
  final int timesTrained;

  factory HistoricalTrainingPlan.fromJson(Map<String, dynamic> json) {
    return HistoricalTrainingPlan(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      source: json['source'] as String? ?? 'generated',
      planVersion: json['plan_version'] as String? ?? '',
      plan: TrainingPlan.fromJson(json['plan'] as Map<String, dynamic>? ?? {}),
      profileSnapshot:
          (json['profile_snapshot'] as Map<String, dynamic>?) != null
          ? UserProfile.fromJson(
              json['profile_snapshot'] as Map<String, dynamic>,
            )
          : null,
      isFavorite: json['is_favorite'] as bool? ?? false,
      lastTrainedAt: DateTime.tryParse(
        json['last_trained_at'] as String? ?? '',
      ),
      timesTrained: (json['times_trained'] as num?)?.toInt() ?? 0,
    );
  }

  HistoricalTrainingPlan copyWith({
    bool? isFavorite,
    DateTime? lastTrainedAt,
    int? timesTrained,
  }) {
    return HistoricalTrainingPlan(
      id: id,
      createdAt: createdAt,
      source: source,
      planVersion: planVersion,
      plan: plan,
      profileSnapshot: profileSnapshot,
      isFavorite: isFavorite ?? this.isFavorite,
      lastTrainedAt: lastTrainedAt ?? this.lastTrainedAt,
      timesTrained: timesTrained ?? this.timesTrained,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'source': source,
      'plan_version': planVersion,
      'plan': plan.toJson(),
      'profile_snapshot': profileSnapshot?.toJson(),
      'is_favorite': isFavorite,
      'last_trained_at': lastTrainedAt?.toIso8601String(),
      'times_trained': timesTrained,
    };
  }
}

class SparkDayStatus {
  const SparkDayStatus({
    required this.date,
    required this.checkedIn,
    required this.isStreakDay,
  });

  final String date;
  final bool checkedIn;
  final bool isStreakDay;

  factory SparkDayStatus.fromJson(Map<String, dynamic> json) {
    return SparkDayStatus(
      date: json['date'] as String? ?? '',
      checkedIn: json['checked_in'] as bool? ?? false,
      isStreakDay: json['is_streak_day'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'checked_in': checkedIn,
      'is_streak_day': isStreakDay,
    };
  }
}

class AchievementState {
  const AchievementState({
    required this.currentStreakDays,
    required this.bestStreakDays,
    this.lastCheckinDate,
    required this.sparkTimeline,
  });

  final int currentStreakDays;
  final int bestStreakDays;
  final String? lastCheckinDate;
  final List<SparkDayStatus> sparkTimeline;

  factory AchievementState.empty() {
    return const AchievementState(
      currentStreakDays: 0,
      bestStreakDays: 0,
      sparkTimeline: [],
    );
  }

  factory AchievementState.fromJson(Map<String, dynamic> json) {
    return AchievementState(
      currentStreakDays: (json['current_streak_days'] as num?)?.toInt() ?? 0,
      bestStreakDays: (json['best_streak_days'] as num?)?.toInt() ?? 0,
      lastCheckinDate: json['last_checkin_date'] as String?,
      sparkTimeline: (json['spark_timeline'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SparkDayStatus.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak_days': currentStreakDays,
      'best_streak_days': bestStreakDays,
      'last_checkin_date': lastCheckinDate,
      'spark_timeline': sparkTimeline
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}

class ApiSettings {
  const ApiSettings({
    this.apiKey = '',
    this.primaryBaseUrl = 'https://codex-api.packycode.com/v1',
    this.fallbackBaseUrl = 'https://api.deepseek.com',
    this.preferredEndpoint = 'primary',
  });

  final String apiKey;
  final String primaryBaseUrl;
  final String fallbackBaseUrl;
  final String preferredEndpoint;

  factory ApiSettings.fromJson(Map<String, dynamic> json) {
    final endpoint = json['preferred_endpoint'] as String? ?? 'primary';
    return ApiSettings(
      apiKey: json['api_key'] as String? ?? '',
      primaryBaseUrl:
          json['primary_base_url'] as String? ??
          'https://codex-api.packycode.com/v1',
      fallbackBaseUrl:
          json['fallback_base_url'] as String? ?? 'https://api.deepseek.com',
      preferredEndpoint: endpoint == 'fallback' ? 'fallback' : 'primary',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_key': apiKey,
      'primary_base_url': primaryBaseUrl,
      'fallback_base_url': fallbackBaseUrl,
      'preferred_endpoint': preferredEndpoint,
    };
  }
}

class AppSnapshot {
  const AppSnapshot({
    required this.schemaVersion,
    required this.updatedAt,
    required this.userProfile,
    required this.latestPlan,
    required this.checkinHistory,
    required this.apiSettings,
    required this.planHistory,
    required this.achievementState,
    this.sessionState,
    this.generatedAt,
    this.planVersion,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime updatedAt;
  final UserProfile? userProfile;
  final TrainingPlan? latestPlan;
  final List<DailyCheckinRecord> checkinHistory;
  final ApiSettings apiSettings;
  final List<HistoricalTrainingPlan> planHistory;
  final AchievementState achievementState;
  final SessionState? sessionState;
  final DateTime? generatedAt;
  final String? planVersion;

  factory AppSnapshot.empty() {
    return AppSnapshot(
      schemaVersion: currentSchemaVersion,
      updatedAt: DateTime.now().toUtc(),
      userProfile: null,
      latestPlan: null,
      checkinHistory: const [],
      apiSettings: const ApiSettings(),
      planHistory: const [],
      achievementState: const AchievementState(
        currentStreakDays: 0,
        bestStreakDays: 0,
        sparkTimeline: [],
      ),
    );
  }

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    return AppSnapshot(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      userProfile: (json['user_profile'] as Map<String, dynamic>?) != null
          ? UserProfile.fromJson(json['user_profile'] as Map<String, dynamic>)
          : null,
      latestPlan: (json['latest_plan'] as Map<String, dynamic>?) != null
          ? TrainingPlan.fromJson(json['latest_plan'] as Map<String, dynamic>)
          : null,
      checkinHistory: (json['checkin_history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DailyCheckinRecord.fromJson)
          .toList(growable: false),
      apiSettings: (json['api_settings'] as Map<String, dynamic>?) != null
          ? ApiSettings.fromJson(json['api_settings'] as Map<String, dynamic>)
          : const ApiSettings(),
      planHistory: (json['plan_history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HistoricalTrainingPlan.fromJson)
          .toList(growable: false),
      achievementState:
          (json['achievement_state'] as Map<String, dynamic>?) != null
          ? AchievementState.fromJson(
              json['achievement_state'] as Map<String, dynamic>,
            )
          : AchievementState.empty(),
      sessionState: (json['session_state'] as Map<String, dynamic>?) != null
          ? SessionState.fromJson(json['session_state'] as Map<String, dynamic>)
          : null,
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
      planVersion: json['plan_version'] as String?,
    );
  }

  AppSnapshot copyWith({
    int? schemaVersion,
    DateTime? updatedAt,
    UserProfile? userProfile,
    bool clearUserProfile = false,
    TrainingPlan? latestPlan,
    bool clearLatestPlan = false,
    List<DailyCheckinRecord>? checkinHistory,
    ApiSettings? apiSettings,
    List<HistoricalTrainingPlan>? planHistory,
    AchievementState? achievementState,
    SessionState? sessionState,
    bool clearSessionState = false,
    DateTime? generatedAt,
    bool clearGeneratedAt = false,
    String? planVersion,
    bool clearPlanVersion = false,
  }) {
    return AppSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: clearUserProfile ? null : userProfile ?? this.userProfile,
      latestPlan: clearLatestPlan ? null : latestPlan ?? this.latestPlan,
      checkinHistory: checkinHistory ?? this.checkinHistory,
      apiSettings: apiSettings ?? this.apiSettings,
      planHistory: planHistory ?? this.planHistory,
      achievementState: achievementState ?? this.achievementState,
      sessionState: clearSessionState
          ? null
          : sessionState ?? this.sessionState,
      generatedAt: clearGeneratedAt ? null : generatedAt ?? this.generatedAt,
      planVersion: clearPlanVersion ? null : planVersion ?? this.planVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'updated_at': updatedAt.toIso8601String(),
      'user_profile': userProfile?.toJson(),
      'latest_plan': latestPlan?.toJson(),
      'checkin_history': checkinHistory
          .map((record) => record.toJson())
          .toList(growable: false),
      'api_settings': apiSettings.toJson(),
      'plan_history': planHistory
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'achievement_state': achievementState.toJson(),
      'session_state': sessionState?.toJson(),
      'generated_at': generatedAt?.toIso8601String(),
      'plan_version': planVersion,
    };
  }
}

String planVersionFromPlan(TrainingPlan plan) {
  final source = plan.toJson().toString();
  var hash = 5381;
  for (final unit in source.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return hash.toUnsigned(32).toRadixString(16);
}

String planHistoryId(DateTime createdAt, String planVersion) {
  final source = '${createdAt.toIso8601String()}#$planVersion';
  var hash = 5381;
  for (final unit in source.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return hash.toUnsigned(32).toRadixString(16);
}
