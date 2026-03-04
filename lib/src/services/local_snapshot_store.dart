import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/training_models.dart';

class LocalSnapshotStore {
  LocalSnapshotStore({
    Future<Directory> Function()? documentsDirectoryProvider,
    DateTime Function()? now,
    this.fileName = 'fitness_snapshot_v1.json',
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final DateTime Function() _now;
  final String fileName;

  Future<AppSnapshot> load() async {
    try {
      final file = await _snapshotFile();
      if (!await file.exists()) {
        return AppSnapshot.empty();
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = AppSnapshot.fromJson(json);
      if (snapshot.schemaVersion > AppSnapshot.currentSchemaVersion) {
        throw const FormatException('Unsupported schema version.');
      }
      return snapshot;
    } catch (e, st) {
      debugPrint('LocalSnapshotStore.load failed: $e\n$st');
      return AppSnapshot.empty();
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final normalized = snapshot.copyWith(
      schemaVersion: AppSnapshot.currentSchemaVersion,
      updatedAt: _now().toUtc(),
    );
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(normalized.toJson());
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(encoded, flush: true);
    try {
      await tempFile.rename(file.path);
    } on FileSystemException {
      await file.writeAsString(encoded, flush: true);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final snapshot = await load();
    await save(snapshot.copyWith(userProfile: profile));
  }

  Future<void> updatePlan(
    TrainingPlan plan, {
    DateTime? generatedAt,
    String? planVersion,
  }) async {
    final snapshot = await load();
    await save(
      snapshot.copyWith(
        latestPlan: plan,
        generatedAt: generatedAt ?? DateTime.now().toUtc(),
        planVersion: planVersion,
        clearSessionState: true,
      ),
    );
  }

  Future<void> updateApiSettings(ApiSettings settings) async {
    final snapshot = await load();
    await save(snapshot.copyWith(apiSettings: settings));
  }

  Future<void> resetAll() async {
    await save(AppSnapshot.empty());
  }

  Future<void> appendOrUpdateCheckin(DailyCheckinRecord record) async {
    final snapshot = await load();
    final next = [...snapshot.checkinHistory];
    final existingIndex = next.indexWhere((entry) => entry.date == record.date);
    if (existingIndex >= 0) {
      next[existingIndex] = record;
    } else {
      next.add(record);
      next.sort((a, b) => a.date.compareTo(b.date));
    }
    final achievement = rebuildAchievementState(checkins: next, days: 30);
    await save(
      snapshot.copyWith(checkinHistory: next, achievementState: achievement),
    );
  }

  Future<void> updateSessionState(SessionState state) async {
    final snapshot = await load();
    await save(snapshot.copyWith(sessionState: state));
  }

  Future<void> clearSessionState() async {
    final snapshot = await load();
    await save(snapshot.copyWith(clearSessionState: true));
  }

  Future<void> addPlanToHistory(HistoricalTrainingPlan plan) async {
    final snapshot = await load();
    final exists = snapshot.planHistory.any((entry) => entry.id == plan.id);
    if (exists) {
      return;
    }
    final next = [...snapshot.planHistory, plan]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await save(snapshot.copyWith(planHistory: next));
  }

  Future<void> toggleFavoritePlan(String planId, bool favorite) async {
    final snapshot = await load();
    final next = snapshot.planHistory
        .map((entry) {
          if (entry.id != planId) {
            return entry;
          }
          return entry.copyWith(isFavorite: favorite);
        })
        .toList(growable: false);
    await save(snapshot.copyWith(planHistory: next));
  }

  Future<void> markPlanTrained(String planId, DateTime trainedAt) async {
    final snapshot = await load();
    final next = snapshot.planHistory
        .map((entry) {
          if (entry.id != planId) {
            return entry;
          }
          return entry.copyWith(
            lastTrainedAt: trainedAt.toUtc(),
            timesTrained: entry.timesTrained + 1,
          );
        })
        .toList(growable: false);
    await save(snapshot.copyWith(planHistory: next));
  }

  Future<List<HistoricalTrainingPlan>> loadPlanHistory() async {
    final snapshot = await load();
    final next = [...snapshot.planHistory]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return next;
  }

  Future<AchievementState> rebuildAchievementStateFromCheckins({
    int days = 30,
  }) async {
    final snapshot = await load();
    final achievement = rebuildAchievementState(
      checkins: snapshot.checkinHistory,
      days: days,
    );
    await save(snapshot.copyWith(achievementState: achievement));
    return achievement;
  }

  AchievementState rebuildAchievementState({
    required List<DailyCheckinRecord> checkins,
    int days = 30,
  }) {
    DateTime normalize(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    DateTime? parseDate(String value) => DateTime.tryParse(value);

    String toDateKey(DateTime value) {
      final y = value.year.toString().padLeft(4, '0');
      final m = value.month.toString().padLeft(2, '0');
      final d = value.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final completedDates = checkins
        .where((entry) => entry.completed)
        .map((entry) => parseDate(entry.date))
        .whereType<DateTime>()
        .map(normalize)
        .toSet();

    final sorted = completedDates.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      if (previous != null && day.difference(previous).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > best) {
        best = run;
      }
      previous = day;
    }

    final today = normalize(_now());
    final yesterday = today.subtract(const Duration(days: 1));
    final latest = sorted.isEmpty ? null : sorted.last;
    var current = 0;
    if (latest != null && (latest == today || latest == yesterday)) {
      current = 1;
      var cursor = latest.subtract(const Duration(days: 1));
      while (completedDates.contains(cursor)) {
        current += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    final streakDays = <DateTime>{};
    if (current > 0 && latest != null) {
      var cursor = latest;
      for (var i = 0; i < current; i++) {
        streakDays.add(cursor);
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    final timeline = List<SparkDayStatus>.generate(days, (index) {
      final offset = days - index - 1;
      final day = today.subtract(Duration(days: offset));
      final key = toDateKey(day);
      return SparkDayStatus(
        date: key,
        checkedIn: completedDates.contains(day),
        isStreakDay: streakDays.contains(day),
      );
    }, growable: false);

    return AchievementState(
      currentStreakDays: current,
      bestStreakDays: best,
      lastCheckinDate: latest == null ? null : toDateKey(latest),
      sparkTimeline: timeline,
    );
  }

  Future<File> _snapshotFile() async {
    final dir = await _resolveSnapshotDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<Directory> _resolveSnapshotDirectory() async {
    final iosHomeDirectory = _directoryFromHomeForIOS();
    if (iosHomeDirectory != null) {
      return iosHomeDirectory;
    }

    try {
      return await _documentsDirectoryProvider();
    } catch (e, st) {
      debugPrint(
        'LocalSnapshotStore directory provider failed, fallback to HOME/Documents: $e\n$st',
      );
    }

    final homeDocuments = _directoryFromHomeDocuments();
    if (homeDocuments != null) {
      return homeDocuments;
    }

    return Directory('${Directory.systemTemp.path}/fitness_flutter_app');
  }

  Directory? _directoryFromHomeForIOS() {
    if (kIsWeb || !Platform.isIOS) {
      return null;
    }
    return _directoryFromHomeDocuments();
  }

  Directory? _directoryFromHomeDocuments() {
    if (kIsWeb) {
      return null;
    }
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) {
      return null;
    }
    return Directory('$home/Documents');
  }
}
