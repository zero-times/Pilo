import 'dart:convert';

import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/services/deepseek_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('payload includes completed training history', () async {
    late Map<String, dynamic> capturedBody;

    final mockClient = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.headers['Authorization'], 'Bearer test-key');

      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'training_items': [
                    {
                      'title': '跳绳',
                      'duration_minutes': 30,
                      'intensity': 'medium',
                      'equipment': '跳绳',
                      'instructions': '每组 2 分钟，间歇 30 秒',
                    },
                  ],
                  'components': [
                    {
                      'component': 'timer_button',
                      'props': {'duration_seconds': 720},
                    },
                  ],
                  'diet_advice': '训练后补充蛋白质。',
                  'hydration_advice': '全程分次补水。',
                  'hydration_target_ml': 2200,
                  'warning': '出现不适立即停止训练。',
                }),
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = DeepSeekService(client: mockClient, apiKey: 'test-key');

    final completedHistory = [
      DailyCheckinRecord(
        date: '2026-02-25',
        planDigest: const PlanDigest(
          itemCount: 3,
          totalTargetSeconds: 1800,
          restTargetSeconds: 300,
        ),
        itemRecords: [
          TrainingItemRecord(
            itemIndex: 0,
            title: '快走',
            durationTargetSec: 600,
            actualElapsedSec: 620,
            startedAt: DateTime(2026, 2, 25, 9),
            completedAt: DateTime(2026, 2, 25, 9, 10),
          ),
        ],
        completed: true,
      ),
    ];

    final plan = await service.generateTrainingPlan(
      profile: const UserProfile(
        heightCm: 170,
        weightKg: 65,
        hasDisease: false,
        exerciseMinutes: 30,
        equipments: ['瑜伽垫', '哑铃'],
      ),
      metrics: DailyHealthMetrics(
        weightKg: 65,
        systolic: 120,
        diastolic: 80,
        date: DateTime(2026, 2, 26),
      ),
      metricHistory: [
        DailyHealthSnapshot(
          date: DateTime(2026, 2, 24),
          weightKg: 64.5,
          systolic: 118,
          diastolic: 78,
        ),
      ],
      completedTrainingHistory: completedHistory,
      contract: const ComponentContract(),
      trainingHistorySummary: '最近一周完成2次慢跑和1次力量。',
    );

    expect(plan.items.single.title, '跳绳');
    expect(plan.totalDurationSeconds, 1800);

    final messages = capturedBody['messages'] as List<dynamic>;
    final userPayload =
        jsonDecode((messages[1] as Map<String, dynamic>)['content'] as String)
            as Map<String, dynamic>;

    final history = userPayload['completed_training_history'] as List<dynamic>;
    expect(history, hasLength(1));
    final first = history.first as Map<String, dynamic>;
    expect(first['date'], '2026-02-25');
    expect(first['completed'], isTrue);
    expect(userPayload['completed_training_summary'], isA<String>());
    expect(userPayload['total_minutes_includes_rest'], isTrue);
  });

  test('falls back when primary endpoint fails', () async {
    final requestedHosts = <String>[];

    final mockClient = MockClient((request) async {
      requestedHosts.add(request.url.host);
      if (request.url.host == 'primary.local') {
        return http.Response('primary failed', 500);
      }
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'training_items': [
                    {
                      'title': '慢跑',
                      'duration_minutes': 30,
                      'intensity': 'low',
                      'equipment': '跑鞋',
                      'instructions': '心率保持平稳',
                    },
                  ],
                  'components': const [],
                  'diet_advice': '均衡饮食',
                  'hydration_advice': '补水',
                  'hydration_target_ml': 2000,
                  'warning': '注意呼吸',
                }),
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = DeepSeekService(
      client: mockClient,
      apiKey: 'test-key',
      primaryBaseUrl: 'https://primary.local/v1',
      fallbackBaseUrl: 'https://fallback.local/v1',
    );

    final plan = await service.generateTrainingPlan(
      profile: const UserProfile(
        heightCm: 170,
        weightKg: 65,
        hasDisease: false,
        exerciseMinutes: 30,
        equipments: ['瑜伽垫'],
      ),
      metrics: DailyHealthMetrics(
        weightKg: 65,
        systolic: 120,
        diastolic: 80,
        date: DateTime(2026, 2, 26),
      ),
      metricHistory: const [],
      completedTrainingHistory: const [],
      contract: const ComponentContract(),
      trainingHistorySummary: '',
    );

    expect(plan.totalDurationSeconds, 1800);
    expect(
      requestedHosts,
      containsAllInOrder(['primary.local', 'fallback.local']),
    );
  });

  test('throws combined error when primary and fallback both fail', () async {
    final mockClient = MockClient((request) async {
      return http.Response('server down', 503);
    });

    final service = DeepSeekService(
      client: mockClient,
      apiKey: 'test-key',
      primaryBaseUrl: 'https://primary.local/v1',
      fallbackBaseUrl: 'https://fallback.local/v1',
    );

    expect(
      () => service.generateTrainingPlan(
        profile: const UserProfile(
          heightCm: 170,
          weightKg: 65,
          hasDisease: false,
          exerciseMinutes: 30,
          equipments: ['瑜伽垫'],
        ),
        metrics: DailyHealthMetrics(
          weightKg: 65,
          systolic: 120,
          diastolic: 80,
          date: DateTime(2026, 2, 26),
        ),
        metricHistory: const [],
        completedTrainingHistory: const [],
        contract: const ComponentContract(),
        trainingHistorySummary: '',
      ),
      throwsA(
        isA<DeepSeekException>().having(
          (e) => e.message,
          'message',
          allOf(contains('主端点失败'), contains('回退失败')),
        ),
      ),
    );
  });
}
