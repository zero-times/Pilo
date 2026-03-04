import 'package:flutter/material.dart';

import '../models/training_models.dart';
import '../navigation/dashboard_tab_navigator.dart';
import '../services/local_snapshot_store.dart';
import '../theme/dashboard_tokens.dart';
import '../widgets/dashboard_bottom_tab_bar.dart';
import 'training_session_page.dart';

class PlanHistoryPage extends StatefulWidget {
  const PlanHistoryPage({
    super.key,
    required this.snapshotStore,
    this.initialFilter = PlanHistoryFilter.favorites,
    this.now,
  });

  final LocalSnapshotStore snapshotStore;
  final PlanHistoryFilter initialFilter;
  final DateTime Function()? now;

  @override
  State<PlanHistoryPage> createState() => _PlanHistoryPageState();
}

enum PlanHistoryFilter { favorites, history }

class _PlanHistoryPageState extends State<PlanHistoryPage> {
  bool _loading = true;
  PlanHistoryFilter _filter = PlanHistoryFilter.favorites;
  List<HistoricalTrainingPlan> _plans = const [];
  final Set<String> _favoritePendingIds = <String>{};
  String? _startingPlanId;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await widget.snapshotStore.loadPlanHistory();
    if (!mounted) {
      return;
    }
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  List<HistoricalTrainingPlan> get _filteredPlans {
    if (_filter == PlanHistoryFilter.history) {
      return _plans;
    }
    return _plans.where((plan) => plan.isFavorite).toList(growable: false);
  }

  Future<void> _toggleFavorite(HistoricalTrainingPlan plan) async {
    if (_favoritePendingIds.contains(plan.id)) {
      return;
    }
    setState(() => _favoritePendingIds.add(plan.id));
    final next = !plan.isFavorite;
    try {
      await widget.snapshotStore.toggleFavoritePlan(plan.id, next);
      await _loadPlans();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next ? '已加入收藏' : '已取消收藏')));
    } finally {
      if (mounted) {
        setState(() => _favoritePendingIds.remove(plan.id));
      } else {
        _favoritePendingIds.remove(plan.id);
      }
    }
  }

  Future<void> _startTraining(HistoricalTrainingPlan plan) async {
    if (_startingPlanId != null) {
      return;
    }
    setState(() => _startingPlanId = plan.id);
    try {
      await widget.snapshotStore.markPlanTrained(plan.id, _now());
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrainingSessionPage(
            plan: plan.plan,
            planVersion: plan.planVersion,
            snapshotStore: widget.snapshotStore,
          ),
        ),
      );
      await _loadPlans();
    } finally {
      if (mounted) {
        setState(() => _startingPlanId = null);
      } else {
        _startingPlanId = null;
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes 分钟';
  }

  String _formatLocalDateTime(DateTime value) {
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final plans = _filteredPlans;
    return Scaffold(
      backgroundColor: DashboardTokens.pageBackground,
      appBar: AppBar(
        title: const Text('历史训练计划'),
        backgroundColor: DashboardTokens.surface,
        foregroundColor: DashboardTokens.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DashboardTokens.surface,
                  borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
                ),
                child: SegmentedButton<PlanHistoryFilter>(
                  segments: const [
                    ButtonSegment<PlanHistoryFilter>(
                      value: PlanHistoryFilter.favorites,
                      label: Text('收藏'),
                    ),
                    ButtonSegment<PlanHistoryFilter>(
                      value: PlanHistoryFilter.history,
                      label: Text('历史'),
                    ),
                  ],
                  selected: {_filter},
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: DashboardTokens.accent,
                    selectedForegroundColor: DashboardTokens.surface,
                    foregroundColor: DashboardTokens.textSecondary,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onSelectionChanged: (selection) {
                    final first = selection.isEmpty ? null : selection.first;
                    if (first == null) {
                      return;
                    }
                    setState(() => _filter = first);
                  },
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : plans.isEmpty
                  ? _buildEmptyState(
                      icon: _filter == PlanHistoryFilter.favorites
                          ? Icons.star_border
                          : Icons.history,
                      message: _filter == PlanHistoryFilter.favorites
                          ? '暂无收藏计划，先在历史里收藏一个吧。'
                          : '暂无历史计划，先生成并完成训练计划。',
                      actionLabel: _filter == PlanHistoryFilter.favorites
                          ? '切到历史'
                          : '去生成计划',
                      onAction: _filter == PlanHistoryFilter.favorites
                          ? () => setState(
                              () => _filter = PlanHistoryFilter.history,
                            )
                          : () => DashboardTabNavigator.goToTabRoot(
                              context,
                              tab: DashboardTab.home,
                              snapshotStore: widget.snapshotStore,
                            ),
                    )
                  : ListView.builder(
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        final isFavoritePending = _favoritePendingIds.contains(
                          plan.id,
                        );
                        final isStarting = _startingPlanId == plan.id;
                        final totalSec = plan.plan.totalDurationSeconds;
                        final title = plan.plan.items.isEmpty
                            ? '未命名计划'
                            : plan.plan.items.first.effectiveTitle;
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DashboardTokens.surface,
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.cardRadius,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: plan.isFavorite ? '取消收藏' : '收藏',
                                    onPressed: isFavoritePending
                                        ? null
                                        : () => _toggleFavorite(plan),
                                    icon: Icon(
                                      plan.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: plan.isFavorite
                                          ? DashboardTokens.warning
                                          : DashboardTokens.iconDisabled,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '总时长 ${_formatDuration(totalSec)}（含休息 ${_formatDuration(plan.plan.restDurationSeconds)}）',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DashboardTokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '共 ${plan.plan.items.length} 项 · 生成于 ${_formatLocalDateTime(plan.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DashboardTokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '训练次数 ${plan.timesTrained}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DashboardTokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: isStarting
                                      ? null
                                      : () => _startTraining(plan),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    backgroundColor: DashboardTokens.accent,
                                    foregroundColor: DashboardTokens.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DashboardTokens.buttonRadius,
                                      ),
                                    ),
                                  ),
                                  child: isStarting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('开始训练'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DashboardBottomTabBar(
        selectedTab: DashboardTab.plan,
        onTabChanged: (tab) => DashboardTabNavigator.goToTabRoot(
          context,
          tab: tab,
          snapshotStore: widget.snapshotStore,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: DashboardTokens.surface,
            borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: DashboardTokens.iconDisabled),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: DashboardTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 44),
                    backgroundColor: DashboardTokens.accent,
                    foregroundColor: DashboardTokens.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
