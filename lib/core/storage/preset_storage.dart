import 'dart:convert';
import 'dart:io';

import '../models/chord_spec.dart';

/// Persists custom user chord progressions to a local JSON file using only
/// standard `dart:convert` and `dart:io` APIs.
class PresetStorage {
  PresetStorage._();

  static const String _appFolder = 'harmonic_explorer';
  static const String _fileName = 'user_presets.json';

  static File _resolveFile() {
    String baseDir;
    if (Platform.isWindows) {
      baseDir = Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.systemTemp.path;
    } else if (Platform.isLinux) {
      final String? xdg = Platform.environment['XDG_DATA_HOME'];
      final String? home = Platform.environment['HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        baseDir = xdg;
      } else if (home != null && home.isNotEmpty) {
        baseDir = '$home/.local/share';
      } else {
        baseDir = Directory.systemTemp.path;
      }
    } else if (Platform.isAndroid) {
      final Directory tempDir = Directory.systemTemp;
      final Directory appDataRoot = tempDir.parent;
      if (appDataRoot.path.isNotEmpty && appDataRoot.path != tempDir.path) {
        baseDir = '${appDataRoot.path}${Platform.pathSeparator}files';
      } else {
        baseDir = tempDir.path;
      }
    } else {
      baseDir = Directory.systemTemp.path;
    }

    final String sep = Platform.pathSeparator;
    return File('$baseDir$sep$_appFolder$sep$_fileName');
  }

  /// Loads saved user presets from disk; returns an empty map if none exist.
  static Future<Map<String, List<ChordSpec>>> loadUserPresets() async {
    try {
      final File file = _resolveFile();
      if (!await file.exists()) {
        return <String, List<ChordSpec>>{};
      }
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <String, List<ChordSpec>>{};
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, List<ChordSpec>>{};
      }

      final Map<String, List<ChordSpec>> result = <String, List<ChordSpec>>{};
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        if (entry.value is! List<dynamic>) {
          continue;
        }
        final List<ChordSpec> chords = <ChordSpec>[];
        for (final dynamic item in entry.value as List<dynamic>) {
          if (item is Map<String, dynamic>) {
            chords.add(ChordSpec.fromJson(item));
          }
        }
        if (chords.isNotEmpty) {
          result[entry.key] = chords;
        }
      }
      return result;
    } catch (_) {
      return <String, List<ChordSpec>>{};
    }
  }

  /// Writes all saved user presets to disk as formatted JSON.
  static Future<void> saveUserPresets(
    Map<String, List<ChordSpec>> presets,
  ) async {
    try {
      final File file = _resolveFile();
      await file.parent.create(recursive: true);
      final Map<String, dynamic> payload = <String, dynamic>{
        for (final MapEntry<String, List<ChordSpec>> entry in presets.entries)
          entry.key:
              entry.value.map((ChordSpec c) => c.toJson()).toList(),
      };
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(payload));
    } catch (_) {
      // Gracefully ignore storage failures in restricted sandboxes/tests.
    }
  }
}
