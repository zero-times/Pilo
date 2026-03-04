import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app snapshot json roundtrip keeps nested fields', () {
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      updatedAt: DateTime.utc(2026, 2, 26, 0, 0, 0),
      userProfile: const UserProfile(
        heightCm: 172,
        weightKg: 68.5,
        hasDisease: true,
        exerciseMinutes: 35,
        equipments: ['弹力带'],
      ),
      latestPlan: const TrainingPlan(
        items: [
          TrainingItem(
            title: '慢跑',
            durationMinutes: 20,
            intensity: 'medium',
            equipment: '跑步机',
            instructions: '匀速跑',
          ),
        ],
        components: [
          TrainingComponentConfig(
            component: 'timer_button',
            props: {'duration_seconds': 1200},
          ),
        ],
        dietAdvice: '多吃蛋白质',
        hydrationAdvice: '分次补水',
        warning: '不适立即停止',
        hydrationTargetMl: 2100,
      ),
      checkinHistory: const [
        DailyCheckinRecord(
          date: '2026-02-26',
          planDigest: PlanDigest(itemCount: 1, totalTargetSeconds: 1200),
          itemRecords: [
            TrainingItemRecord(
              itemIndex: 0,
              title: '慢跑',
              durationTargetSec: 1200,
              actualElapsedSec: 1200,
            ),
          ],
          completed: true,
        ),
      ],
      apiSettings: const ApiSettings(),
      planHistory: [
        HistoricalTrainingPlan(
          id: 'plan-1',
          createdAt: DateTime.utc(2026, 2, 26, 1, 0, 0),
          source: 'generated',
          planVersion: 'v1',
          plan: const TrainingPlan(
            items: [
              TrainingItem(
                title: '开合跳',
                durationMinutes: 10,
                intensity: 'medium',
                equipment: '无器械',
                instructions: '保持节奏',
              ),
            ],
            components: [],
            dietAdvice: '均衡饮食',
            hydrationAdvice: '多次饮水',
            warning: '注意膝盖',
            hydrationTargetMl: 2000,
          ),
          isFavorite: true,
          timesTrained: 2,
        ),
      ],
      achievementState: const AchievementState(
        currentStreakDays: 3,
        bestStreakDays: 5,
        lastCheckinDate: '2026-02-26',
        sparkTimeline: [
          SparkDayStatus(
            date: '2026-02-24',
            checkedIn: true,
            isStreakDay: true,
          ),
          SparkDayStatus(
            date: '2026-02-25',
            checkedIn: true,
            isStreakDay: true,
          ),
          SparkDayStatus(
            date: '2026-02-26',
            checkedIn: true,
            isStreakDay: true,
          ),
        ],
      ),
    );

    final parsed = AppSnapshot.fromJson(snapshot.toJson());
    expect(parsed.schemaVersion, 1);
    expect(parsed.userProfile?.hasDisease, isTrue);
    expect(parsed.latestPlan?.items.single.title, '慢跑');
    expect(
      parsed.checkinHistory.single.itemRecords.single.actualElapsedSec,
      1200,
    );
    expect(parsed.planHistory.single.isFavorite, isTrue);
    expect(parsed.achievementState.currentStreakDays, 3);
  });

  test('old snapshot json can still be parsed with defaults', () {
    final oldJson = {
      'schema_version': 1,
      'updated_at': DateTime.utc(2026, 2, 26).toIso8601String(),
      'user_profile': const UserProfile(
        heightCm: 172,
        weightKg: 68.5,
        hasDisease: false,
        exerciseMinutes: 30,
        equipments: ['弹力带'],
      ).toJson(),
      'latest_plan': const TrainingPlan(
        items: [],
        components: [],
        dietAdvice: '',
        hydrationAdvice: '',
        warning: '',
        hydrationTargetMl: 2000,
      ).toJson(),
      'checkin_history': const [],
      'api_settings': const ApiSettings().toJson(),
    };
    final parsed = AppSnapshot.fromJson(oldJson);
    expect(parsed.planHistory, isEmpty);
    expect(parsed.achievementState.currentStreakDays, 0);
  });
}
