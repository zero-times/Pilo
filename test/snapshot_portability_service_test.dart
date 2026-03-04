import 'dart:convert';
import 'dart:io';

import 'package:fitness_flutter_app/src/models/training_models.dart';
import 'package:fitness_flutter_app/src/services/local_snapshot_store.dart';
import 'package:fitness_flutter_app/src/services/snapshot_portability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export file and import parse work with valid schema', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'fitness-portability-',
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
      latestPlan: const TrainingPlan(
        items: [],
        components: [],
        dietAdvice: 'test',
        hydrationAdvice: 'test',
        warning: 'test',
        hydrationTargetMl: 2000,
      ),
    );

    final importFile = File('${tempDir.path}/import.json');
    await importFile.writeAsString(jsonEncode(snapshot.toJson()));

    final service = SnapshotPortabilityService(
      snapshotStore: store,
      tempDirectoryProvider: () async => tempDir,
      importFilePicker: () async => importFile,
      fileSharer: (_) async {},
      now: () => DateTime.utc(2026, 2, 26, 1, 2, 3),
    );

    final exported = await service.exportSnapshotFile(snapshot);
    expect(exported.path, contains('fitness-backup-20260226-010203.json'));

    final parsed = await service.pickAndParseImportFile();
    expect(parsed?.latestPlan?.dietAdvice, 'test');
  });

  test('import parser rejects unsupported schema version', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'fitness-portability-bad-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = LocalSnapshotStore(
      documentsDirectoryProvider: () async => tempDir,
    );
    final badFile = File('${tempDir.path}/bad.json');
    await badFile.writeAsString(
      jsonEncode({
        'schema_version': 99,
        'updated_at': DateTime.now().toString(),
      }),
    );

    final service = SnapshotPortabilityService(
      snapshotStore: store,
      importFilePicker: () async => badFile,
      fileSharer: (_) async {},
    );

    expect(service.pickAndParseImportFile, throwsFormatException);
  });
}
