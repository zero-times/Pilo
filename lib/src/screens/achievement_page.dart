import 'package:flutter/material.dart';

import '../models/training_models.dart';
import '../navigation/dashboard_tab_navigator.dart';
import '../services/local_snapshot_store.dart';
import '../theme/dashboard_tokens.dart';
import '../widgets/dashboard_bottom_tab_bar.dart';

class AchievementPage extends StatelessWidget {
  const AchievementPage({
    super.key,
    required this.achievementState,
    this.snapshotStore,
  });

  final AchievementState achievementState;
  final LocalSnapshotStore? snapshotStore;

  @override
  Widget build(BuildContext context) {
    final timeline = achievementState.sparkTimeline;
    return Scaffold(
      backgroundColor: DashboardTokens.pageBackground,
      appBar: AppBar(
        title: const Text('打卡成就'),
        backgroundColor: DashboardTokens.surface,
        foregroundColor: DashboardTokens.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
                gradient: DashboardTokens.accentGradient,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: 8),
                  Text(
                    '连续 ${achievementState.currentStreakDays} 天',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DashboardTokens.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '历史最佳 ${achievementState.bestStreakDays} 天',
                    style: const TextStyle(
                      color: DashboardTokens.surface,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashboardTokens.surface,
                borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '最近30天火花',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeline
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
                              child: const Center(
                                child: Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: DashboardTokens.surface,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashboardTokens.surface,
                borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
              ),
              child: const Row(
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => DashboardTabNavigator.goToTabRoot(
                  context,
                  tab: DashboardTab.home,
                  snapshotStore: snapshotStore,
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
      ),
      bottomNavigationBar: DashboardBottomTabBar(
        selectedTab: DashboardTab.stats,
        onTabChanged: (tab) => DashboardTabNavigator.goToTabRoot(
          context,
          tab: tab,
          snapshotStore: snapshotStore,
        ),
      ),
    );
  }
}
