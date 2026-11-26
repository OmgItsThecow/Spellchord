import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Loads and caches MIT-licensed clean electric guitar multisamples from
/// `assets/audio/guitar/` as normalized floating-point PCM buffers.
class GuitarSampleBank {
  GuitarSampleBank._();

  static final GuitarSampleBank instance = GuitarSampleBank._();

  /// Base MIDI pitches and corresponding asset filenames (spaced every 4 semitones).
  static const Map<int, String> sampleAssets = <int, String>{
    40: 'assets/audio/guitar/E2.wav',
    44: 'assets/audio/guitar/Ab2.wav',
    48: 'assets/audio/guitar/C3.wav',
    52: 'assets/audio/guitar/E3.wav',
    56: 'assets/audio/guitar/Ab3.wav',
    60: 'assets/audio/guitar/C4.wav',
    64: 'assets/audio/guitar/E4.wav',
    68: 'assets/audio/guitar/Ab4.wav',
    72: 'assets/audio/guitar/C5.wav',
    76: 'assets/audio/guitar/E5.wav',
  };

  final Map<int, Float64List> _samples = <int, Float64List>{};
  Future<void>? _loadingFuture;

  bool get isLoaded => _samples.isNotEmpty;

  Map<int, Float64List> get samples => _samples;

  /// Lazily loads all bundled guitar WAV samples once. Safe to call repeatedly.
  Future<void> ensureLoaded() {
    if (_samples.isNotEmpty) {
      return Future<void>.value();
    }
    return _loadingFuture ??= _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      for (final MapEntry<int, String> entry in sampleAssets.entries) {
        final ByteData data = await rootBundle.load(entry.value);
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final Float64List pcm = decodeWavPcm16(bytes);
        if (pcm.isNotEmpty) {
          _samples[entry.key] = pcm;
        }
      }
    } catch (_) {
      // Allow graceful fallback to harmonic synthesis in headless/assetless tests.
    } finally {
      _loadingFuture = null;
    }
  }

  /// Injects pre-decoded samples (useful for unit tests without asset bundles).
  void loadFromMap(Map<int, Float64List> decoded) {
    _samples
      ..clear()
      ..addAll(decoded);
  }

  /// Returns the base MIDI note in [samples] closest to [targetMidi].
  static int nearestBaseMidi(int targetMidi, Iterable<int> availableMidi) {
    int bestMidi = availableMidi.first;
    int bestDist = (targetMidi - bestMidi).abs();
    for (final int candidate in availableMidi) {
      final int dist = (targetMidi - candidate).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestMidi = candidate;
      }
    }
    return bestMidi;
  }

  /// Decodes a 16-bit mono PCM RIFF/WAV buffer into normalized [-1.0, 1.0] samples.
  static Float64List decodeWavPcm16(Uint8List bytes) {
    if (bytes.length < 44) {
      return Float64List(0);
    }
    final ByteData view = ByteData.sublistView(bytes);
    // Verify 'RIFF' and 'WAVE'
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46 ||
        bytes[8] != 0x57 ||
        bytes[9] != 0x41 ||
        bytes[10] != 0x56 ||
        bytes[11] != 0x45) {
      return Float64List(0);
    }

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final int chunkSize = view.getUint32(offset + 4, Endian.little);
      final bool isData = bytes[offset] == 0x64 &&
          bytes[offset + 1] == 0x61 &&
          bytes[offset + 2] == 0x74 &&
          bytes[offset + 3] == 0x61;
      final int dataStart = offset + 8;
      if (isData) {
        final int availableBytes =
            (bytes.length - dataStart).clamp(0, chunkSize);
        final int sampleCount = availableBytes ~/ 2;
        final Float64List out = Float64List(sampleCount);
        for (int i = 0; i < sampleCount; i++) {
          out[i] = view.getInt16(dataStart + i * 2, Endian.little) / 32768.0;
        }
        return out;
      }
      offset = dataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    return Float64List(0);
  }
}
