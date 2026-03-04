import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/screens/training_session_page.dart';
import 'package:fitness_flutter_app/src/services/voice_broadcast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auto goes next after timer completes', (tester) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '开合跳',
          durationMinutes: 0,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持匀速呼吸',
        ),
        TrainingItem(
          title: '深蹲',
          durationMinutes: 0,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '膝盖朝脚尖方向',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    final nextButton = tester.widget<FilledButton>(
      find.byType(FilledButton).last,
    );
    expect(nextButton.onPressed, isNull);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始'),
    );
    startButton.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 4200));
    await tester.pump();
    expect(find.text('第 2 项'), findsOneWidget);
    expect(
      voice.messages.where((m) => m.contains('第 2 项，训练环节')).length >= 2,
      isTrue,
    );
  });

  testWidgets('rest step supports quick skip to next item', (tester) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '休息调整',
          type: 'rest',
          durationMinutes: 1,
          intensity: 'low',
          equipment: '无器械',
          instructions: '放松呼吸',
        ),
        TrainingItem(
          title: '平板支撑',
          durationMinutes: 1,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '保持核心稳定',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    final skipFinder = find.text('跳过休息并进入下一项');
    expect(skipFinder, findsOneWidget);
    await tester.ensureVisible(skipFinder);
    await tester.tap(skipFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('第 2 项'), findsOneWidget);
  });

  testWidgets('speaks intro, completion and next item broadcast', (
    tester,
  ) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '开合跳',
          durationMinutes: 0,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持匀速呼吸',
        ),
        TrainingItem(
          title: '高抬腿',
          durationMinutes: 0,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '抬高膝盖，核心稳定',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始'),
    );
    startButton.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 4200));

    expect(
      voice.messages.where((m) => m.contains('第 1 项，训练环节')).isNotEmpty,
      isTrue,
    );
    expect(
      voice.messages.where((m) => m.contains('第 1 项已完成')).isNotEmpty,
      isTrue,
    );
    expect(
      voice.messages.where((m) => m.contains('第 2 项，训练环节')).isNotEmpty,
      isTrue,
    );
  });

  testWidgets('shows next-step hint and final-step completion hint', (
    tester,
  ) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '开合跳',
          durationMinutes: 0,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持匀速呼吸',
        ),
        TrainingItem(
          title: '深蹲',
          durationMinutes: 0,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '膝盖朝脚尖方向',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    expect(find.textContaining('下一项：深蹲'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始'),
    );
    startButton.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 4200));

    expect(find.text('当前是最后一项，完成后即可打卡成功。'), findsOneWidget);
  });

  testWidgets('updates remaining duration while timer is running', (
    tester,
  ) async {
    final voice = _FakeVoiceBroadcastService();
    final fixedNow = DateTime(2026, 2, 27, 8, 0);
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '慢跑热身',
          durationMinutes: 3,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持均匀呼吸',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(
          plan: plan,
          voiceService: voice,
          now: () => fixedNow,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('剩余 3 分钟'), findsOneWidget);
    expect(find.text('预计完成 08:03'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始'),
    );
    startButton.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 62));

    expect(find.textContaining('剩余 2 分钟'), findsOneWidget);
    expect(find.text('预计完成 08:01'), findsOneWidget);
  });

  testWidgets('disables previous action while current timer is running', (
    tester,
  ) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '波比跳',
          durationMinutes: 0,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '保持节奏',
        ),
        TrainingItem(
          title: '高抬腿',
          durationMinutes: 1,
          intensity: 'medium',
          equipment: '无器械',
          instructions: '核心收紧',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始'),
    );
    startButton.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 4200));
    await tester.pump();
    expect(find.text('第 2 项'), findsOneWidget);
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '暂停'), findsOneWidget);

    final previousButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '上一项'),
    );
    expect(previousButton.onPressed, isNull);
    expect(find.text('当前计时进行中，先暂停或完成本项再切换动作。'), findsOneWidget);
  });

  testWidgets('supports replaying current voice guidance manually', (
    tester,
  ) async {
    final voice = _FakeVoiceBroadcastService();
    final plan = TrainingPlan(
      items: const [
        TrainingItem(
          title: '慢跑热身',
          durationMinutes: 1,
          intensity: 'low',
          equipment: '无器械',
          instructions: '保持均匀呼吸',
        ),
      ],
      components: const [],
      dietAdvice: '均衡饮食',
      hydrationAdvice: '分次补水',
      warning: '不适即停',
      hydrationTargetMl: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSessionPage(plan: plan, voiceService: voice),
      ),
    );
    await tester.pump();

    final beforeCount = voice.messages.length;
    final replayButton = find.widgetWithText(OutlinedButton, '重播语音指导');
    await tester.dragUntilVisible(
      replayButton,
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.tap(replayButton);
    await tester.pump();

    expect(voice.messages.length, greaterThan(beforeCount));
    expect(find.text('已重播当前动作语音指导'), findsOneWidget);
  });
}

class _FakeVoiceBroadcastService implements VoiceBroadcastService {
  final List<String> messages = <String>[];
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> speak(String message, {bool interrupt = true}) async {
    messages.add(message);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
