import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'chord_synthesizer.dart';

/// Cross-platform audio playback wrapper for synthesized piano/guitar chords.
/// Lazily creates its [AudioPlayer] and safely ignores platform-channel errors
/// in headless test environments.
class ChordAudioPlayer {
  AudioPlayer? _player;
  bool _disposed = false;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> playChord({
    required List<int> midiNotes,
    required SynthInstrument instrument,
  }) async {
    if (_disposed || midiNotes.isEmpty || _isTestEnvironment) {
      return;
    }

    final Uint8List wavBytes = ChordSynthesizer.synthesizeChordWav(
      midiNotes: midiNotes,
      instrument: instrument,
    );

    await runZonedGuarded<Future<void>>(
      () async {
        try {
          final AudioPlayer player = _player ??= AudioPlayer();
          await player.stop();
          await player.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
        } catch (_) {
          // Ignore platform audio errors if no audio device is available.
        }
      },
      (Object error, StackTrace stack) {
        // Swallow unawaited plugin channel errors from AudioPlayer._create().
      },
    );
  }

  Future<void> stop() async {
    if (_disposed || _player == null || _isTestEnvironment) {
      return;
    }
    try {
      await _player!.stop();
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
