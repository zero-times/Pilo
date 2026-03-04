import 'package:fitness_flutter_app/src/widgets/animated_timer_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows countdown in mm:ss format', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedTimerButton(duration: Duration(seconds: 65)),
        ),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('01:03'), findsOneWidget);
  });

  testWidgets(
    'animated timer button transitions idle -> running -> paused -> running -> completed',
    (tester) async {
      TimerButtonStatus? latestStatus;
      final ticks = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTimerButton(
              duration: const Duration(seconds: 2),
              onTick: ticks.add,
              onStatusChanged: (status) => latestStatus = status,
            ),
          ),
        ),
      );

      expect(find.text('开始'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(latestStatus, TimerButtonStatus.running);
      expect(find.text('暂停'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(latestStatus, TimerButtonStatus.paused);
      expect(find.text('继续'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(latestStatus, TimerButtonStatus.running);

      await tester.pump(const Duration(seconds: 3));
      expect(latestStatus, TimerButtonStatus.completed);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);
      expect(ticks, isNotEmpty);
      expect(ticks.last, 0);
    },
  );
}
