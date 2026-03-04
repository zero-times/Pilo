import 'dart:io';

import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/screens/plan_history_page.dart';
import 'package:fitness_flutter_app/src/services/local_snapshot_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan history filters favorites and history', (tester) async {
    final store = _FakeHistoryStore(
      plans: [
        _buildPlan('fav-1', true, '收藏计划'),
        _buildPlan('his-1', false, '历史计划'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: PlanHistoryPage(snapshotStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏计划'), findsOneWidget);
    expect(find.text('历史计划'), findsNothing);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();

    expect(find.text('历史计划'), findsOneWidget);
  });

  testWidgets('start training marks usage without api calls', (tester) async {
    final store = _FakeHistoryStore(plans: [_buildPlan('run-1', true, '执行计划')]);

    await tester.pumpWidget(
      MaterialApp(home: PlanHistoryPage(snapshotStore: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '开始训练').first);
    await tester.pumpAndSettle();

    expect(store.markTrainedCalls, 1);
  });
}

HistoricalTrainingPlan _buildPlan(String id, bool favorite, String title) {
  return HistoricalTrainingPlan(
    id: id,
    createdAt: DateTime.utc(2026, 2, 26, 10),
    source: 'generated',
    planVersion: 'v1',
    plan: TrainingPlan(
      items: [
        TrainingItem(
          title: title,
          durationMinutes: 10,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持呼吸',
        ),
      ],
      components: const [],
      dietAdvice: '',
      hydrationAdvice: '',
      warning: '',
      hydrationTargetMl: 2000,
    ),
    isFavorite: favorite,
  );
}

class _FakeHistoryStore extends LocalSnapshotStore {
  _FakeHistoryStore({required List<HistoricalTrainingPlan> plans})
    : _plans = plans,
      super(documentsDirectoryProvider: _unusedDirectory);

  List<HistoricalTrainingPlan> _plans;
  int markTrainedCalls = 0;

  static Future<Directory> _unusedDirectory() async {
    throw UnimplementedError('not used in widget tests');
  }

  @override
  Future<List<HistoricalTrainingPlan>> loadPlanHistory() async =>
      List<HistoricalTrainingPlan>.from(_plans);

  @override
  Future<void> toggleFavoritePlan(String planId, bool favorite) async {
    _plans = _plans
        .map(
          (entry) =>
              entry.id == planId ? entry.copyWith(isFavorite: favorite) : entry,
        )
        .toList(growable: false);
  }

  @override
  Future<void> markPlanTrained(String planId, DateTime trainedAt) async {
    markTrainedCalls += 1;
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot.empty();
}
