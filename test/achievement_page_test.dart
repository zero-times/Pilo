import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/screens/achievement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('achievement page renders spark statuses', (tester) async {
    const state = AchievementState(
      currentStreakDays: 2,
      bestStreakDays: 5,
      lastCheckinDate: '2026-02-26',
      sparkTimeline: [
        SparkDayStatus(
          date: '2026-02-24',
          checkedIn: false,
          isStreakDay: false,
        ),
        SparkDayStatus(date: '2026-02-25', checkedIn: true, isStreakDay: true),
        SparkDayStatus(date: '2026-02-26', checkedIn: true, isStreakDay: true),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: AchievementPage(achievementState: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('连续 2 天'), findsOneWidget);
    expect(find.byKey(const Key('spark-2026-02-24-off')), findsOneWidget);
    expect(find.byKey(const Key('spark-2026-02-25-on')), findsOneWidget);
    expect(find.byKey(const Key('spark-2026-02-26-on')), findsOneWidget);
  });
}
