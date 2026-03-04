enum StatsRange { days7, days30, days90 }

extension StatsRangeX on StatsRange {
  int get days {
    switch (this) {
      case StatsRange.days7:
        return 7;
      case StatsRange.days30:
        return 30;
      case StatsRange.days90:
        return 90;
    }
  }

  String get label {
    switch (this) {
      case StatsRange.days7:
        return '7天';
      case StatsRange.days30:
        return '30天';
      case StatsRange.days90:
        return '90天';
    }
  }
}

enum WorkoutItemStatus { completed, active, pending }

class DashboardWorkoutItemData {
  const DashboardWorkoutItemData({
    required this.title,
    required this.meta,
    required this.status,
  });

  final String title;
  final String meta;
  final WorkoutItemStatus status;
}

class RecoveryMetricData {
  const RecoveryMetricData({
    required this.label,
    required this.valueText,
    required this.progress,
    this.estimated = false,
  });

  final String label;
  final String valueText;
  final double progress;
  final bool estimated;
}

class HomeViewData {
  const HomeViewData({
    required this.progressText,
    required this.progressRatio,
    required this.streakDays,
    required this.estimatedKcal,
    required this.items,
  });

  final String progressText;
  final double progressRatio;
  final int streakDays;
  final int estimatedKcal;
  final List<DashboardWorkoutItemData> items;
}

class PlanViewData {
  const PlanViewData({
    required this.todayItems,
    required this.recoveryMetrics,
  });

  final List<DashboardWorkoutItemData> todayItems;
  final List<RecoveryMetricData> recoveryMetrics;
}

class StatsMetricData {
  const StatsMetricData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class StatsTrendBarData {
  const StatsTrendBarData({
    required this.label,
    required this.minutes,
  });

  final String label;
  final int minutes;
}

class StatsViewData {
  const StatsViewData({
    required this.completionRate,
    required this.streakDays,
    required this.totalMinutes,
    required this.estimatedKcal,
    required this.metrics,
    required this.trendBars,
    required this.habitRank,
  });

  final int completionRate;
  final int streakDays;
  final int totalMinutes;
  final int estimatedKcal;
  final List<StatsMetricData> metrics;
  final List<StatsTrendBarData> trendBars;
  final List<MapEntry<String, int>> habitRank;
}

class ProfileViewData {
  const ProfileViewData({
    required this.displayName,
    required this.badgeText,
    required this.meta,
    required this.goalText,
    required this.reminderText,
    required this.unitText,
  });

  final String displayName;
  final String badgeText;
  final String meta;
  final String goalText;
  final String reminderText;
  final String unitText;
}
