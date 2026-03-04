import 'dart:io';

import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/screens/training_planner_page.dart';
import 'package:fitness_flutter_app/src/services/deepseek_service.dart';
import 'package:fitness_flutter_app/src/services/local_snapshot_store.dart';
import 'package:fitness_flutter_app/src/services/snapshot_portability_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

Finder _tabFinder(String label) => find.byKey(ValueKey('dashboard-tab-$label'));

Future<void> _setIPhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('renders four-tab dashboard and default empty action', (
    tester,
  ) async {
    await _setIPhoneSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlannerPage(snapshotStore: _MemorySnapshotStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('计划'), findsWidgets);
    expect(find.text('统计'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('创建计划'), findsOneWidget);
  });

  testWidgets('switches tabs and shows page-specific content', (tester) async {
    await _setIPhoneSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlannerPage(snapshotStore: _MemorySnapshotStore()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tabFinder('计划'));
    await tester.pumpAndSettle();
    expect(find.text('本周计划'), findsOneWidget);

    await tester.tap(_tabFinder('统计'));
    await tester.pumpAndSettle();
    expect(find.text('训练趋势'), findsOneWidget);

    await tester.tap(_tabFinder('我的'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-action-privacy')),
      findsOneWidget,
    );
  });

  testWidgets('planner passes completed checkin history to service', (
    tester,
  ) async {
    await _setIPhoneSurface(tester);
    final completedRecord = DailyCheckinRecord(
      date: '2026-02-25',
      planDigest: const PlanDigest(
        itemCount: 2,
        totalTargetSeconds: 1200,
        restTargetSeconds: 300,
      ),
      itemRecords: const [],
      completed: true,
    );
    final snapshotStore = _MemorySnapshotStore(
      snapshot: AppSnapshot.empty().copyWith(checkinHistory: [completedRecord]),
    );
    final service = _CapturingDeepSeekService();

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlannerPage(
          snapshotStore: snapshotStore,
          deepSeekService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建计划'));
    await tester.pumpAndSettle();
    final submitButton = find.widgetWithText(FilledButton, '生成今日打卡计划');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.lastCompletedHistory.length, 1);
    expect(service.lastCompletedHistory.first.date, '2026-02-25');
    expect(find.text('冲刺 0/1'), findsOneWidget);
  });

  testWidgets('planner persists generated plan to local snapshot', (
    tester,
  ) async {
    await _setIPhoneSurface(tester);
    final snapshotStore = _MemorySnapshotStore();
    final service = _CapturingDeepSeekService();

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlannerPage(
          snapshotStore: snapshotStore,
          deepSeekService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建计划'));
    await tester.pumpAndSettle();
    final submitButton = find.widgetWithText(FilledButton, '生成今日打卡计划');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pumpAndSettle();

    final snapshot = await snapshotStore.load();
    expect(snapshot.latestPlan, isNotNull);
    expect(snapshot.latestPlan?.items.first.title, '慢跑');
    expect(snapshot.planHistory.length, 1);
    expect(snapshot.planVersion, isNotNull);
  });

  testWidgets('stats range switch updates summary hint text', (tester) async {
    await _setIPhoneSurface(tester);
    final snapshotStore = _MemorySnapshotStore(
      snapshot: AppSnapshot.empty().copyWith(
        checkinHistory: [
          const DailyCheckinRecord(
            date: '2026-02-26',
            planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 1800),
            itemRecords: [],
            completed: true,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TrainingPlannerPage(snapshotStore: snapshotStore)),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tabFinder('统计'));
    await tester.pumpAndSettle();
    expect(find.textContaining('近 7 天训练完成率'), findsOneWidget);

    await tester.tap(find.text('30天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('近 30 天训练完成率'), findsOneWidget);
  });

  testWidgets('profile routes privacy to API settings and export action', (
    tester,
  ) async {
    await _setIPhoneSurface(tester);
    final snapshotStore = _MemorySnapshotStore();
    final portability = _SpyPortabilityService(snapshotStore: snapshotStore);

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlannerPage(
          snapshotStore: snapshotStore,
          portabilityService: portability,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tabFinder('我的'));
    await tester.pumpAndSettle();

    final privacyAction = find.byKey(const ValueKey('profile-action-privacy'));
    await tester.ensureVisible(privacyAction);
    await tester.tap(privacyAction);
    await tester.pumpAndSettle();
    expect(find.text('API 设置'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'sk-test');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://example.com/v1/',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'https://fallback.example.com/',
    );
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();

    final updatedSnapshot = await snapshotStore.load();
    expect(updatedSnapshot.apiSettings.apiKey, 'sk-test');
    expect(updatedSnapshot.apiSettings.primaryBaseUrl, 'https://example.com/v1');
    expect(
      updatedSnapshot.apiSettings.fallbackBaseUrl,
      'https://fallback.example.com',
    );

    final exportAction = find.byKey(const ValueKey('profile-action-export'));
    await tester.ensureVisible(exportAction);
    await tester.tap(exportAction);
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && !portability.shareCalled; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(portability.exportCalled, isTrue);
    expect(portability.shareCalled, isTrue);
  });

  testWidgets('profile basic info entry saves user profile', (tester) async {
    await _setIPhoneSurface(tester);
    final snapshotStore = _MemorySnapshotStore();

    await tester.pumpWidget(
      MaterialApp(home: TrainingPlannerPage(snapshotStore: snapshotStore)),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tabFinder('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-basic-info-entry')));
    await tester.pumpAndSettle();
    expect(find.text('基本信息设置'), findsOneWidget);

    await tester.tap(find.text('保存基本信息'));
    await tester.pumpAndSettle();

    final snapshot = await snapshotStore.load();
    expect(snapshot.userProfile, isNotNull);
    expect(snapshot.userProfile?.heightCm, 170);
    expect(snapshot.userProfile?.weightKg, 65);
    expect(snapshot.userProfile?.exerciseMinutes, 30);
  });

  testWidgets('logout clears local snapshot and returns to empty state', (
    tester,
  ) async {
    await _setIPhoneSurface(tester);
    final snapshotStore = _MemorySnapshotStore(
      snapshot: AppSnapshot.empty().copyWith(
        latestPlan: const TrainingPlan(
          items: [
            TrainingItem(
              title: '深蹲',
              durationMinutes: 10,
              intensity: 'medium',
              equipment: '无器械',
              instructions: '保持节奏',
            ),
          ],
          components: [],
          dietAdvice: '',
          hydrationAdvice: '',
          warning: '',
          hydrationTargetMl: 2000,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TrainingPlannerPage(snapshotStore: snapshotStore)),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tabFinder('我的'));
    await tester.pumpAndSettle();
    final logoutButton = find.byKey(const ValueKey('profile-logout-button'));
    await tester.ensureVisible(logoutButton);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();

    final snapshot = await snapshotStore.load();
    expect(snapshot.latestPlan, isNull);
    expect(find.text('创建计划'), findsOneWidget);
  });
}

class _MemorySnapshotStore extends LocalSnapshotStore {
  _MemorySnapshotStore({AppSnapshot? snapshot})
    : _snapshot = snapshot ?? AppSnapshot.empty(),
      super(documentsDirectoryProvider: _unusedDirectory);

  AppSnapshot _snapshot;

  static Future<Directory> _unusedDirectory() async {
    throw UnimplementedError('not used in widget tests');
  }

  @override
  Future<AppSnapshot> load() async => _snapshot;

  @override
  Future<void> save(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class _CapturingDeepSeekService extends DeepSeekService {
  _CapturingDeepSeekService()
    : super(
        apiKey: 'test-key',
        client: MockClient((request) async {
          throw UnimplementedError('network should not be called in this test');
        }),
      );

  List<DailyCheckinRecord> lastCompletedHistory = const [];

  @override
  Future<TrainingPlan> generateTrainingPlan({
    required UserProfile profile,
    required DailyHealthMetrics metrics,
    required List<DailyHealthSnapshot> metricHistory,
    required List<DailyCheckinRecord> completedTrainingHistory,
    required ComponentContract contract,
    required String trainingHistorySummary,
    bool totalMinutesIncludesRest = true,
  }) async {
    lastCompletedHistory = completedTrainingHistory;
    return const TrainingPlan(
      items: [
        TrainingItem(
          title: '慢跑',
          durationMinutes: 30,
          intensity: 'low',
          equipment: '跑鞋',
          instructions: '保持匀速',
        ),
      ],
      components: [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '按需补水',
      warning: '注意心率',
      hydrationTargetMl: 2000,
    );
  }
}

class _SpyPortabilityService extends SnapshotPortabilityService {
  _SpyPortabilityService({required LocalSnapshotStore snapshotStore})
    : super(
        snapshotStore: snapshotStore,
        tempDirectoryProvider: () async => Directory.systemTemp,
        importFilePicker: () async => null,
      );

  bool exportCalled = false;
  bool shareCalled = false;

  @override
  Future<File> exportSnapshotFile(AppSnapshot snapshot) async {
    exportCalled = true;
    return File('/tmp/fitness-test-export.json');
  }

  @override
  Future<void> shareExportedFile(File file) async {
    shareCalled = true;
  }
}
