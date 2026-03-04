import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/training_models.dart';
import '../navigation/dashboard_tab_navigator.dart';
import '../services/local_snapshot_store.dart';
import '../services/voice_broadcast_service.dart';
import '../theme/dashboard_tokens.dart';
import '../widgets/animated_timer_button.dart';
import '../widgets/completion_feedback.dart';
import '../widgets/dashboard_bottom_tab_bar.dart';
import '../widgets/risk_banner.dart';

class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({
    super.key,
    required this.plan,
    this.planVersion,
    this.snapshotStore,
    this.voiceService,
    this.now,
  });

  final TrainingPlan plan;
  final String? planVersion;
  final LocalSnapshotStore? snapshotStore;
  final VoiceBroadcastService? voiceService;
  final DateTime Function()? now;

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  final _controller = PageController();
  final Set<int> _completedIndexes = <int>{};
  final Set<int> _quickActionBusyIndexes = <int>{};
  final Set<int> _runningTimerIndexes = <int>{};
  final Map<int, DateTime> _startedAtByIndex = <int, DateTime>{};
  final Map<int, DateTime> _completedAtByIndex = <int, DateTime>{};
  final Map<int, int> _elapsedSecByIndex = <int, int>{};

  late final String _planId;
  late final VoiceBroadcastService _voiceService;
  late final bool _ownsVoiceService;

  bool _restoring = true;
  bool _showFeedback = false;
  bool _riskExpanded = false;
  bool _autoAdvancing = false;
  bool _autoStartOnArrival = false;
  bool _currentTimerRunning = false;
  bool _manualAnnounceBusy = false;
  int _currentIndex = 0;
  int? _announcedIndex;
  int _milestoneMark = 0;
  int _timerAutoStartSignal = 0;
  Timer? _feedbackHideTimer;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _planId = widget.planVersion ?? planVersionFromPlan(widget.plan);
    _ownsVoiceService = widget.voiceService == null;
    _voiceService = widget.voiceService ?? FlutterTtsVoiceBroadcastService();
    _restoreSession();
  }

  @override
  void dispose() {
    _feedbackHideTimer?.cancel();
    if (_ownsVoiceService) {
      _voiceService.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final store = widget.snapshotStore;
    if (store == null) {
      if (mounted) {
        setState(() => _restoring = false);
      }
      return;
    }

    final snapshot = await store.load();
    final session = snapshot.sessionState;
    if (session != null && session.planId == _planId) {
      _currentIndex = session.currentIndex.clamp(
        0,
        widget.plan.items.length - 1,
      );
      _completedIndexes
        ..clear()
        ..addAll(
          session.completedIndexes.where((i) => i < widget.plan.items.length),
        );
      _startedAtByIndex
        ..clear()
        ..addAll(session.startedAtByIndex);
      _completedAtByIndex
        ..clear()
        ..addAll(session.completedAtByIndex);
      _elapsedSecByIndex
        ..clear()
        ..addAll(session.elapsedSecByIndex);
      _riskExpanded = session.riskExpanded;
    }

    if (!mounted) {
      return;
    }

    setState(() => _restoring = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.jumpToPage(_currentIndex);
    });
  }

  int _itemTargetSec(TrainingItem item) {
    return max(1, item.normalizedDurationSeconds);
  }

  int get _totalDurationSec {
    return widget.plan.items.fold<int>(
      0,
      (sum, item) => sum + _itemTargetSec(item),
    );
  }

  int get _elapsedDurationSec {
    var elapsed = 0;
    final items = widget.plan.items;
    for (var index = 0; index < items.length; index += 1) {
      final target = _itemTargetSec(items[index]);
      if (_completedIndexes.contains(index)) {
        elapsed += target;
        continue;
      }
      final currentElapsed = (_elapsedSecByIndex[index] ?? 0).clamp(0, target);
      elapsed += currentElapsed;
    }
    return elapsed;
  }

  int get _remainingDurationSec =>
      max(0, _totalDurationSec - _elapsedDurationSec);

  double get _completedRatio {
    if (widget.plan.items.isEmpty) {
      return 0;
    }
    return _completedIndexes.length / widget.plan.items.length;
  }

  String _dateKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes 分钟';
  }

  String _formatEstimatedFinishTime(int remainingSeconds) {
    final estimated = _now().add(Duration(seconds: remainingSeconds));
    final h = estimated.hour.toString().padLeft(2, '0');
    final m = estimated.minute.toString().padLeft(2, '0');
    return '预计完成 $h:$m';
  }

  String _formatItemVoiceMessage(int index) {
    final item = widget.plan.items[index];
    final typeText = item.type == 'rest' ? '休息环节' : '训练环节';
    return '第 ${index + 1} 项，$typeText。${item.effectiveTitle}。${item.instructions}。目标时长 ${_formatDuration(_itemTargetSec(item))}。';
  }

  Future<void> _announceItem(int index, {bool force = false}) async {
    if (!mounted || index < 0 || index >= widget.plan.items.length) {
      return;
    }
    if (!force && _announcedIndex == index) {
      return;
    }

    _announcedIndex = index;
    await _voiceService.speak(_formatItemVoiceMessage(index));
  }

  Future<void> _announceCurrentItem({bool force = false}) async {
    await _announceItem(_currentIndex, force: force);
  }

  Future<void> _replayCurrentGuidance() async {
    if (_manualAnnounceBusy) {
      return;
    }

    setState(() => _manualAnnounceBusy = true);
    try {
      await _announceCurrentItem(force: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重播当前动作语音指导')));
    } finally {
      if (mounted) {
        setState(() => _manualAnnounceBusy = false);
      }
    }
  }

  Future<void> _maybeSpeakMilestone() async {
    final ratio = _completedRatio;
    if (_milestoneMark < 1 && ratio >= 0.5) {
      _milestoneMark = 1;
      await _voiceService.speak('你已经完成一半训练，状态很棒，继续保持！');
      return;
    }

    if (_milestoneMark < 2 && ratio >= 0.8) {
      _milestoneMark = 2;
      await _voiceService.speak('接近完成了，再坚持一下就能打卡成功！');
    }
  }

  Future<void> _persistSessionState() async {
    final store = widget.snapshotStore;
    if (store == null) {
      return;
    }

    final state = SessionState(
      planId: _planId,
      currentIndex: _currentIndex,
      completedIndexes: _completedIndexes.toList(growable: false),
      startedAtByIndex: Map<int, DateTime>.from(_startedAtByIndex),
      completedAtByIndex: Map<int, DateTime>.from(_completedAtByIndex),
      elapsedSecByIndex: Map<int, int>.from(_elapsedSecByIndex),
      updatedAt: _now().toUtc(),
      riskExpanded: _riskExpanded,
    );
    await store.updateSessionState(state);
  }

  Future<void> _persistCheckin({required bool completed}) async {
    final store = widget.snapshotStore;
    if (store == null) {
      return;
    }

    final items = widget.plan.items;
    final dateKey = _dateKey(_now());
    final records = List<TrainingItemRecord>.generate(items.length, (index) {
      final item = items[index];
      return TrainingItemRecord(
        itemIndex: index,
        title: item.effectiveTitle,
        durationTargetSec: _itemTargetSec(item),
        startedAt: _startedAtByIndex[index],
        completedAt: _completedAtByIndex[index],
        actualElapsedSec: _elapsedSecByIndex[index] ?? 0,
      );
    }, growable: false);

    final digest = PlanDigest(
      itemCount: items.length,
      totalTargetSeconds: _totalDurationSec,
      restTargetSeconds: widget.plan.restDurationSeconds,
    );

    await store.appendOrUpdateCheckin(
      DailyCheckinRecord(
        date: dateKey,
        planDigest: digest,
        itemRecords: records,
        completed: completed,
      ),
    );
  }

  Future<void> _markStarted(int index) async {
    final firstStart = !_startedAtByIndex.containsKey(index);
    if (!firstStart) {
      return;
    }
    _startedAtByIndex[index] = _now();
    await _persistCheckin(completed: false);
    await _persistSessionState();
    await _announceItem(index, force: true);
  }

  Future<void> _markStepDone(int index) async {
    if (_completedIndexes.contains(index)) {
      return;
    }
    _completedAtByIndex[index] = _now();
    _elapsedSecByIndex[index] = _itemTargetSec(widget.plan.items[index]);

    setState(() {
      _completedIndexes.add(index);
      _showFeedback = true;
    });

    await _persistCheckin(completed: false);
    await _persistSessionState();

    await _voiceService.speak('第 ${index + 1} 项已完成，做得很好！');
    await _maybeSpeakMilestone();

    _feedbackHideTimer?.cancel();
    _feedbackHideTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() => _showFeedback = false);
    });

    if (index == _currentIndex) {
      await _goNext(autoStartAfterArrival: true);
    }
  }

  bool get _canMoveNext => _completedIndexes.contains(_currentIndex);
  bool get _hasProgress =>
      _startedAtByIndex.isNotEmpty || _completedIndexes.isNotEmpty;

  Future<bool> _confirmExitIfNeeded() async {
    if (!_hasProgress || _completedIndexes.length == widget.plan.items.length) {
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认结束本次训练？'),
          content: Text(
            '你已完成 ${_completedIndexes.length}/${widget.plan.items.length} 项，退出后可从首页继续。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续训练'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      await _voiceService.stop();
    }
    return shouldExit ?? false;
  }

  Future<void> _skipRestAndContinue(int index) async {
    if (_quickActionBusyIndexes.contains(index) ||
        _completedIndexes.contains(index)) {
      return;
    }

    setState(() => _quickActionBusyIndexes.add(index));
    try {
      await _markStarted(index);
      await _markStepDone(index);
    } finally {
      if (mounted) {
        setState(() => _quickActionBusyIndexes.remove(index));
      }
    }
  }

  Future<void> _goNext({bool autoStartAfterArrival = false}) async {
    if (!_canMoveNext || _autoAdvancing) {
      return;
    }

    final isLast = _currentIndex == widget.plan.items.length - 1;
    if (isLast) {
      await _persistCheckin(completed: true);
      await widget.snapshotStore?.clearSessionState();
      await _voiceService.speak('今天训练全部完成，恭喜你打卡成功！');
      if (!mounted) {
        return;
      }
      _showFinishDialog();
      return;
    }

    setState(() => _autoAdvancing = true);
    _autoStartOnArrival = autoStartAfterArrival;
    try {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        setState(() => _autoAdvancing = false);
      }
    }
  }

  void _showFinishDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('今日打卡完成'),
          content: const Text('你已完成全部训练，继续保持！'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                DashboardTabNavigator.goToTabRoot(
                  this.context,
                  tab: DashboardTab.home,
                  snapshotStore: widget.snapshotStore,
                );
              },
              child: const Text('返回首页'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onBottomTabChanged(DashboardTab tab) async {
    if (_currentTimerRunning) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前计时进行中，请先暂停或完成本项')));
      return;
    }

    final shouldExit = await _confirmExitIfNeeded();
    if (!shouldExit || !mounted) {
      return;
    }

    DashboardTabNavigator.goToTabRoot(
      context,
      tab: tab,
      snapshotStore: widget.snapshotStore,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = widget.plan.items;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await _confirmExitIfNeeded();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _SessionColors.pageBackground,
        appBar: AppBar(
          title: const Text('今日训练打卡'),
          backgroundColor: _SessionColors.surface,
          foregroundColor: _SessionColors.textPrimary,
          elevation: 0,
        ),
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _SessionColors.surface,
                        borderRadius: BorderRadius.circular(
                          DashboardTokens.cardRadius,
                        ),
                      ),
                      child: RiskBanner(
                        warning: widget.plan.warning,
                        expanded: _riskExpanded,
                        onToggle: () async {
                          setState(() => _riskExpanded = !_riskExpanded);
                          await _persistSessionState();
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _SessionColors.surface,
                        borderRadius: BorderRadius.circular(
                          DashboardTokens.cardRadius,
                        ),
                      ),
                      child: _ProgressCheckpoints(
                        total: items.length,
                        currentIndex: _currentIndex,
                        completed: _completedIndexes,
                        completedDurationSec: _elapsedDurationSec,
                        totalDurationSec: _totalDurationSec,
                        remainingDurationSec: _remainingDurationSec,
                        estimatedFinishText: _formatEstimatedFinishTime(
                          _remainingDurationSec,
                        ),
                        formatDuration: _formatDuration,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: items.length,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) async {
                        setState(() {
                          _currentIndex = index;
                          _showFeedback = false;
                          _currentTimerRunning = _runningTimerIndexes.contains(
                            index,
                          );
                        });
                        await _persistSessionState();
                        await _announceCurrentItem(force: true);
                        if (_autoStartOnArrival && mounted) {
                          setState(() {
                            _autoStartOnArrival = false;
                            _timerAutoStartSignal += 1;
                          });
                        }
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isRest = item.type == 'rest';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _SessionColors.surface,
                              borderRadius: BorderRadius.circular(
                                DashboardTokens.cardRadius,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Text(
                                    '第 ${index + 1} 项',
                                    style: const TextStyle(
                                      color: _SessionColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.effectiveTitle,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: _SessionColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isRest
                                        ? '类型：休息'
                                        : '强度：${item.intensity}  |  器材：${item.equipment}',
                                    style: const TextStyle(
                                      color: _SessionColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    item.instructions,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _SessionColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '时长：${_formatDuration(_itemTargetSec(item))}',
                                    style: const TextStyle(
                                      color: _SessionColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _NextStepHint(
                                    currentIndex: index,
                                    items: items,
                                    formatDuration: _formatDuration,
                                    itemTargetSec: _itemTargetSec,
                                  ),
                                  const SizedBox(height: 24),
                                  OutlinedButton.icon(
                                    onPressed: _manualAnnounceBusy
                                        ? null
                                        : _replayCurrentGuidance,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(44),
                                      side: const BorderSide(
                                        color: DashboardTokens.outline,
                                      ),
                                      foregroundColor: _SessionColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
                                      ),
                                    ),
                                    icon: _manualAnnounceBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.volume_up_outlined),
                                    label: const Text('重播语音指导'),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedTimerButton(
                                    key: ValueKey('timer-$index'),
                                    duration: Duration(
                                      seconds: _itemTargetSec(item),
                                    ),
                                    autoStartSignal: index == _currentIndex
                                        ? _timerAutoStartSignal
                                        : 0,
                                    onCompleted: () => _markStepDone(index),
                                    onTick: (remainingSeconds) {
                                      if (!mounted ||
                                          _completedIndexes.contains(index)) {
                                        return;
                                      }
                                      final target = _itemTargetSec(item);
                                      final elapsed =
                                          (target - remainingSeconds).clamp(
                                            0,
                                            target,
                                          );
                                      setState(() {
                                        _elapsedSecByIndex[index] = elapsed;
                                      });
                                    },
                                    onStatusChanged: (status) {
                                      if (!mounted) {
                                        return;
                                      }
                                      final runningNow =
                                          status == TimerButtonStatus.running;
                                      if (status == TimerButtonStatus.running) {
                                        _markStarted(index);
                                      }
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted) {
                                              return;
                                            }
                                            setState(() {
                                              if (runningNow) {
                                                _runningTimerIndexes.add(index);
                                              } else {
                                                _runningTimerIndexes.remove(
                                                  index,
                                                );
                                              }

                                              if (index == _currentIndex) {
                                                _currentTimerRunning =
                                                    runningNow;
                                              }

                                              if (status ==
                                                  TimerButtonStatus.idle) {
                                                _showFeedback = false;
                                                if (!_completedIndexes.contains(
                                                  index,
                                                )) {
                                                  _elapsedSecByIndex[index] = 0;
                                                }
                                              }
                                            });
                                          });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _completedIndexes.contains(index)
                                        ? '本项已达成，可进入下一项'
                                        : '完成计时后才可进入下一项',
                                    style: TextStyle(
                                      color: _completedIndexes.contains(index)
                                          ? _SessionColors.success
                                          : _SessionColors.warning,
                                    ),
                                  ),
                                  if (isRest &&
                                      !_completedIndexes.contains(index)) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed:
                                          _quickActionBusyIndexes.contains(
                                            index,
                                          )
                                          ? null
                                          : () => _skipRestAndContinue(index),
                                      icon:
                                          _quickActionBusyIndexes.contains(
                                            index,
                                          )
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.skip_next),
                                      label: const Text('跳过休息并进入下一项'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _currentIndex == 0 || _currentTimerRunning
                                ? null
                                : () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                  ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: _SessionColors.surface,
                              foregroundColor: _SessionColors.textPrimary,
                              side: const BorderSide(
                                color: DashboardTokens.outline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
                              ),
                            ),
                            child: const Text('上一项'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _canMoveNext && !_autoAdvancing
                                ? _goNext
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: _SessionColors.accent,
                              foregroundColor: _SessionColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
                              ),
                            ),
                            child: Text(
                              _currentIndex == items.length - 1
                                  ? '完成训练'
                                  : '下一项',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentTimerRunning)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        '当前计时进行中，先暂停或完成本项再切换动作。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _SessionColors.warning),
                      ),
                    ),
                ],
              ),
              CompletionFeedback(visible: _showFeedback),
            ],
          ),
        ),
        bottomNavigationBar: DashboardBottomTabBar(
          selectedTab: DashboardTab.plan,
          onTabChanged: (tab) => _onBottomTabChanged(tab),
        ),
      ),
    );
  }
}

