import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'chord_synthesizer.dart';

/// Cross-platform audio playback wrapper for synthesized piano/guitar chords.
/// Lazily creates its [AudioPlayer] and safely ignores platform-channel errors
/// in headless test environments.
class ChordAudioPlayer {
  AudioPlayer? _player;
  bool _disposed = false;

  Future<void> playChord({
    required List<int> midiNotes,
    required SynthInstrument instrument,
  }) async {
    if (_disposed || midiNotes.isEmpty) {
      return;
    }

    final Uint8List wavBytes = ChordSynthesizer.synthesizeChordWav(
      midiNotes: midiNotes,
      instrument: instrument,
    );

    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Gracefully ignore missing plugin channels in unit/widget tests or
      // environments without an active audio output device.
    }
  }

  Future<void> stop() async {
    if (_disposed || _player == null) {
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
