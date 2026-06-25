import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogManager {
  static final LogManager _instance = LogManager._();
  factory LogManager() => _instance;
  LogManager._();

  File? _logFile;
  IOSink? _sink;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/notification_debug_${DateTime.now().millisecondsSinceEpoch}.log');
      _sink = _logFile!.openWrite();
      _initialized = true;
      log('--- LogManager initialized ---');
    } catch (e) {
      // Silently fail — logging shouldn't crash the app
    }
  }

  void log(String message) {
    if (!_initialized || _sink == null) return;
    final timestamp = DateTime.now().toIso8601String();
    _sink!.writeln('[$timestamp] $message');
  }

  Future<String?> getLogPath() async {
    if (!_initialized || _logFile == null) return null;
    return _logFile!.path;
  }

  Future<String?> readLog() async {
    if (!_initialized || _logFile == null) return null;
    return await _logFile!.readAsString();
  }

  Future<void> close() async {
    if (!_initialized || _sink == null) return;
    await _sink!.flush();
    await _sink!.close();
    _initialized = false;
  }
}
