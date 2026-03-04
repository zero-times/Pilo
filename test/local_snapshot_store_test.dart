import 'dart:io';

import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/services/local_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local snapshot store can save and load snapshot', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'fitness-store-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = LocalSnapshotStore(
      documentsDirectoryProvider: () async => tempDir,
    );

    final snapshot = AppSnapshot.empty().copyWith(
      userProfile: const UserProfile(
        heightCm: 171,
        weightKg: 64,
        hasDisease: false,
        exerciseMinutes: 30,
        equipments: ['哑铃'],
      ),
      latestPlan: const TrainingPlan(
        items: [
          TrainingItem(
            title: '俯卧撑',
            durationMinutes: 2,
            intensity: 'high',
            equipment: '无器械',
            instructions: '核心收紧',
          ),
        ],
        components: [],
        dietAdvice: '补充蛋白质',
        hydrationAdvice: '分次喝水',
        warning: '不适立即停止',
        hydrationTargetMl: 2000,
      ),
    );

    await store.save(snapshot);
    final loaded = await store.load();
    expect(loaded.userProfile?.heightCm, 171);
    expect(loaded.latestPlan?.items.first.title, '俯卧撑');
  });

  test('load invalid json falls back to empty snapshot', () async {
    final tempDir = await Directory.systemTemp.createTemp('fitness-store-bad-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}/fitness_snapshot_v1.json');
    await file.writeAsString('{bad json}');

    final store = LocalSnapshotStore(
      documentsDirectoryProvider: () async => tempDir,
    );
    final loaded = await store.load();
    expect(loaded.latestPlan, isNull);
    expect(loaded.checkinHistory, isEmpty);
  });

  test('add plan history is idempotent and favorite toggle works', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'fitness-store-history-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = LocalSnapshotStore(
      documentsDirectoryProvider: () async => tempDir,
    );
    final plan = HistoricalTrainingPlan(
      id: 'same-id',
      createdAt: DateTime.utc(2026, 2, 26, 9),
      source: 'generated',
      planVersion: 'v1',
      plan: const TrainingPlan(
        items: [
          TrainingItem(
            title: '深蹲',
            durationMinutes: 10,
            intensity: 'medium',
            equipment: '无器械',
            instructions: '注意膝盖方向',
          ),
        ],
        components: [],
        dietAdvice: '均衡',
        hydrationAdvice: '补水',
        warning: '注意姿势',
        hydrationTargetMl: 2000,
      ),
    );
    await store.addPlanToHistory(plan);
    await store.addPlanToHistory(plan);

    var history = await store.loadPlanHistory();
    expect(history, hasLength(1));
    expect(history.first.isFavorite, isFalse);

    await store.toggleFavoritePlan('same-id', true);
    history = await store.loadPlanHistory();
    expect(history.first.isFavorite, isTrue);
  });

  test('rebuild achievement streak resets after break', () async {
    final fixedNow = DateTime(2026, 2, 26, 12);
    final store = LocalSnapshotStore(
      documentsDirectoryProvider: () async => Directory.systemTemp,
      now: () => fixedNow,
    );

    final continuous = store.rebuildAchievementState(
      checkins: const [
        DailyCheckinRecord(
          date: '2026-02-22',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-23',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-24',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-25',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-26',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
      ],
    );
    expect(continuous.currentStreakDays, 5);

    final broken = store.rebuildAchievementState(
      checkins: const [
        DailyCheckinRecord(
          date: '2026-02-22',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-23',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
        DailyCheckinRecord(
          date: '2026-02-24',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 60),
          itemRecords: [],
          completed: true,
        ),
      ],
    );
    expect(broken.currentStreakDays, 0);
    expect(broken.bestStreakDays, 3);
  });
}
