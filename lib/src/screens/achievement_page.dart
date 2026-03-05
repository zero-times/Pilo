import 'package:flutter/material.dart';

import '../models/training_models.dart';
import '../navigation/dashboard_tab_navigator.dart';
import '../services/local_snapshot_store.dart';
import '../theme/dashboard_tokens.dart';
import '../widgets/dashboard_page_header.dart';
import '../widgets/dashboard_segmented_tab_selector.dart';
import '../widgets/dashboard_surface_card.dart';
import '../widgets/dashboard_tab_page_scaffold.dart';

class AchievementPage extends StatefulWidget {
  const AchievementPage({
    super.key,
    required this.achievementState,
    this.snapshotStore,
  });

  final AchievementState achievementState;
  final LocalSnapshotStore? snapshotStore;

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

enum _AchievementRange { days7, days14, days30 }

class _AchievementPageState extends State<AchievementPage> {
  _AchievementRange _range = _AchievementRange.days30;

  int get _rangeDays {
    switch (_range) {
      case _AchievementRange.days7:
        return 7;
      case _AchievementRange.days14:
        return 14;
      case _AchievementRange.days30:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = widget.achievementState.sparkTimeline;
    final rangeDays = _rangeDays;
    final filteredTimeline = timeline.length <= rangeDays
        ? timeline
        : timeline.sublist(timeline.length - rangeDays);
    final checkedInDays = filteredTimeline
        .where((entry) => entry.checkedIn)
        .length;
    final streakDays = filteredTimeline
        .where((entry) => entry.isStreakDay)
        .length;
    final completionRate = filteredTimeline.isEmpty
        ? 0
        : ((checkedInDays / filteredTimeline.length) * 100).round();
    return DashboardTabPageScaffold(
      title: '打卡成就',
      showAppBar: false,
      selectedTab: DashboardTab.stats,
      snapshotStore: widget.snapshotStore,
      allowReselectCurrentTab: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          const DashboardPageHeader(
            title: '打卡成就',
            subtitle: '查看连续打卡与近 30 天活跃状态。',
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: DashboardSegmentedTabSelector<_AchievementRange>(
              items: const [
                DashboardSegmentedTabItem<_AchievementRange>(
                  value: _AchievementRange.days7,
                  label: '近 7 天',
                  icon: Icons.looks_one_rounded,
                ),
                DashboardSegmentedTabItem<_AchievementRange>(
                  value: _AchievementRange.days14,
                  label: '近 14 天',
                  icon: Icons.looks_two_rounded,
                ),
                DashboardSegmentedTabItem<_AchievementRange>(
                  value: _AchievementRange.days30,
                  label: '近 30 天',
                  icon: Icons.looks_3_rounded,
                ),
              ],
              selectedValue: _range,
              onChanged: (value) => setState(() => _range = value),
            ),
          ),
          const SizedBox(height: 10),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DashboardTokens.accentSoft,
                    borderRadius: BorderRadius.circular(29),
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 10),
                Text(
                  '连续 ${widget.achievementState.currentStreakDays} 天',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: DashboardTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '历史最佳 ${widget.achievementState.bestStreakDays} 天',
                  style: const TextStyle(
                    color: DashboardTokens.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AchievementMetricTile(
                  label: '近$rangeDays天打卡',
                  value: '$checkedInDays 天',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AchievementMetricTile(
                  label: '连击标记',
                  value: '$streakDays 天',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AchievementMetricTile(
                  label: '完成率',
                  value: '$completionRate%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DashboardSurfaceCard(
            outlined: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近$rangeDays天火花',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    _LegendDot(color: DashboardTokens.accent, label: '已打卡'),
                    SizedBox(width: 12),
                    _LegendDot(color: DashboardTokens.neutralSoft, label: '未打卡'),
                  ],
                ),
                const SizedBox(height: 10),
                if (filteredTimeline.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: DashboardTokens.warningSoft,
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                    child: const Text(
                      '暂无打卡记录，完成一次训练后这里会展示火花轨迹。',
                      style: TextStyle(color: DashboardTokens.textSecondary),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredTimeline
                        .map((entry) {
                          final color = entry.checkedIn
                              ? DashboardTokens.accent
                              : DashboardTokens.neutralSoft;
                          return Tooltip(
                            message:
                                '${entry.date} ${entry.checkedIn ? '已打卡' : '未打卡'}',
                            child: Container(
                              key: Key(
                                'spark-${entry.date}-${entry.checkedIn ? 'on' : 'off'}',
                              ),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: entry.isStreakDay
                                    ? Border.all(
                                        color: DashboardTokens.accentSoft,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: entry.checkedIn
                                      ? DashboardTokens.surface
                                      : DashboardTokens.textMuted,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const DashboardSurfaceCard(
            outlined: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: DashboardTokens.textMuted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '若当天未完成打卡，连续天数将从次日重新计算。',
                    style: TextStyle(
                      fontSize: 13,
                      color: DashboardTokens.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => DashboardTabNavigator.goToTabRoot(
                    context,
                    tab: DashboardTab.plan,
                    snapshotStore: widget.snapshotStore,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: DashboardTokens.textPrimary,
                    side: const BorderSide(color: DashboardTokens.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('查看计划记录'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => DashboardTabNavigator.goToTabRoot(
                    context,
                    tab: DashboardTab.home,
                    snapshotStore: widget.snapshotStore,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: DashboardTokens.accent,
                    foregroundColor: DashboardTokens.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    '返回首页',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementMetricTile extends StatelessWidget {
  const _AchievementMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      outlined: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: DashboardTokens.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DashboardTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: DashboardTokens.textMuted,
          ),
        ),
      ],
    );
  }
}
