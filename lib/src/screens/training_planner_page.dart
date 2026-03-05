import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_models.dart';
import '../services/deepseek_service.dart';
import '../services/local_snapshot_store.dart';
import '../services/snapshot_portability_service.dart';
import '../theme/dashboard_tokens.dart';
import '../widgets/dashboard_page_header.dart';
import '../widgets/dashboard_segmented_tab_selector.dart';
import '../widgets/dashboard_snack_bar.dart';
import '../widgets/dashboard_surface_card.dart';
import '../widgets/dashboard_tab_page_scaffold.dart';
import 'achievement_page.dart';
import 'dashboard_view_data.dart';
import 'plan_history_page.dart';
import 'training_session_page.dart';

class TrainingPlannerPage extends StatefulWidget {
  const TrainingPlannerPage({
    super.key,
    this.deepSeekService,
    this.snapshotStore,
    this.portabilityService,
    this.initialTabIndex = 0,
  });

  final DeepSeekService? deepSeekService;
  final LocalSnapshotStore? snapshotStore;
  final SnapshotPortabilityService? portabilityService;
  final int initialTabIndex;

  @override
  State<TrainingPlannerPage> createState() => _TrainingPlannerPageState();
}

class _TrainingPlannerPageState extends State<TrainingPlannerPage> {
  final _formKey = GlobalKey<FormState>();
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '65');
  final _minutesCtrl = TextEditingController(text: '30');
  final _equipmentsCtrl = TextEditingController(text: '瑜伽垫,哑铃');
  final _goalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _historyTrainingCtrl = TextEditingController();
  final _systolicCtrl = TextEditingController(text: '120');
  final _diastolicCtrl = TextEditingController(text: '80');
  final _historyWeightsCtrl = TextEditingController();
  final _historyBpCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _primaryBaseUrlCtrl = TextEditingController();
  final _fallbackBaseUrlCtrl = TextEditingController();

  bool _hasDisease = false;
  bool _hydrating = true;
  bool _loading = false;
  String _gender = 'unknown';
  String _preferredEndpoint = 'primary';
  String? _error;
  TrainingPlan? _plan;
  String? _planVersion;
  int _planHistoryCount = 0;
  AppSnapshot _snapshot = AppSnapshot.empty();
  AchievementState _achievementState = AchievementState.empty();
  _PendingSessionEntry? _pendingSession;
  int _currentTabIndex = 0;
  StatsRange _statsRange = StatsRange.days7;

  DeepSeekService? _service;
  late final bool _ownsService;
  late final LocalSnapshotStore _snapshotStore;
  late final SnapshotPortabilityService _portabilityService;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex.clamp(0, 3);
    _ownsService = widget.deepSeekService == null;
    _service = widget.deepSeekService;
    _snapshotStore = widget.snapshotStore ?? LocalSnapshotStore();
    _portabilityService =
        widget.portabilityService ??
        SnapshotPortabilityService(snapshotStore: _snapshotStore);
    _restoreFromSnapshot();
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service?.dispose();
    }
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _minutesCtrl.dispose();
    _equipmentsCtrl.dispose();
    _goalCtrl.dispose();
    _notesCtrl.dispose();
    _historyTrainingCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _historyWeightsCtrl.dispose();
    _historyBpCtrl.dispose();
    _apiKeyCtrl.dispose();
    _primaryBaseUrlCtrl.dispose();
    _fallbackBaseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreFromSnapshot() async {
    var snapshot = await _snapshotStore.load();
    if (snapshot.checkinHistory.isNotEmpty &&
        snapshot.achievementState.sparkTimeline.isEmpty) {
      final rebuilt = await _snapshotStore
          .rebuildAchievementStateFromCheckins();
      snapshot = snapshot.copyWith(achievementState: rebuilt);
    }
    if (!mounted) {
      return;
    }

    _applyProfileToControllers(snapshot.userProfile);
    _apiKeyCtrl.text = snapshot.apiSettings.apiKey;
    _primaryBaseUrlCtrl.text = snapshot.apiSettings.primaryBaseUrl;
    _fallbackBaseUrlCtrl.text = snapshot.apiSettings.fallbackBaseUrl;
    _preferredEndpoint = snapshot.apiSettings.preferredEndpoint;

    setState(() {
      _snapshot = snapshot;
      _plan = snapshot.latestPlan;
      _planVersion = snapshot.planVersion;
      _planHistoryCount = snapshot.planHistory.length;
      _achievementState = snapshot.achievementState;
      _pendingSession = _resolvePendingSession(snapshot);
      _hydrating = false;
    });
  }

  void _applyProfileToControllers(UserProfile? profile) {
    if (profile != null) {
      _heightCtrl.text = _formatDouble(profile.heightCm);
      _weightCtrl.text = _formatDouble(profile.weightKg);
      _minutesCtrl.text = profile.exerciseMinutes.toString();
      _equipmentsCtrl.text = profile.equipments.join(',');
      _goalCtrl.text = profile.goal;
      _notesCtrl.text = profile.notes;
      _historyTrainingCtrl.text = profile.trainingHistorySummary;
      _hasDisease = profile.hasDisease;
      _gender = _normalizeGender(profile.gender);
      return;
    }

    _heightCtrl.text = '170';
    _weightCtrl.text = '65';
    _minutesCtrl.text = '30';
    _equipmentsCtrl.text = '瑜伽垫,哑铃';
    _goalCtrl.clear();
    _notesCtrl.clear();
    _historyTrainingCtrl.clear();
    _hasDisease = false;
    _gender = 'unknown';
  }

  String _normalizeGender(String? value) {
    switch (value) {
      case 'male':
      case 'female':
      case 'other':
      case 'unknown':
        return value!;
      default:
        return 'unknown';
    }
  }

  UserProfile _buildProfileDraftForSettings() {
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 170;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 65;
    final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? 30;
    return UserProfile(
      heightCm: height,
      weightKg: weight,
      hasDisease: _hasDisease,
      exerciseMinutes: minutes,
      equipments: _parseEquipmentList(_equipmentsCtrl.text),
      gender: _gender,
      goal: _goalCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      trainingHistorySummary: _historyTrainingCtrl.text.trim(),
      targetMinutesIncludesRest: true,
    );
  }

  _PendingSessionEntry? _resolvePendingSession(AppSnapshot snapshot) {
    final session = snapshot.sessionState;
    if (session == null || session.planId.isEmpty) {
      return null;
    }
    if (snapshot.planVersion == session.planId && snapshot.latestPlan != null) {
      return _PendingSessionEntry(
        plan: snapshot.latestPlan!,
        planVersion: session.planId,
        currentIndex: session.currentIndex,
        completedCount: session.completedIndexes.length,
      );
    }

    final matchedHistory = snapshot.planHistory
        .where((entry) => entry.planVersion == session.planId)
        .toList(growable: false);
    if (matchedHistory.isEmpty) {
      return null;
    }
    final latest = matchedHistory.first;
    return _PendingSessionEntry(
      plan: latest.plan,
      planVersion: latest.planVersion,
      currentIndex: session.currentIndex,
      completedCount: session.completedIndexes.length,
    );
  }

  Future<void> _openApiSettingsPage() async {
    if (!mounted) {
      return;
    }
    final settings = ApiSettings(
      apiKey: _apiKeyCtrl.text.trim(),
      primaryBaseUrl: _normalizeUrl(
        _primaryBaseUrlCtrl.text,
        'https://codex-api.packycode.com/v1',
      ),
      fallbackBaseUrl: _normalizeUrl(
        _fallbackBaseUrlCtrl.text,
        'https://api.deepseek.com',
      ),
      preferredEndpoint: _preferredEndpoint,
    );
    final next = await Navigator.of(context).push<ApiSettings>(
      MaterialPageRoute<ApiSettings>(
        builder: (context) => _ApiSettingsPage(
          initialSettings: settings,
          snapshotStore: _snapshotStore,
        ),
      ),
    );
    if (next == null) {
      return;
    }
    try {
      await _snapshotStore.updateApiSettings(next);
      _apiKeyCtrl.text = next.apiKey;
      _primaryBaseUrlCtrl.text = next.primaryBaseUrl;
      _fallbackBaseUrlCtrl.text = next.fallbackBaseUrl;
      _preferredEndpoint = next.preferredEndpoint;
      if (mounted) {
        setState(() => _snapshot = _snapshot.copyWith(apiSettings: next));
      }
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: 'API 设置已保存');
    } catch (e) {
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: 'API 设置保存失败：$e', isError: true);
    }
  }

  Future<void> _openBasicProfileSettingsPage() async {
    if (!mounted) {
      return;
    }
    final next = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => _BasicProfileSettingsPage(
          initialProfile:
              _snapshot.userProfile ?? _buildProfileDraftForSettings(),
          snapshotStore: _snapshotStore,
        ),
      ),
    );
    if (next == null) {
      return;
    }

    try {
      await _snapshotStore.updateProfile(next);
      _applyProfileToControllers(next);
      if (mounted) {
        setState(() => _snapshot = _snapshot.copyWith(userProfile: next));
      }
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '基本信息已保存');
    } catch (e) {
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '基本信息保存失败：$e', isError: true);
    }
  }

  Future<void> _openPlanBuilderSheet() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: _DashboardColors.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Future<void> submit() async {
          if (_loading) {
            return;
          }
          if (!_formKey.currentState!.validate()) {
            return;
          }

          final profile = _buildProfileFromForm();
          final metrics = DailyHealthMetrics(
            weightKg: double.parse(_weightCtrl.text.trim()),
            systolic: int.parse(_systolicCtrl.text.trim()),
            diastolic: int.parse(_diastolicCtrl.text.trim()),
            date: DateTime.now(),
          );
          final metricHistory = _buildMetricHistory();
          // Persist profile draft locally first, so notes/basic info are not
          // lost even if remote plan generation fails.
          await _snapshotStore.updateProfile(profile);
          if (!sheetContext.mounted) {
            return;
          }
          Navigator.of(sheetContext).pop();
          await _runGeneratePlanWithBlockingLoading(
            profile: profile,
            metrics: metrics,
            metricHistory: metricHistory,
          );
        }

        return Theme(
          data: Theme.of(sheetContext).copyWith(
            inputDecorationTheme: _buildDashboardInputDecorationTheme(),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return _DashboardColors.accent;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFED7AA);
                }
                return null;
              }),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '基础信息与计划生成',
                          style: const TextStyle(
                            color: _DashboardColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSheetSection(
                      title: '基础信息',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(labelText: '性别'),
                            items: const [
                              DropdownMenuItem(
                                value: 'unknown',
                                child: Text('未知'),
                              ),
                              DropdownMenuItem(value: 'male', child: Text('男')),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('女'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('其他'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _gender = value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _heightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '身高（cm）',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,1}'),
                              ),
                            ],
                            validator: (value) => _validateDoubleInRange(
                              value,
                              label: '身高',
                              min: 80,
                              max: 250,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '体重（kg）',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,1}'),
                              ),
                            ],
                            validator: (value) => _validateDoubleInRange(
                              value,
                              label: '体重',
                              min: 20,
                              max: 300,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _goalCtrl,
                            decoration: const InputDecoration(
                              labelText: '锻炼目的',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: '备注（伤病/限制/偏好）',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _historyTrainingCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: '最近7天历史训练摘要',
                              hintText: '例如：最近一周完成了2次慢跑和1次力量训练',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                '是否有基础疾病',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _DashboardColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _hasDisease,
                                onChanged: (value) =>
                                    setState(() => _hasDisease = value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetSection(
                      title: '训练参数',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _minutesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '锻炼时长（分钟，含休息）',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) => _validateIntInRange(
                              value,
                              label: '锻炼时长',
                              min: 5,
                              max: 300,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _minutesCtrl,
                            builder: (context, value, _) {
                              final selectedQuickMinute =
                                  int.tryParse(value.text.trim()) ?? -1;
                              return DashboardSegmentedTabSelector<int>(
                                items: const [
                                  DashboardSegmentedTabItem<int>(
                                    value: 20,
                                    label: '20 分钟',
                                  ),
                                  DashboardSegmentedTabItem<int>(
                                    value: 30,
                                    label: '30 分钟',
                                  ),
                                  DashboardSegmentedTabItem<int>(
                                    value: 45,
                                    label: '45 分钟',
                                  ),
                                  DashboardSegmentedTabItem<int>(
                                    value: 60,
                                    label: '60 分钟',
                                  ),
                                ],
                                selectedValue: selectedQuickMinute,
                                onChanged: (minute) =>
                                    _setControllerTextAndKeepCursor(
                                      _minutesCtrl,
                                      minute.toString(),
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _equipmentsCtrl,
                            decoration: const InputDecoration(
                              labelText: '器材（逗号分隔）',
                              helperText: '可点击下方标签快速增删',
                            ),
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _equipmentsCtrl,
                            builder: (context, value, _) {
                              final selectedEquipments = _parseEquipmentList(
                                value.text,
                              ).toSet();
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['无器械', '瑜伽垫', '哑铃', '拉力带']
                                    .map((equipment) {
                                      final selected = selectedEquipments
                                          .contains(equipment);
                                      return _QuickSelectTag(
                                        label: equipment,
                                        selected: selected,
                                        onTap: () => _toggleEquipmentChip(
                                          equipment,
                                          !selected,
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSheetSection(
                      title: '健康指标',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _systolicCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '收缩压'),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) => _validateIntInRange(
                              value,
                              label: '收缩压',
                              min: 70,
                              max: 220,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _diastolicCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '舒张压'),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final base = _validateIntInRange(
                                value,
                                label: '舒张压',
                                min: 40,
                                max: 140,
                              );
                              if (base != null) {
                                return base;
                              }
                              final systolic = int.tryParse(
                                _systolicCtrl.text.trim(),
                              );
                              final diastolic = int.tryParse(value!.trim());
                              if (systolic != null &&
                                  diastolic != null &&
                                  diastolic >= systolic) {
                                return '舒张压需小于收缩压';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _historyWeightsCtrl,
                            decoration: const InputDecoration(
                              labelText: '最近体重序列（kg，逗号分隔）',
                              hintText: '例如：64.8,65.0,65.2',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _historyBpCtrl,
                            decoration: const InputDecoration(
                              labelText: '最近血压序列（systolic/diastolic）',
                              hintText: '例如：118/78,120/80',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text(
                        '生成今日打卡计划',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runGeneratePlanWithBlockingLoading({
    required UserProfile profile,
    required DailyHealthMetrics metrics,
    required List<DailyHealthSnapshot> metricHistory,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final navigator = Navigator.of(context, rootNavigator: true);
    var loadingOpened = false;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'loading',
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        loadingOpened = true;
        return const _FullscreenLoadingPage();
      },
    );
    await Future<void>.delayed(Duration.zero);

    try {
      final snapshot = await _snapshotStore.load();
      final apiSettings = snapshot.apiSettings;
      final preferPrimary = apiSettings.preferredEndpoint != 'fallback';
      final preferredBaseUrl = preferPrimary
          ? apiSettings.primaryBaseUrl
          : apiSettings.fallbackBaseUrl;
      final backupBaseUrl = preferPrimary
          ? apiSettings.fallbackBaseUrl
          : apiSettings.primaryBaseUrl;
      final usingInjectedService = _service != null;
      final generatedService =
          _service ??
          DeepSeekService(
            apiKey: apiSettings.apiKey.trim().isEmpty
                ? null
                : apiSettings.apiKey.trim(),
            primaryBaseUrl: preferredBaseUrl,
            fallbackBaseUrl: backupBaseUrl,
          );
      final completedHistory = snapshot.checkinHistory
          .where((record) => record.completed)
          .toList(growable: false);
      late final TrainingPlan plan;
      try {
        plan = await generatedService
            .generateTrainingPlan(
              profile: profile,
              metrics: metrics,
              metricHistory: metricHistory,
              completedTrainingHistory: completedHistory,
              contract: const ComponentContract(),
              trainingHistorySummary: _historyTrainingCtrl.text.trim(),
              totalMinutesIncludesRest: true,
            )
            .timeout(
              const Duration(seconds: 300),
              onTimeout: () => throw const DeepSeekException('生成超时，请稍后重试。'),
            );
      } finally {
        if (!usingInjectedService) {
          generatedService.dispose();
        }
      }
      final now = DateTime.now().toUtc();
      final planVersion = planVersionFromPlan(plan);
      final historyId = planHistoryId(now, planVersion);
      await _snapshotStore.updateProfile(profile);
      await _snapshotStore.updatePlan(
        plan,
        generatedAt: now,
        planVersion: planVersion,
      );
      await _snapshotStore.addPlanToHistory(
        HistoricalTrainingPlan(
          id: historyId,
          createdAt: now,
          source: 'generated',
          planVersion: planVersion,
          plan: plan,
          profileSnapshot: profile,
        ),
      );
      final latestSnapshot = await _snapshotStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = latestSnapshot;
        _plan = plan;
        _planVersion = planVersion;
        _planHistoryCount = latestSnapshot.planHistory.length;
        _achievementState = latestSnapshot.achievementState;
        _pendingSession = _resolvePendingSession(latestSnapshot);
      });
      showDashboardSnackBar(
        context,
        message: '计划已生成：共 ${plan.items.length} 项，建议立即开始训练',
        actionLabel: '开始',
        onAction: _startTraining,
        duration: const Duration(seconds: 4),
      );
    } on DeepSeekException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '生成失败: $e');
      }
    } finally {
      if (loadingOpened && navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _normalizeUrl(String value, String fallback) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return fallback;
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  UserProfile _buildProfileFromForm() {
    return UserProfile(
      heightCm: double.parse(_heightCtrl.text.trim()),
      weightKg: double.parse(_weightCtrl.text.trim()),
      hasDisease: _hasDisease,
      exerciseMinutes: int.parse(_minutesCtrl.text.trim()),
      equipments: _equipmentsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      gender: _gender,
      goal: _goalCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      trainingHistorySummary: _historyTrainingCtrl.text.trim(),
      targetMinutesIncludesRest: true,
    );
  }

  List<DailyHealthSnapshot> _buildMetricHistory() {
    final weightSeries = _historyWeightsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);

    final bpSeries = _historyBpCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((entry) {
          final pair = entry.split('/');
          if (pair.length != 2) {
            return null;
          }
          final systolic = int.tryParse(pair[0]);
          final diastolic = int.tryParse(pair[1]);
          if (systolic == null || diastolic == null) {
            return null;
          }
          return (systolic: systolic, diastolic: diastolic);
        })
        .whereType<({int systolic, int diastolic})>()
        .toList(growable: false);

    final count = min(weightSeries.length, bpSeries.length);
    if (count == 0) {
      return const [];
    }

    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: count - 1));
    return List<DailyHealthSnapshot>.generate(count, (index) {
      return DailyHealthSnapshot(
        date: startDate.add(Duration(days: index)),
        weightKg: weightSeries[index],
        systolic: bpSeries[index].systolic,
        diastolic: bpSeries[index].diastolic,
      );
    }, growable: false);
  }

  String _formatDouble(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String? _validateDoubleInRange(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label必填';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return '$label请输入数字';
    }
    if (parsed < min || parsed > max) {
      return '$label建议在${min.toStringAsFixed(0)}-$max之间';
    }
    return null;
  }

  String? _validateIntInRange(
    String? value, {
    required String label,
    required int min,
    required int max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label必填';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$label请输入整数';
    }
    if (parsed < min || parsed > max) {
      return '$label建议在$min-$max之间';
    }
    return null;
  }

  void _setControllerTextAndKeepCursor(
    TextEditingController controller,
    String value,
  ) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  List<String> _parseEquipmentList(String raw) {
    final seen = <String>{};
    final values = <String>[];
    for (final value in raw.split(RegExp(r'[，,]'))) {
      final cleaned = value.trim();
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      values.add(cleaned);
    }
    return values;
  }

  void _toggleEquipmentChip(String equipment, bool selected) {
    final current = _parseEquipmentList(_equipmentsCtrl.text);
    if (selected) {
      if (!current.contains(equipment)) {
        current.add(equipment);
      }
    } else {
      current.removeWhere((item) => item == equipment);
    }
    _setControllerTextAndKeepCursor(_equipmentsCtrl, current.join(','));
  }

  Future<void> _exportData() async {
    try {
      final snapshot = await _snapshotStore.load();
      final file = await _portabilityService.exportSnapshotFile(snapshot);
      await _portabilityService.shareExportedFile(file);
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '已导出并调起分享。');
    } catch (e) {
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '导出失败：$e', isError: true);
    }
  }

  Future<void> _importData() async {
    final confirmed = await _showDashboardConfirmDialog(
      title: '导入并覆盖本地数据',
      message: '导入将覆盖当前基础信息、计划与打卡记录，是否继续？',
      confirmLabel: '继续导入',
    );

    if (confirmed != true) {
      return;
    }

    try {
      final imported = await _portabilityService.pickAndParseImportFile();
      if (imported == null) {
        return;
      }
      await _portabilityService.importAndReplace(imported);
      setState(() => _hydrating = true);
      await _restoreFromSnapshot();
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '导入成功，已刷新页面数据。');
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: e.message, isError: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showDashboardSnackBar(context, message: '导入失败：$e', isError: true);
    }
  }

  Future<void> _openHelpAndFeedbackSheet() async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _DashboardColors.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const DashboardPageHeader(
              title: '帮助与反馈',
              subtitle: '延续首页四标签规范，统一入口与数据操作。',
            ),
            const SizedBox(height: 8),
            _buildSheetActionTile(
              leading: const Icon(Icons.download_for_offline),
              title: '导入数据',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _importData();
              },
            ),
            const SizedBox(height: 8),
            _buildSheetActionTile(
              leading: const Icon(Icons.history),
              title: '历史计划',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openHistoryPage();
              },
            ),
            const SizedBox(height: 8),
            _buildSheetActionTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: '我的成就',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openAchievementPage();
              },
            ),
            const SizedBox(height: 8),
            _buildSheetActionTile(
              leading: const Icon(Icons.info_outline),
              title: '版本说明',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAboutDialog(
                  context: context,
                  applicationName: '个人锻炼助手',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '运动竞速橙蓝版首页重构',
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndResetLocalData() async {
    final confirmed = await _showDashboardConfirmDialog(
      title: '退出并清空本地数据',
      message: '将清除当前设备上的计划、打卡和设置数据，是否继续？',
      confirmLabel: '确认清空',
      warning: true,
    );
    if (confirmed != true) {
      return;
    }

    await _snapshotStore.resetAll();
    await _restoreFromSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentTabIndex = 0;
      _error = null;
    });
    showDashboardSnackBar(context, message: '已退出并清空本地数据');
  }

  Future<bool?> _showDashboardConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool warning = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: DashboardSurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: warning
                            ? DashboardTokens.warningSoft
                            : DashboardTokens.accentSoft,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        warning
                            ? Icons.warning_amber_rounded
                            : Icons.file_download_done_rounded,
                        color: warning
                            ? DashboardTokens.warning
                            : DashboardTokens.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: DashboardTokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: DashboardTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          foregroundColor: DashboardTokens.textSecondary,
                          side: const BorderSide(
                            color: DashboardTokens.inputBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.buttonRadius,
                            ),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          backgroundColor: warning
                              ? DashboardTokens.warning
                              : DashboardTokens.accent,
                          foregroundColor: DashboardTokens.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.buttonRadius,
                            ),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startTraining() {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrainingSessionPage(
              plan: plan,
              planVersion: _planVersion,
              snapshotStore: _snapshotStore,
            ),
          ),
        )
        .then((_) => _restoreFromSnapshot());
  }

  Future<void> _resumePendingSession(_PendingSessionEntry pending) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingSessionPage(
          plan: pending.plan,
          planVersion: pending.planVersion,
          snapshotStore: _snapshotStore,
        ),
      ),
    );
    await _restoreFromSnapshot();
  }

  Future<void> _openAchievementPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AchievementPage(
          achievementState: _achievementState,
          snapshotStore: _snapshotStore,
        ),
      ),
    );
    await _restoreFromSnapshot();
  }

  Future<void> _openHistoryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanHistoryPage(snapshotStore: _snapshotStore),
      ),
    );
    await _restoreFromSnapshot();
  }

  Future<void> _openPlanDetailsSheet(TrainingPlan plan) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _DashboardColors.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: plan.items.length + 1,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return DashboardSurfaceCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '完整动作列表',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${plan.items.length} 项 · 预计 ${_formatDuration(plan.totalDurationSeconds)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _DashboardColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }
            final item = plan.items[index - 1];
            final isRest = item.type == 'rest';
            return DashboardSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isRest
                          ? DashboardTokens.info.withValues(alpha: 0.12)
                          : DashboardTokens.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isRest ? Icons.self_improvement : Icons.fitness_center,
                      size: 18,
                      color: isRest
                          ? DashboardTokens.info
                          : _DashboardColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.effectiveTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDuration(item.normalizedDurationSeconds)} · ${isRest ? '休息' : item.intensity}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DashboardColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInsightsSheet(TrainingPlan plan) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _DashboardColors.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const DashboardPageHeader(
              title: '训练建议',
              subtitle: '按首页四标签规范查看饮食、补水与风险提示。',
            ),
            const SizedBox(height: 8),
            _buildSheetSection(
              title: '饮食',
              child: _AdviceRow(
                icon: Icons.restaurant,
                title: '饮食',
                content: plan.dietAdvice,
              ),
            ),
            const SizedBox(height: 10),
            _buildSheetSection(
              title: '饮水（${plan.hydrationTargetMl}ml）',
              child: _AdviceRow(
                icon: Icons.water_drop_outlined,
                title: '饮水',
                content: plan.hydrationAdvice,
              ),
            ),
            const SizedBox(height: 10),
            _buildSheetSection(
              title: '风险提示',
              child: _AdviceRow(
                icon: Icons.health_and_safety_outlined,
                title: '风险提示',
                content: plan.warning,
                isWarning: true,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes 分钟';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  int _estimateKcalFromSeconds(int seconds) {
    final minutes = seconds / 60;
    return (minutes * 7).round();
  }

  TrainingPlan? get _activePlanForDashboard => _pendingSession?.plan ?? _plan;

  int get _completedCountForActivePlan {
    final pending = _pendingSession;
    if (pending != null) {
      return pending.completedCount;
    }
    return 0;
  }

  WorkoutItemStatus _statusForItem(int index) {
    final pending = _pendingSession;
    if (pending != null) {
      if (index < pending.completedCount) {
        return WorkoutItemStatus.completed;
      }
      if (index == pending.currentIndex) {
        return WorkoutItemStatus.active;
      }
      return WorkoutItemStatus.pending;
    }
    if (_activePlanForDashboard == null) {
      return WorkoutItemStatus.pending;
    }
    return index == 0 ? WorkoutItemStatus.active : WorkoutItemStatus.pending;
  }

  List<DashboardWorkoutItemData> _buildWorkoutItems({int maxCount = 3}) {
    final plan = _activePlanForDashboard;
    if (plan == null || plan.items.isEmpty) {
      return const [
        DashboardWorkoutItemData(
          title: '还没有训练项',
          meta: '创建计划后会自动生成动作列表',
          status: WorkoutItemStatus.pending,
        ),
      ];
    }

    return plan.items
        .take(maxCount)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          return DashboardWorkoutItemData(
            title: item.effectiveTitle,
            meta:
                '${_formatDuration(item.normalizedDurationSeconds)} · ${item.type == 'rest' ? '休息' : item.intensity}',
            status: _statusForItem(index),
          );
        })
        .toList(growable: false);
  }

  HomeViewData _buildHomeViewData() {
    final plan = _activePlanForDashboard;
    final total = plan?.items.length ?? 0;
    final completed = _completedCountForActivePlan;
    final progressText = total == 0 ? '冲刺 0/0' : '冲刺 $completed/$total';
    final progressRatio = total == 0
        ? 0.0
        : (completed / total).clamp(0.0, 1.0);

    final today = _dateKey(DateTime.now());
    final todayCompleted = _snapshot.checkinHistory
        .where((entry) => entry.completed && entry.date == today)
        .fold<int>(
          0,
          (sum, entry) => sum + entry.planDigest.totalTargetSeconds,
        );
    final fallbackSeconds = plan?.totalDurationSeconds ?? 0;
    final estimatedKcal = _estimateKcalFromSeconds(
      todayCompleted > 0 ? todayCompleted : fallbackSeconds,
    );

    return HomeViewData(
      progressText: progressText,
      progressRatio: progressRatio,
      streakDays: _achievementState.currentStreakDays,
      estimatedKcal: estimatedKcal,
      items: _buildWorkoutItems(),
    );
  }

  PlanViewData _buildPlanViewData() {
    final plan = _activePlanForDashboard;
    final progressRatio = plan == null || plan.items.isEmpty
        ? 0.0
        : (_completedCountForActivePlan / plan.items.length).clamp(0.0, 1.0);
    final streak = _achievementState.currentStreakDays;
    final sleepProgress = (0.55 + streak * 0.03).clamp(0.3, 1.0);
    final sleepHours = (sleepProgress * 8).toStringAsFixed(1);

    final waterTarget = plan?.hydrationTargetMl ?? 2000;
    final waterCurrent = max(
      300,
      (waterTarget * (0.35 + progressRatio * 0.5)).round(),
    );
    final waterProgress = (waterCurrent / waterTarget).clamp(0.0, 1.0);

    final stepTarget = 10000;
    final estimatedSteps = max(
      2400,
      (3500 + progressRatio * 5500 + streak * 180).round(),
    );
    final stepProgress = (estimatedSteps / stepTarget).clamp(0.0, 1.0);

    return PlanViewData(
      todayItems: _buildWorkoutItems(),
      recoveryMetrics: [
        RecoveryMetricData(
          label: '睡眠',
          valueText: '$sleepHours / 8 小时（估算）',
          progress: sleepProgress,
          estimated: true,
        ),
        RecoveryMetricData(
          label: '饮水',
          valueText:
              '${(waterCurrent / 1000).toStringAsFixed(1)} / ${(waterTarget / 1000).toStringAsFixed(1)} L',
          progress: waterProgress,
        ),
        RecoveryMetricData(
          label: '步数',
          valueText: '$estimatedSteps / $stepTarget（估算）',
          progress: stepProgress,
          estimated: true,
        ),
      ],
    );
  }

  List<DailyCheckinRecord> _checkinsInRange(StatsRange range) {
    final now = _dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: range.days - 1));
    return _snapshot.checkinHistory
        .where((entry) {
          final parsed = DateTime.tryParse(entry.date);
          if (parsed == null) {
            return false;
          }
          final day = _dateOnly(parsed);
          return !day.isBefore(start) && !day.isAfter(now);
        })
        .toList(growable: false);
  }

  StatsViewData _buildStatsViewData(StatsRange range) {
    final checkins = _checkinsInRange(range);
    final completed = checkins
        .where((entry) => entry.completed)
        .toList(growable: false);
    final completionRate = checkins.isEmpty
        ? 0
        : ((completed.length / checkins.length) * 100).round();
    final totalSeconds = completed.fold<int>(
      0,
      (sum, entry) => sum + entry.planDigest.totalTargetSeconds,
    );
    final totalMinutes = (totalSeconds / 60).round();
    final estimatedKcal = _estimateKcalFromSeconds(totalSeconds);

    final now = _dateOnly(DateTime.now());
    final dayMinutes = <String, int>{};
    for (final entry in completed) {
      dayMinutes[entry.date] =
          (dayMinutes[entry.date] ?? 0) +
          (entry.planDigest.totalTargetSeconds / 60).round();
    }
    final trendBars = List<StatsTrendBarData>.generate(range.days, (index) {
      final day = now.subtract(Duration(days: range.days - index - 1));
      final key = _dateKey(day);
      return StatsTrendBarData(
        label: '${day.month}/${day.day}',
        minutes: dayMinutes[key] ?? 0,
      );
    }, growable: false);

    final habitCounter = <String, int>{};
    for (final record in completed) {
      for (final item in record.itemRecords) {
        if (item.title.trim().isEmpty) {
          continue;
        }
        habitCounter[item.title] = (habitCounter[item.title] ?? 0) + 1;
      }
    }
    final habitRank = habitCounter.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return a.key.compareTo(b.key);
      });
    final topHabits = habitRank.take(3).toList(growable: false);

    return StatsViewData(
      completionRate: completionRate,
      streakDays: _achievementState.currentStreakDays,
      totalMinutes: totalMinutes,
      estimatedKcal: estimatedKcal,
      metrics: [
        StatsMetricData(label: '完成率', value: '$completionRate%'),
        StatsMetricData(
          label: '连续天数',
          value: '${_achievementState.currentStreakDays} 天',
        ),
        StatsMetricData(label: '总训练时长', value: '$totalMinutes 分钟'),
        StatsMetricData(label: '活动千卡', value: '$estimatedKcal'),
      ],
      trendBars: trendBars,
      habitRank: topHabits,
    );
  }

  ProfileViewData _buildProfileViewData() {
    final profile = _snapshot.userProfile;
    final displayName = '训练者';
    final streak = _achievementState.currentStreakDays;
    final level = max(1, (streak / 7).ceil());
    final weekCompleted = _checkinsInRange(
      StatsRange.days7,
    ).where((entry) => entry.completed).length;
    final goalMinutes = profile?.exerciseMinutes ?? 30;
    return ProfileViewData(
      displayName: displayName,
      badgeText: '等级$level',
      meta: '本周完成 $weekCompleted 次训练 · 历史计划 $_planHistoryCount 条',
      goalText: '训练 $goalMinutes 分钟',
      reminderText: '每天 20:30',
      unitText: '公制',
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_loading) {
      return;
    }
    final pending = _pendingSession;
    if (pending != null) {
      await _resumePendingSession(pending);
      return;
    }
    if (_activePlanForDashboard != null) {
      _startTraining();
      return;
    }
    await _openPlanBuilderSheet();
  }

  String _primaryActionLabel() {
    if (_pendingSession != null) {
      return '继续训练';
    }
    if (_activePlanForDashboard != null) {
      return '开始训练';
    }
    return '创建计划';
  }

  Widget _buildHeader(String title, String subtitle) {
    return DashboardPageHeader(title: title, subtitle: subtitle);
  }

  Widget _buildWorkoutStatusButton(WorkoutItemStatus status) {
    late final Color background;
    late final Color foreground;
    late final String symbol;
    switch (status) {
      case WorkoutItemStatus.completed:
        background = _DashboardColors.success;
        foreground = Colors.white;
        symbol = '✓';
        break;
      case WorkoutItemStatus.active:
        background = _DashboardColors.warning;
        foreground = Colors.white;
        symbol = '•';
        break;
      case WorkoutItemStatus.pending:
        background = const Color(0xFFE5E7EB);
        foreground = const Color(0xFF8E8E93);
        symbol = '○';
        break;
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildWorkoutItemCard(DashboardWorkoutItemData item, {Color? fill}) {
    Color dotColor;
    switch (item.status) {
      case WorkoutItemStatus.completed:
        dotColor = _DashboardColors.success;
        break;
      case WorkoutItemStatus.active:
        dotColor = _DashboardColors.warning;
        break;
      case WorkoutItemStatus.pending:
        dotColor = _DashboardColors.info;
        break;
    }
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fill ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _DashboardColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildWorkoutStatusButton(item.status),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton({required String label}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _handlePrimaryAction,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: _DashboardColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRegeneratePlanButton({double minHeight = 46}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _openPlanBuilderSheet,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(minHeight),
          backgroundColor: DashboardTokens.accentSoft,
          foregroundColor: _DashboardColors.accent,
          side: BorderSide(
            color: _DashboardColors.accent.withValues(alpha: 0.45),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
          ),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text(
          '重新生成计划',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHydratingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          _buildHeader('训练计划', '正在同步你的训练数据与四标签面板。'),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 250,
                child: DashboardSurfaceCard(
                  outlined: true,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dashboard_customize_rounded,
                        size: 28,
                        color: _DashboardColors.accent,
                      ),
                      SizedBox(height: 12),
                      CircularProgressIndicator(color: _DashboardColors.accent),
                      SizedBox(height: 10),
                      Text(
                        '正在加载首页四标签内容...',
                        style: TextStyle(color: _DashboardColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final data = _buildHomeViewData();
    final plan = _activePlanForDashboard;
    return RefreshIndicator(
      onRefresh: _restoreFromSnapshot,
      child: ListView(
        key: const ValueKey('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildHeader('今天', '保持节奏，冲刺每日习惯目标。'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '今日进度',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.progressText,
                      style: const TextStyle(
                        color: _DashboardColors.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: data.progressRatio,
                    backgroundColor: const Color(0xFFD1D5DB),
                    color: _DashboardColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.buttonRadius,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '连续天数',
                              style: TextStyle(
                                fontSize: 12,
                                color: _DashboardColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.streakDays} 天',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2E8),
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.buttonRadius,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '活动千卡',
                              style: TextStyle(
                                fontSize: 12,
                                color: _DashboardColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.estimatedKcal}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _handlePrimaryAction,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFDDF7E8),
                          foregroundColor: const Color(0xFF12805C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text('开始训练'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (plan != null) {
                            _openPlanDetailsSheet(plan);
                          } else {
                            setState(() => _currentTabIndex = 1);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFFFEAD9),
                          foregroundColor: const Color(0xFFD95F00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text('查看计划'),
                      ),
                    ),
                  ],
                ),
                if (plan != null) ...[
                  const SizedBox(height: 8),
                  _buildRegeneratePlanButton(minHeight: 44),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '今日习惯',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentTabIndex = 1),
                child: const Text(
                  '查看全部',
                  style: TextStyle(
                    color: _DashboardColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ...data.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildWorkoutItemCard(item),
            ),
          ),
          if (plan != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openInsightsSheet(plan),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('训练建议'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EA),
                borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
                border: Border.all(color: const Color(0xFFFFD7B8)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildPrimaryActionButton(label: _primaryActionLabel()),
        ],
      ),
    );
  }

  Widget _buildPlanTab() {
    final data = _buildPlanViewData();
    final weekdays = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final selectedDay = DateTime.now().weekday - 1;
    return RefreshIndicator(
      onRefresh: _restoreFromSnapshot,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildHeader('计划', '本周训练与恢复冲刺安排'),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '本周计划',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      weekdays[selectedDay],
                      style: const TextStyle(
                        fontSize: 15,
                        color: _DashboardColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List<Widget>.generate(weekdays.length, (index) {
                    final selected = index == selectedDay;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? _DashboardColors.accent
                                : const Color(0xFFE8EDF3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            weekdays[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF59626B),
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '今日训练',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${data.todayItems.length} 项 · 目标45分',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _DashboardColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...data.todayItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final fill = switch (index) {
                    0 => const Color(0xFFF4FBF7),
                    1 => const Color(0xFFFFF5EC),
                    _ => const Color(0xFFF1F8FF),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildWorkoutItemCard(item, fill: fill),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '恢复与习惯',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...data.recoveryMetrics.map((metric) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              metric.label,
                              style: const TextStyle(
                                fontSize: 15,
                                color: _DashboardColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              metric.valueText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _DashboardColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        if (metric.estimated)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              '未接设备，估算值',
                              style: TextStyle(
                                fontSize: 11,
                                color: _DashboardColors.textMuted,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: metric.progress.clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFD1D1D6),
                            color: switch (metric.label) {
                              '睡眠' => _DashboardColors.info,
                              '饮水' => const Color(0xFF32ADE6),
                              _ => _DashboardColors.success,
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPrimaryActionButton(label: '开始今日计划'),
          if (_activePlanForDashboard != null) ...[
            const SizedBox(height: 8),
            _buildRegeneratePlanButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final data = _buildStatsViewData(_statsRange);
    final maxMinutes = data.trendBars.fold<int>(
      1,
      (maxValue, item) => max(maxValue, item.minutes),
    );
    return RefreshIndicator(
      onRefresh: _restoreFromSnapshot,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildHeader('统计', '查看训练趋势与冲刺表现'),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DashboardSegmentedTabSelector<StatsRange>(
                  items: const [
                    DashboardSegmentedTabItem<StatsRange>(
                      value: StatsRange.days7,
                      label: '7天',
                    ),
                    DashboardSegmentedTabItem<StatsRange>(
                      value: StatsRange.days30,
                      label: '30天',
                    ),
                    DashboardSegmentedTabItem<StatsRange>(
                      value: StatsRange.days90,
                      label: '90天',
                    ),
                  ],
                  selectedValue: _statsRange,
                  onChanged: (value) => setState(() => _statsRange = value),
                ),
                const SizedBox(height: 8),
                Text(
                  '冲刺周：近 ${_statsRange.days} 天训练完成率 ${data.completionRate >= 50 ? '持续提升' : '需要加强'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _DashboardColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '总览',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        data.metrics[0],
                        const Color(0xFFEEF4FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        data.metrics[1],
                        const Color(0xFFEEF8F2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        data.metrics[2],
                        const Color(0xFFFFF3E9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        data.metrics[3],
                        const Color(0xFFFFE9D9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '训练趋势',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '分钟',
                      style: TextStyle(
                        fontSize: 12,
                        color: _DashboardColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.trendBars
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final bar = entry.value;
                          final ratio = (bar.minutes / maxMinutes).clamp(
                            0.0,
                            1.0,
                          );
                          final barHeight = 18 + ratio * 52;
                          final isLast = index == data.trendBars.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 14,
                              height: 82,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: isLast
                                        ? _DashboardColors.accent
                                        : Color.lerp(
                                            const Color(0xFFCFE0FF),
                                            const Color(0xFF3B82F6),
                                            ratio,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '习惯贡献榜',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (data.habitRank.isEmpty)
                  const Text(
                    '暂无已完成训练记录',
                    style: TextStyle(
                      fontSize: 13,
                      color: _DashboardColors.textMuted,
                    ),
                  )
                else
                  ...data.habitRank.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final row = entry.value;
                    return Container(
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? const Color(0xFFEEF8F2)
                            : const Color(0xFFF7F8FB),
                        borderRadius: BorderRadius.circular(
                          DashboardTokens.buttonRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$rank. ${row.key}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Text(
                            '${row.value} 次',
                            style: TextStyle(
                              fontSize: 13,
                              color: rank == 1
                                  ? const Color(0xFF16A34A)
                                  : _DashboardColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(StatsMetricData metric, Color backgroundColor) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              fontSize: 12,
              color: _DashboardColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final data = _buildProfileViewData();
    final avatarText = data.displayName.isNotEmpty ? data.displayName[0] : '训';
    return RefreshIndicator(
      onRefresh: _restoreFromSnapshot,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildHeader('我的', '账号、偏好与隐私设置'),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('profile-basic-info-entry'),
                onTap: _openBasicProfileSettingsPage,
                borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFFF9A4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          avatarText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.meta,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _DashboardColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '点击可设置基本信息',
                              style: TextStyle(
                                fontSize: 12,
                                color: _DashboardColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _DashboardColors.accent,
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.buttonRadius,
                          ),
                        ),
                        child: Text(
                          data.badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _DashboardColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildProfileInfoRow(
                  '每日目标',
                  data.goalText,
                  icon: Icons.timer_outlined,
                  background: DashboardTokens.info.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 8),
                _buildProfileInfoRow(
                  '提醒时间',
                  data.reminderText,
                  icon: Icons.notifications_none_rounded,
                  background: DashboardTokens.successSoft,
                ),
                const SizedBox(height: 8),
                _buildProfileInfoRow(
                  '单位设置',
                  data.unitText,
                  icon: Icons.straighten_rounded,
                  background: DashboardTokens.warningSoft,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DashboardSurfaceCard(
            outlined: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildProfileActionRow(
                  key: const ValueKey('profile-action-notification'),
                  label: '通知设置',
                  icon: Icons.notifications_outlined,
                  onTap: () {
                    showDashboardSnackBar(context, message: '通知设置即将上线');
                  },
                ),
                const SizedBox(height: 8),
                _buildProfileActionRow(
                  key: const ValueKey('profile-action-privacy'),
                  label: '隐私与安全',
                  icon: Icons.lock_outline_rounded,
                  onTap: _openApiSettingsPage,
                ),
                const SizedBox(height: 8),
                _buildProfileActionRow(
                  key: const ValueKey('profile-action-export'),
                  label: '数据导出',
                  icon: Icons.ios_share_rounded,
                  onTap: _exportData,
                ),
                const SizedBox(height: 8),
                _buildProfileActionRow(
                  key: const ValueKey('profile-action-help'),
                  label: '帮助与反馈',
                  icon: Icons.help_outline_rounded,
                  onTap: _openHelpAndFeedbackSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('profile-logout-button'),
              onPressed: _confirmAndResetLocalData,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: const Color(0xFFFFEDEE),
                foregroundColor: const Color(0xFFC62828),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DashboardTokens.buttonRadius,
                  ),
                ),
              ),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(
    String label,
    String value, {
    required IconData icon,
    required Color background,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: _DashboardColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _DashboardColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: _DashboardColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionRow({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: DashboardTokens.pageBackground,
          borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
          border: Border.all(color: DashboardTokens.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: DashboardTokens.accentSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: _DashboardColors.accent),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: _DashboardColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _DashboardColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  InputDecorationTheme _buildDashboardInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
        borderSide: const BorderSide(color: _DashboardColors.accent),
      ),
    );
  }

  Widget _buildSheetSection({required String title, required Widget child}) {
    return DashboardSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSheetActionTile({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
  }) {
    return DashboardSurfaceCard(
      outlined: true,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DashboardTokens.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconTheme(
                    data: const IconThemeData(
                      color: DashboardTokens.accent,
                      size: 18,
                    ),
                    child: leading,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DashboardTokens.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: DashboardTokens.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardTabPageScaffold(
      title: '训练计划',
      showAppBar: false,
      selectedTab: DashboardTab.values[_currentTabIndex],
      onTabChanged: (tab) => setState(() => _currentTabIndex = tab.index),
      backgroundColor: _DashboardColors.pageBackground,
      body: _hydrating
          ? _buildHydratingState()
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildHomeTab(),
                _buildPlanTab(),
                _buildStatsTab(),
                _buildProfileTab(),
              ],
            ),
    );
  }
}

class _DashboardColors {
  static const pageBackground = DashboardTokens.pageBackground;
  static const accent = DashboardTokens.accent;
  static const info = DashboardTokens.info;
  static const warning = DashboardTokens.warning;
  static const success = DashboardTokens.success;
  static const textPrimary = DashboardTokens.textPrimary;
  static const textSecondary = DashboardTokens.textSecondary;
  static const textMuted = DashboardTokens.textMuted;
}

InputDecoration _buildDashboardInputDecoration({
  required String labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: DashboardTokens.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      borderSide: const BorderSide(color: DashboardTokens.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      borderSide: const BorderSide(color: _DashboardColors.accent),
    ),
  );
}

class _PendingSessionEntry {
  const _PendingSessionEntry({
    required this.plan,
    required this.planVersion,
    required this.currentIndex,
    required this.completedCount,
  });

  final TrainingPlan plan;
  final String planVersion;
  final int currentIndex;
  final int completedCount;
}

class _SettingsOverviewTile extends StatelessWidget {
  const _SettingsOverviewTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconBackground,
    required this.iconColor,
    this.valueColor = _DashboardColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconBackground;
  final Color iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: DashboardSurfaceCard(
        outlined: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _DashboardColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSelectTag extends StatelessWidget {
  const _QuickSelectTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? DashboardTokens.accent
        : DashboardTokens.textInactive;
    return InkWell(
      borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? DashboardTokens.accentSoft
              : DashboardTokens.pageBackground,
          borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
          border: Border.all(
            color: selected
                ? DashboardTokens.accent
                : DashboardTokens.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
    required this.icon,
    required this.title,
    required this.content,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String content;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$title：',
              style: const TextStyle(fontWeight: FontWeight.w600),
              children: [TextSpan(text: content)],
            ),
          ),
        ),
      ],
    );
  }
}

class _BasicProfileSettingsPage extends StatefulWidget {
  const _BasicProfileSettingsPage({
    required this.initialProfile,
    required this.snapshotStore,
  });

  final UserProfile initialProfile;
  final LocalSnapshotStore snapshotStore;

  @override
  State<_BasicProfileSettingsPage> createState() =>
      _BasicProfileSettingsPageState();
}

class _BasicProfileSettingsPageState extends State<_BasicProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _equipmentsCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _trainingHistoryCtrl;

  late bool _hasDisease;
  late String _gender;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _heightCtrl = TextEditingController(
      text: _formatDouble(profile.heightCm, fallback: '170'),
    );
    _weightCtrl = TextEditingController(
      text: _formatDouble(profile.weightKg, fallback: '65'),
    );
    _minutesCtrl = TextEditingController(
      text: profile.exerciseMinutes <= 0
          ? '30'
          : profile.exerciseMinutes.toString(),
    );
    _equipmentsCtrl = TextEditingController(
      text: profile.equipments.join(',').trim().isEmpty
          ? '瑜伽垫,哑铃'
          : profile.equipments.join(','),
    );
    _goalCtrl = TextEditingController(text: profile.goal);
    _notesCtrl = TextEditingController(text: profile.notes);
    _trainingHistoryCtrl = TextEditingController(
      text: profile.trainingHistorySummary,
    );
    _hasDisease = profile.hasDisease;
    _gender = _normalizeGender(profile.gender);
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _minutesCtrl.dispose();
    _equipmentsCtrl.dispose();
    _goalCtrl.dispose();
    _notesCtrl.dispose();
    _trainingHistoryCtrl.dispose();
    super.dispose();
  }

  String _formatDouble(double value, {required String fallback}) {
    if (value <= 0) {
      return fallback;
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String _normalizeGender(String? value) {
    switch (value) {
      case 'male':
      case 'female':
      case 'other':
      case 'unknown':
        return value!;
      default:
        return 'unknown';
    }
  }

  String? _validateDoubleInRange(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label必填';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return '$label请输入数字';
    }
    if (parsed < min || parsed > max) {
      return '$label建议在${min.toStringAsFixed(0)}-$max之间';
    }
    return null;
  }

  String? _validateIntInRange(
    String? value, {
    required String label,
    required int min,
    required int max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label必填';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$label请输入整数';
    }
    if (parsed < min || parsed > max) {
      return '$label建议在$min-$max之间';
    }
    return null;
  }

  List<String> _parseEquipmentList(String raw) {
    final seen = <String>{};
    final values = <String>[];
    for (final part in raw.split(RegExp(r'[，,]'))) {
      final cleaned = part.trim();
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      values.add(cleaned);
    }
    return values;
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final profile = UserProfile(
      heightCm: double.parse(_heightCtrl.text.trim()),
      weightKg: double.parse(_weightCtrl.text.trim()),
      hasDisease: _hasDisease,
      exerciseMinutes: int.parse(_minutesCtrl.text.trim()),
      equipments: _parseEquipmentList(_equipmentsCtrl.text),
      gender: _gender,
      goal: _goalCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      trainingHistorySummary: _trainingHistoryCtrl.text.trim(),
      targetMinutesIncludesRest: true,
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final targetMinutes =
        int.tryParse(_minutesCtrl.text.trim()) ??
        widget.initialProfile.exerciseMinutes;
    final equipmentCount = _parseEquipmentList(_equipmentsCtrl.text).length;

    return DashboardTabPageScaffold(
      title: '基本信息设置',
      showAppBar: false,
      selectedTab: DashboardTab.profile,
      useSafeArea: false,
      backgroundColor: _DashboardColors.pageBackground,
      snapshotStore: widget.snapshotStore,
      allowReselectCurrentTab: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const DashboardPageHeader(
                title: '基本信息',
                subtitle: '按首页四标签样式维护你的训练档案。',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SettingsOverviewTile(
                      icon: Icons.timer_outlined,
                      title: '每日目标',
                      value: '${targetMinutes <= 0 ? 30 : targetMinutes} 分钟',
                      iconBackground: DashboardTokens.info.withValues(
                        alpha: 0.12,
                      ),
                      iconColor: _DashboardColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SettingsOverviewTile(
                      icon: Icons.fitness_center,
                      title: '可用器材',
                      value: '$equipmentCount 项',
                      iconBackground: DashboardTokens.warningSoft,
                      iconColor: _DashboardColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const DashboardSurfaceCard(
                outlined: true,
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: DashboardTokens.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '基础信息用于生成计划与恢复评估，建议按周更新一次。',
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
              const SizedBox(height: 10),
              DashboardSurfaceCard(
                outlined: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '身体与训练偏好',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '性别',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'unknown', child: Text('未知')),
                        DropdownMenuItem(value: 'male', child: Text('男')),
                        DropdownMenuItem(value: 'female', child: Text('女')),
                        DropdownMenuItem(value: 'other', child: Text('其他')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _buildDashboardInputDecoration(
                        labelText: '身高（cm）',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}'),
                        ),
                      ],
                      validator: (value) => _validateDoubleInRange(
                        value,
                        label: '身高',
                        min: 80,
                        max: 250,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _buildDashboardInputDecoration(
                        labelText: '体重（kg）',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}'),
                        ),
                      ],
                      validator: (value) => _validateDoubleInRange(
                        value,
                        label: '体重',
                        min: 20,
                        max: 300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minutesCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: _buildDashboardInputDecoration(
                        labelText: '每日训练目标（分钟）',
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => _validateIntInRange(
                        value,
                        label: '每日训练目标',
                        min: 5,
                        max: 300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _equipmentsCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _buildDashboardInputDecoration(
                        labelText: '器材（逗号分隔）',
                        hintText: '如：瑜伽垫,哑铃',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goalCtrl,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '锻炼目的',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '备注（伤病/限制/偏好）',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trainingHistoryCtrl,
                      maxLines: 2,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '最近7天历史训练摘要',
                        hintText: '例如：最近一周完成了2次慢跑和1次力量训练',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          '是否有基础疾病',
                          style: TextStyle(
                            fontSize: 15,
                            color: _DashboardColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _hasDisease,
                          onChanged: (value) =>
                              setState(() => _hasDisease = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DashboardSurfaceCard(
                outlined: true,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: DashboardTokens.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasDisease ? '已标记基础疾病，系统会降低训练强度。' : '未标记基础疾病，按标准训练强度生成计划。',
                        style: const TextStyle(
                          fontSize: 13,
                          color: DashboardTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveProfile,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _DashboardColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    '保存基本信息',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiSettingsPage extends StatefulWidget {
  const _ApiSettingsPage({
    required this.initialSettings,
    required this.snapshotStore,
  });

  final ApiSettings initialSettings;
  final LocalSnapshotStore snapshotStore;

  @override
  State<_ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<_ApiSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _primaryBaseUrlCtrl;
  late final TextEditingController _fallbackBaseUrlCtrl;
  late String _preferredEndpoint;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: widget.initialSettings.apiKey);
    _primaryBaseUrlCtrl = TextEditingController(
      text: widget.initialSettings.primaryBaseUrl,
    );
    _fallbackBaseUrlCtrl = TextEditingController(
      text: widget.initialSettings.fallbackBaseUrl,
    );
    _preferredEndpoint = widget.initialSettings.preferredEndpoint;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _primaryBaseUrlCtrl.dispose();
    _fallbackBaseUrlCtrl.dispose();
    super.dispose();
  }

  String _normalizeUrl(String value, String fallback) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return fallback;
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String? _validateBaseUrl(
    String? value, {
    required String label,
    required String fallback,
  }) {
    final normalized = _normalizeUrl(value ?? '', fallback);
    final uri = Uri.tryParse(normalized);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!valid) {
      return '$label格式不正确';
    }
    return null;
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      ApiSettings(
        apiKey: _apiKeyCtrl.text.trim(),
        primaryBaseUrl: _normalizeUrl(
          _primaryBaseUrlCtrl.text,
          'https://codex-api.packycode.com/v1',
        ),
        fallbackBaseUrl: _normalizeUrl(
          _fallbackBaseUrlCtrl.text,
          'https://api.deepseek.com',
        ),
        preferredEndpoint: _preferredEndpoint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKey = _apiKeyCtrl.text.trim().isNotEmpty;
    final activeEndpoint =
        _preferredEndpoint == 'fallback' ? '回退线路' : '主线路';

    return DashboardTabPageScaffold(
      title: 'API 设置',
      showAppBar: false,
      selectedTab: DashboardTab.profile,
      useSafeArea: false,
      backgroundColor: _DashboardColors.pageBackground,
      snapshotStore: widget.snapshotStore,
      allowReselectCurrentTab: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const DashboardPageHeader(
                title: 'API 设置',
                subtitle: '延续首页四标签规范，统一连接参数与优先策略。',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SettingsOverviewTile(
                      icon: Icons.hub_outlined,
                      title: '当前通道',
                      value: activeEndpoint,
                      iconBackground: DashboardTokens.warningSoft,
                      iconColor: _DashboardColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SettingsOverviewTile(
                      icon: hasApiKey
                          ? Icons.verified_outlined
                          : Icons.key_off_outlined,
                      title: '密钥状态',
                      value: hasApiKey ? '已配置' : '待配置',
                      iconBackground: hasApiKey
                          ? DashboardTokens.successSoft
                          : DashboardTokens.neutralSoft,
                      iconColor: hasApiKey
                          ? _DashboardColors.success
                          : _DashboardColors.textMuted,
                      valueColor: hasApiKey
                          ? _DashboardColors.success
                          : _DashboardColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DashboardSurfaceCard(
                outlined: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '连接参数',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _apiKeyCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _buildDashboardInputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _primaryBaseUrlCtrl,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '主 Base URL',
                        hintText: 'https://codex-api.packycode.com/v1',
                      ),
                      validator: (value) => _validateBaseUrl(
                        value,
                        label: '主 Base URL',
                        fallback: 'https://codex-api.packycode.com/v1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fallbackBaseUrlCtrl,
                      decoration: _buildDashboardInputDecoration(
                        labelText: '回退 Base URL',
                        hintText: 'https://api.deepseek.com',
                      ),
                      validator: (value) => _validateBaseUrl(
                        value,
                        label: '回退 Base URL',
                        fallback: 'https://api.deepseek.com',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DashboardSurfaceCard(
                outlined: true,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '优先使用',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DashboardSegmentedTabSelector<String>(
                      items: const [
                        DashboardSegmentedTabItem<String>(
                          value: 'primary',
                          label: '主 Base URL',
                        ),
                        DashboardSegmentedTabItem<String>(
                          value: 'fallback',
                          label: '回退 Base URL',
                        ),
                      ],
                      selectedValue: _preferredEndpoint,
                      onChanged: (value) =>
                          setState(() => _preferredEndpoint = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const DashboardSurfaceCard(
                outlined: true,
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: DashboardTokens.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '优先线路会在生成计划与语音播报时生效，建议保持主线路可用并配置回退线路。',
                        style: TextStyle(
                          fontSize: 13,
                          color: DashboardTokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSettings,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _DashboardColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DashboardTokens.buttonRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    '保存设置',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenLoadingPage extends StatelessWidget {
  const _FullscreenLoadingPage();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: DashboardTokens.textPrimary.withValues(alpha: 0.24),
        child: Center(
          child: SizedBox(
            width: 260,
            child: DashboardSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              outlined: true,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: _DashboardColors.accent,
                    size: 24,
                  ),
                  SizedBox(height: 10),
                  CircularProgressIndicator(color: _DashboardColors.accent),
                  SizedBox(height: 12),
                  Text(
                    '正在生成计划，请稍候...',
                    style: TextStyle(
                      fontSize: 14,
                      color: _DashboardColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
