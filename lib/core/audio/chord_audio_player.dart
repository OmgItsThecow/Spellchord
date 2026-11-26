import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'chord_synthesizer.dart';
import 'guitar_sample_bank.dart';

/// Cross-platform audio playback wrapper for synthesized piano and sampled
/// electric guitar chords with an in-memory LRU WAV cache.
/// Lazily creates its [AudioPlayer] and safely ignores platform-channel errors
/// in headless test environments.
class ChordAudioPlayer {
  AudioPlayer? _player;
  bool _disposed = false;

  static const int _maxCacheEntries = 24;
  final LinkedHashMap<String, Uint8List> _wavCache =
      LinkedHashMap<String, Uint8List>();

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> playChord({
    required List<int> midiNotes,
    required SynthInstrument instrument,
  }) async {
    if (_disposed || midiNotes.isEmpty || _isTestEnvironment) {
      return;
    }

    if (instrument == SynthInstrument.guitar &&
        !GuitarSampleBank.instance.isLoaded) {
      await GuitarSampleBank.instance.ensureLoaded();
      if (_disposed) {
        return;
      }
    }

    final List<int> sorted = List<int>.from(midiNotes)..sort();
    final String cacheKey = '${instrument.name}:${sorted.join(",")}';

    Uint8List? wavBytes = _wavCache.remove(cacheKey);
    if (wavBytes == null) {
      wavBytes = ChordSynthesizer.synthesizeChordWav(
        midiNotes: sorted,
        instrument: instrument,
      );
      if (_wavCache.length >= _maxCacheEntries) {
        _wavCache.remove(_wavCache.keys.first);
      }
    }
    _wavCache[cacheKey] = wavBytes;

    await runZonedGuarded<Future<void>>(
      () async {
        try {
          final AudioPlayer player = _player ??= AudioPlayer();
          await player.stop();
          await player.play(BytesSource(wavBytes!, mimeType: 'audio/wav'));
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
    _wavCache.clear();
    try {
      _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