class _ProgressCheckpoints extends StatelessWidget {
  const _ProgressCheckpoints({
    required this.total,
    required this.currentIndex,
    required this.completed,
    required this.completedDurationSec,
    required this.totalDurationSec,
    required this.remainingDurationSec,
    required this.estimatedFinishText,
    required this.formatDuration,
  });

  final int total;
  final int currentIndex;
  final Set<int> completed;
  final int completedDurationSec;
  final int totalDurationSec;
  final int remainingDurationSec;
  final String estimatedFinishText;
  final String Function(int seconds) formatDuration;

  @override
  Widget build(BuildContext context) {
    final progress = totalDurationSec == 0
        ? 0.0
        : completedDurationSec / totalDurationSec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: DashboardTokens.neutralSoft,
            color: _SessionColors.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '进度：${completed.length}/$total · ${formatDuration(completedDurationSec)} / ${formatDuration(totalDurationSec)} · 剩余 ${formatDuration(remainingDurationSec)}',
          style: const TextStyle(color: _SessionColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          estimatedFinishText,
          style: const TextStyle(
            color: _SessionColors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List<Widget>.generate(total, (index) {
            final isDone = completed.contains(index);
            final isCurrent = index == currentIndex;
            final background = isDone
                ? _SessionColors.success
                : isCurrent
                ? _SessionColors.accent
                : DashboardTokens.neutralFaint;
            return Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDone || isCurrent
                      ? DashboardTokens.surface
                      : _SessionColors.textMuted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _NextStepHint extends StatelessWidget {
  const _NextStepHint({
    required this.currentIndex,
    required this.items,
    required this.formatDuration,
    required this.itemTargetSec,
  });

  final int currentIndex;
  final List<TrainingItem> items;
  final String Function(int seconds) formatDuration;
  final int Function(TrainingItem item) itemTargetSec;

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= items.length - 1) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _SessionColors.successSoft,
          borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: _SessionColors.success,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前是最后一项，完成后即可打卡成功。',
                  style: TextStyle(color: _SessionColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final next = items[currentIndex + 1];
    final nextType = next.type == 'rest' ? '休息' : '训练';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SessionColors.warningSoft,
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 18,
              color: _SessionColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '下一项：${next.effectiveTitle}（$nextType，${formatDuration(itemTargetSec(next))}）',
                style: const TextStyle(color: _SessionColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionColors {
  static const pageBackground = DashboardTokens.pageBackground;
  static const surface = DashboardTokens.surface;
  static const accent = DashboardTokens.accent;
  static const successSoft = DashboardTokens.successSoft;
  static const warningSoft = DashboardTokens.warningSoft;
  static const success = DashboardTokens.success;
  static const warning = DashboardTokens.warning;
  static const textPrimary = DashboardTokens.textPrimary;
  static const textSecondary = DashboardTokens.textSecondary;
  static const textMuted = DashboardTokens.textMuted;
}
