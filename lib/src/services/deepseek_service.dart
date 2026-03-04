import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/training_models.dart';

class DeepSeekService {
  DeepSeekService({
    http.Client? client,
    String? apiKey,
    String? primaryBaseUrl,
    String? fallbackBaseUrl,
    Duration? requestTimeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? const String.fromEnvironment('DEEPSEEK_API_KEY'),
       _primaryBaseUrl = primaryBaseUrl ?? 'https://codex-api.packycode.com/v1',
       _fallbackBaseUrl = fallbackBaseUrl ?? 'https://api.deepseek.com',
       _requestTimeout = requestTimeout ?? const Duration(seconds: 45);

  static const String _chatCompletionsPath = '/chat/completions';
  static const String _model = 'gpt-5.3';

  final http.Client _client;
  final String _apiKey;
  final String _primaryBaseUrl;
  final String _fallbackBaseUrl;
  final Duration _requestTimeout;

  Future<TrainingPlan> generateTrainingPlan({
    required UserProfile profile,
    required DailyHealthMetrics metrics,
    required List<DailyHealthSnapshot> metricHistory,
    required List<DailyCheckinRecord> completedTrainingHistory,
    required ComponentContract contract,
    required String trainingHistorySummary,
    bool totalMinutesIncludesRest = true,
  }) async {
    if (_apiKey.isEmpty) {
      throw const DeepSeekException(
        '未设置 DEEPSEEK_API_KEY，请使用 --dart-define 传入。',
      );
    }

    final hasHistory = metricHistory.isNotEmpty;
    final completedHistory = _compactCompletedHistory(completedTrainingHistory);
    final payload = {
      'profile': profile.toJson(),
      'daily_metrics': metrics.toJson(),
      'history_available': hasHistory,
      'daily_metrics_history': metricHistory.map((e) => e.toJson()).toList(),
      'daily_trend_summary': _buildTrendSummary(
        metrics: metrics,
        metricHistory: metricHistory,
      ),
      'completed_training_history': completedHistory,
      'completed_training_summary': _buildCompletedTrainingSummary(
        completedHistory,
      ),
      'training_history_summary': trainingHistorySummary.trim(),
      'total_minutes_includes_rest': totalMinutesIncludesRest,
      'target_total_seconds': profile.exerciseMinutes * 60,
      'component_contract': contract.toJson(),
      'expect_response_schema': {
        'training_items': [
          {
            'type': 'exercise|rest',
            'title': '动作名称',
            'display_title': '用于展示的标题',
            'duration_seconds': 600,
            'duration_minutes': 10,
            'intensity': 'low|medium|high',
            'equipment': '哑铃/瑜伽垫/无器械',
            'instructions': '简短动作说明',
          },
        ],
        'components': [
          {
            'component': 'timer_button|completion_feedback|training_card',
            'props': {'key': 'value'},
          },
        ],
        'diet_advice': '饮食建议',
        'hydration_advice': '饮水建议',
        'hydration_target_ml': 2000,
        'warning': '风险提醒',
      },
    };

    final targetSeconds = max(60, profile.exerciseMinutes * 60);
    int? previousDurationSeconds;
    DeepSeekException? latestError;
    TrainingPlan? latestPlan;

    for (var attempt = 0; attempt < 3; attempt++) {
      final stricterRetryNote = attempt == 0
          ? null
          : '上次生成总时长为 ${_minutes(previousDurationSeconds ?? 0)} 分钟，'
                '目标是 ${_minutes(targetSeconds)} 分钟（含休息）。'
                '请重新输出，并将总时长精确等于目标时长。';

      try {
        final plan = await _requestPlan(
          payload: payload,
          stricterRetryNote: stricterRetryNote,
          temperature: attempt == 0 ? 0.2 : 0.0,
        );
        latestPlan = plan;
        if (_isExactDuration(plan, targetSeconds)) {
          return plan;
        }
        previousDurationSeconds = plan.totalDurationSeconds;
        latestError = DeepSeekException(
          '计划时长与目标不匹配（目标 ${_minutes(targetSeconds)} 分钟，'
          '实际约 ${_minutes(plan.totalDurationSeconds)} 分钟），请重试。',
        );
      } on DeepSeekException catch (e) {
        latestError = e;
        final match = RegExp(r'实际约 (\d+) 分钟').firstMatch(e.message);
        if (match != null) {
          previousDurationSeconds =
              (int.tryParse(match.group(1) ?? '') ?? 0) * 60;
        }
      }
    }

    if (latestPlan != null) {
      return _forceAdjustToExactDuration(latestPlan, targetSeconds);
    }
    throw latestError ?? const DeepSeekException('生成失败，请稍后重试。');
  }

  Future<TrainingPlan> _requestPlan({
    required Map<String, dynamic> payload,
    required double temperature,
    String? stricterRetryNote,
  }) async {
    try {
      return await _requestPlanToBase(
        baseUrl: _primaryBaseUrl,
        payload: payload,
        stricterRetryNote: stricterRetryNote,
        temperature: temperature,
      );
    } catch (primaryError) {
      try {
        return await _requestPlanToBase(
          baseUrl: _fallbackBaseUrl,
          payload: payload,
          stricterRetryNote: stricterRetryNote,
          temperature: temperature,
        );
      } catch (fallbackError) {
        throw DeepSeekException(
          '主端点失败: ${_errorMessage(primaryError)}；'
          '回退失败: ${_errorMessage(fallbackError)}',
        );
      }
    }
  }

  Future<TrainingPlan> _requestPlanToBase({
    required String baseUrl,
    required Map<String, dynamic> payload,
    required double temperature,
    String? stricterRetryNote,
  }) async {
    final endpoint = '$baseUrl$_chatCompletionsPath';
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': temperature,
            'messages': [
              {
                'role': 'system',
                'content':
                    '你是专业运动康复教练。仅输出合法 JSON，不要 markdown，不要解释。'
                    '必须包含训练条目、组件配置、饮食建议、饮水建议、饮水目标和风险提示。'
                    '训练条目必须支持 type=exercise/rest，并保证总时长包含休息时长。'
                    '需要根据用户性别、目标、备注、近期训练摘要、体重和血压变化生成个性化计划。'
                    '必须结合 completed_training_history 输出更个性化计划，'
                    '若近期完成强度较高，优先控制恢复/休息配比。'
                    '训练总时长必须精确等于用户输入的锻炼时长。',
              },
              {'role': 'user', 'content': jsonEncode(payload)},
              if (stricterRetryNote != null)
                {'role': 'user', 'content': stricterRetryNote},
            ],
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeepSeekException(
        '请求失败($baseUrl): ${response.statusCode} ${response.body}',
      );
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = parsed['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw DeepSeekException('响应缺少 choices($baseUrl)。');
    }

    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    final text = _contentToString(content);

    if (text == null || text.trim().isEmpty) {
      throw DeepSeekException('响应内容为空($baseUrl)。');
    }

    final normalized = _extractJsonString(text.trim());
    final planJson = jsonDecode(normalized) as Map<String, dynamic>;
    final plan = TrainingPlan.fromJson(planJson);
    if (plan.items.isEmpty) {
      throw DeepSeekException('计划为空($baseUrl)。');
    }
    return plan;
  }

  bool _isExactDuration(TrainingPlan plan, int targetSeconds) {
    return plan.totalDurationSeconds == targetSeconds;
  }

  TrainingPlan _forceAdjustToExactDuration(
    TrainingPlan plan,
    int targetSeconds,
  ) {
    final items = [...plan.items];
    var delta = targetSeconds - plan.totalDurationSeconds;
    if (delta == 0) {
      return plan;
    }

    if (delta > 0) {
      items.add(
        TrainingItem(
          type: 'rest',
          title: '补足休息',
          displayTitle: '补足休息',
          durationMinutes: max(1, (delta / 60).ceil()),
          durationSeconds: delta,
          intensity: 'low',
          equipment: '无器械',
          instructions: '按计划补足时长，平稳呼吸。',
        ),
      );
      return TrainingPlan(
        items: items,
        components: plan.components,
        dietAdvice: plan.dietAdvice,
        hydrationAdvice: plan.hydrationAdvice,
        warning: plan.warning,
        hydrationTargetMl: plan.hydrationTargetMl,
      );
    }

    var needCut = -delta;
    for (var i = items.length - 1; i >= 0 && needCut > 0; i--) {
      final item = items[i];
      final current = item.normalizedDurationSeconds;
      final minAllowed = item.type == 'rest' ? 0 : 60;
      final canCut = max(0, current - minAllowed);
      if (canCut == 0) {
        continue;
      }
      final cut = min(canCut, needCut);
      final next = current - cut;
      needCut -= cut;
      if (next == 0 && item.type == 'rest') {
        items.removeAt(i);
      } else {
        items[i] = TrainingItem(
          type: item.type,
          title: item.title,
          displayTitle: item.displayTitle,
          durationMinutes: max(1, (next / 60).ceil()),
          durationSeconds: next,
          intensity: item.intensity,
          equipment: item.equipment,
          instructions: item.instructions,
        );
      }
    }

    if (needCut > 0 && items.isNotEmpty) {
      final last = items.last;
      final lastSeconds = max(1, last.normalizedDurationSeconds - needCut);
      items[items.length - 1] = TrainingItem(
        type: last.type,
        title: last.title,
        displayTitle: last.displayTitle,
        durationMinutes: max(1, (lastSeconds / 60).ceil()),
        durationSeconds: lastSeconds,
        intensity: last.intensity,
        equipment: last.equipment,
        instructions: last.instructions,
      );
    }

    return TrainingPlan(
      items: items,
      components: plan.components,
      dietAdvice: plan.dietAdvice,
      hydrationAdvice: plan.hydrationAdvice,
      warning: plan.warning,
      hydrationTargetMl: plan.hydrationTargetMl,
    );
  }

  int _minutes(int seconds) => (seconds / 60).round();

  List<Map<String, dynamic>> _compactCompletedHistory(
    List<DailyCheckinRecord> history,
  ) {
    final filtered = history.where((record) => record.completed).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered
        .take(7)
        .map((record) {
          final completedItems = record.itemRecords
              .where((item) => item.completedAt != null)
              .map(
                (item) => {
                  'title': item.title,
                  'duration_target_sec': item.durationTargetSec,
                  'actual_elapsed_sec': item.actualElapsedSec,
                },
              )
              .toList(growable: false);
          return {
            'date': record.date,
            'completed': record.completed,
            'plan_digest': record.planDigest.toJson(),
            'completed_items': completedItems,
          };
        })
        .toList(growable: false);
  }

  String _buildCompletedTrainingSummary(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return '最近7天无已完成训练记录。';
    }
    final days = history.length;
    final totalItems = history
        .map((entry) => (entry['completed_items'] as List<dynamic>).length)
        .fold<int>(0, (sum, value) => sum + value);
    final totalSeconds = history
        .map(
          (entry) =>
              ((entry['plan_digest']
                          as Map<String, dynamic>)['total_target_seconds']
                      as num?)
                  ?.toInt() ??
              0,
        )
        .fold<int>(0, (sum, value) => sum + value);
    return '最近$days天已完成$totalItems项训练，累计目标约${_minutes(totalSeconds)}分钟。';
  }

  String _errorMessage(Object error) {
    if (error is DeepSeekException) {
      return error.message;
    }
    return error.toString();
  }

  Map<String, dynamic> _buildTrendSummary({
    required DailyHealthMetrics metrics,
    required List<DailyHealthSnapshot> metricHistory,
  }) {
    if (metricHistory.isEmpty) {
      return {
        'weight_delta_kg': 0.0,
        'systolic_delta': 0,
        'diastolic_delta': 0,
        'days': 1,
      };
    }

    final first = metricHistory.first;
    final last = metricHistory.last;
    final latestWeight = last.date.isAfter(metrics.date)
        ? last.weightKg
        : metrics.weightKg;
    final latestSystolic = last.date.isAfter(metrics.date)
        ? last.systolic
        : metrics.systolic;
    final latestDiastolic = last.date.isAfter(metrics.date)
        ? last.diastolic
        : metrics.diastolic;

    return {
      'weight_delta_kg': double.parse(
        (latestWeight - first.weightKg).toStringAsFixed(2),
      ),
      'systolic_delta': latestSystolic - first.systolic,
      'diastolic_delta': latestDiastolic - first.diastolic,
      'days': metricHistory.length,
    };
  }

  String? _contentToString(dynamic content) {
    if (content is String) {
      return content;
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map<String, dynamic>) {
          final text = part['text'];
          if (text is String) {
            buffer.write(text);
          }
        }
      }
      final result = buffer.toString();
      return result.isEmpty ? null : result;
    }

    return null;
  }

  String _extractJsonString(String raw) {
    if (!raw.startsWith('```')) {
      return raw;
    }

    final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(raw);
    if (match == null) {
      return raw;
    }

    return match.group(1) ?? raw;
  }

  void dispose() {
    _client.close();
  }
}

class DeepSeekException implements Exception {
  const DeepSeekException(this.message);

  final String message;

  @override
  String toString() => message;
}
