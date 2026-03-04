import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class VoiceBroadcastService {
  Future<void> speak(String message, {bool interrupt = true});

  Future<void> stop();

  Future<void> dispose();
}

class FlutterTtsVoiceBroadcastService implements VoiceBroadcastService {
  FlutterTtsVoiceBroadcastService({FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;
  bool _available = true;

  Future<void> _ensureInitialized() async {
    if (_initialized || !_available) {
      return;
    }

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      _initialized = true;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  @override
  Future<void> speak(String message, {bool interrupt = true}) async {
    final text = message.trim();
    if (text.isEmpty) {
      return;
    }

    await _ensureInitialized();
    if (!_available) {
      return;
    }

    try {
      if (interrupt) {
        await _tts.stop();
      }
      await _tts.speak(text);
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  @override
  Future<void> stop() async {
    await _ensureInitialized();
    if (!_available) {
      return;
    }

    try {
      await _tts.stop();
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
