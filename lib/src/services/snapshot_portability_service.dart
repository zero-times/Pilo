import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/training_models.dart';
import 'local_snapshot_store.dart';

class SnapshotPortabilityService {
  SnapshotPortabilityService({
    required LocalSnapshotStore snapshotStore,
    Future<Directory> Function()? tempDirectoryProvider,
    Future<File?> Function()? importFilePicker,
    Future<void> Function(File file)? fileSharer,
    DateTime Function()? now,
  }) : _snapshotStore = snapshotStore,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
       _importFilePicker = importFilePicker ?? _defaultImportPicker,
       _fileSharer = fileSharer ?? _defaultFileSharer,
       _now = now ?? DateTime.now;

  final LocalSnapshotStore _snapshotStore;
  final Future<Directory> Function() _tempDirectoryProvider;
  final Future<File?> Function() _importFilePicker;
  final Future<void> Function(File file) _fileSharer;
  final DateTime Function() _now;

  Future<File> exportSnapshotFile(AppSnapshot snapshot) async {
    final tempDir = await _tempDirectoryProvider();
    await tempDir.create(recursive: true);
    final timestamp = _fileStamp(_now());
    final file = File('${tempDir.path}/fitness-backup-$timestamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
    return file;
  }

  Future<void> shareExportedFile(File file) {
    return _fileSharer(file);
  }

  Future<AppSnapshot?> pickAndParseImportFile() async {
    final file = await _importFilePicker();
    if (file == null) {
      return null;
    }
    final raw = await file.readAsString();
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('导入文件不是合法 JSON 对象。');
    }
    final schemaVersion = parsed['schema_version'];
    if (schemaVersion is! int) {
      throw const FormatException('导入文件缺少 schema_version。');
    }
    if (schemaVersion > AppSnapshot.currentSchemaVersion) {
      throw const FormatException('不支持的备份版本。');
    }
    return AppSnapshot.fromJson(parsed);
  }

  Future<void> importAndReplace(AppSnapshot snapshot) async {
    if (snapshot.schemaVersion > AppSnapshot.currentSchemaVersion) {
      throw const FormatException('不支持的备份版本。');
    }
    await _snapshotStore.save(
      snapshot.copyWith(schemaVersion: AppSnapshot.currentSchemaVersion),
    );
  }

  static Future<File?> _defaultImportPicker() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path);
  }

  static Future<void> _defaultFileSharer(File file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '个人锻炼助手本地备份文件'),
    );
  }

  String _fileStamp(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$y$m$d-$hh$mm$ss';
  }
}
