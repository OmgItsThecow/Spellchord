import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'midi_exporter.dart';

/// Initiates native Windows OLE file drag-and-drop (`DoDragDrop` with
/// `IDataObject`) so users can drag single chords or full progressions as
/// `.mid` files straight into Ableton Live or other Windows DAWs.
class WindowsMidiDrag {
  WindowsMidiDrag._();

  static const MethodChannel _channel =
      MethodChannel('spellchord/windows_drag');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Exports [chordMidiNotes] to a temporary `.mid` file and begins a native
  /// Windows file drag session. Returns `true` if the drop completed.
  static Future<bool> startDrag({
    required List<List<int>> chordMidiNotes,
    required String suggestedName,
  }) async {
    if (!isSupported || chordMidiNotes.isEmpty) {
      return false;
    }
    try {
      final File midiFile = MidiExporter.writeTempMidiFile(
        chordMidiNotes: chordMidiNotes,
        suggestedName: suggestedName,
      );
      final bool? dropped = await _channel.invokeMethod<bool>(
        'startFileDrag',
        <String, dynamic>{'path': midiFile.path},
      );
      return dropped ?? false;
    } catch (_) {
      return false;
    }
  }
}
