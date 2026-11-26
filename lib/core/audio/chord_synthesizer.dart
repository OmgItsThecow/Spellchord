import 'dart:math' as math;
import 'dart:typed_data';

/// Instrument timbre for real-time in-memory chord synthesis.
enum SynthInstrument {
  piano,
  guitar,
}

/// Pure-Dart in-memory PCM WAV synthesizer for piano and plucked guitar chords.
/// Requires zero bundled audio asset files.
class ChordSynthesizer {
  ChordSynthesizer._();

  static const int sampleRate = 22050;

  /// Converts a MIDI note number [0..127] to frequency in Hz (A4 = 440 Hz).
  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  /// Synthesizes [midiNotes] using the requested [instrument] and returns a
  /// complete 16-bit mono RIFF/WAV byte buffer ready for playback.
  static Uint8List synthesizeChordWav({
    required List<int> midiNotes,
    required SynthInstrument instrument,
  }) {
    if (midiNotes.isEmpty) {
      return encodeWavPcm16(Float64List(0), sampleRate);
    }
    final List<int> sorted = List<int>.from(midiNotes)..sort();
    final Float64List samples = instrument == SynthInstrument.piano
        ? _synthesizePiano(sorted)
        : _synthesizeGuitar(sorted);
    return encodeWavPcm16(samples, sampleRate);
  }

  static Float64List _synthesizePiano(List<int> notes) {
    const double durationSec = 1.35;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List mix = Float64List(totalSamples);

    // Harmonic amplitudes for a warm electric/acoustic piano tone.
    const List<double> harmonics = <double>[1.0, 0.44, 0.22, 0.11, 0.05, 0.02];
    const int attackSamples = 176; // ~8 ms
    const int tailFadeSamples = 882; // ~40 ms

    for (int nIdx = 0; nIdx < notes.length; nIdx++) {
      final int midi = notes[nIdx];
      final double freq = midiToFrequency(midi);
      final int startSample = (nIdx * 0.004 * sampleRate).round();
      final double baseDecay = 2.2 + (midi - 48).clamp(0, 48) * 0.032;

      for (int i = startSample; i < totalSamples; i++) {
        final double t = (i - startSample) / sampleRate;
        final double attack = i - startSample < attackSamples
            ? (i - startSample) / attackSamples
            : 1.0;

        double sample = 0.0;
        for (int h = 0; h < harmonics.length; h++) {
          final double hFreq = freq * (h + 1);
          if (hFreq >= sampleRate * 0.45) {
            break;
          }
          final double hDecay = math.exp(-t * (baseDecay + h * 1.15));
          sample += harmonics[h] *
              hDecay *
              math.sin(2.0 * math.pi * hFreq * t);
        }

        mix[i] += sample * attack;
      }
    }

    _normalizeAndFadeTail(mix, tailFadeSamples);
    return mix;
  }

  static Float64List _synthesizeGuitar(List<int> notes) {
    const double durationSec = 1.65;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List mix = Float64List(totalSamples);

    const int harmonicCount = 10;
    const double pluckPos = 0.21;
    const double inharmonicity = 0.000035;
    const double strumStepSec = 0.012; // Subtle 12 ms per-string strum stagger
    const int attackSamples = 100; // ~4.5 ms smooth pluck attack
    const int tailFadeSamples = 1323; // ~60 ms

    // Precompute pluck-position harmonic amplitudes (1-indexed harmonics).
    final List<double> harmonicAmps = List<double>.generate(
      harmonicCount,
      (int h) {
        final int n = h + 1;
        if (n == 1) {
          return 1.0;
        }
        final double pluckWeight = math.sin(math.pi * n * pluckPos).abs();
        return (0.35 + 0.65 * pluckWeight) / math.pow(n, 1.28);
      },
      growable: false,
    );

    final int lastIdx = math.max(1, notes.length - 1);

    for (int nIdx = 0; nIdx < notes.length; nIdx++) {
      final int midi = notes[nIdx];
      final double freq = midiToFrequency(midi);
      final int startSample = (nIdx * strumStepSec * sampleRate).round();
      final double baseDecay = 1.45 + (midi - 40).clamp(0, 48) * 0.024;
      // Slightly balance bass vs. treble strings so upper chord voices sing.
      final double stringGain = 0.88 + 0.12 * (nIdx / lastIdx);

      // Precompute valid harmonic frequencies and decay rates for this string.
      final List<double> hFreqs = <double>[];
      final List<double> hDecays = <double>[];
      final List<double> hAmps = <double>[];
      for (int h = 0; h < harmonicCount; h++) {
        final int n = h + 1;
        final double hFreq =
            freq * n * math.sqrt(1.0 + inharmonicity * n * n);
        if (hFreq >= sampleRate * 0.45) {
          break;
        }
        hFreqs.add(2.0 * math.pi * hFreq);
        hDecays.add(baseDecay + math.pow(h, 1.35) * 1.45);
        hAmps.add(harmonicAmps[h]);
      }

      for (int i = startSample; i < totalSamples; i++) {
        final int dt = i - startSample;
        final double t = dt / sampleRate;
        final double attack = dt < attackSamples
            ? 0.5 * (1.0 - math.cos(math.pi * dt / attackSamples))
            : 1.0;

        double sample = 0.0;
        for (int h = 0; h < hFreqs.length; h++) {
          sample += hAmps[h] *
              math.exp(-t * hDecays[h]) *
              math.sin(hFreqs[h] * t);
        }

        mix[i] += sample * attack * stringGain;
      }
    }

    _normalizeAndFadeTail(mix, tailFadeSamples);
    return mix;
  }

  static void _normalizeAndFadeTail(Float64List samples, int tailFadeSamples) {
    if (samples.isEmpty) {
      return;
    }

    double peak = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double absVal = samples[i].abs();
      if (absVal > peak) {
        peak = absVal;
      }
    }

    final double scale = peak > 0.0 ? 0.88 / peak : 1.0;
    final int fadeStart = math.max(0, samples.length - tailFadeSamples);

    for (int i = 0; i < samples.length; i++) {
      double v = samples[i] * scale;
      if (i >= fadeStart && tailFadeSamples > 0) {
        final double fade = (samples.length - i) / tailFadeSamples;
        v *= fade;
      }
      samples[i] = v.clamp(-1.0, 1.0);
    }
  }

  /// Encodes normalized [-1.0, 1.0] mono float samples into a 16-bit PCM WAV.
  static Uint8List encodeWavPcm16(Float64List samples, int rate) {
    final int dataBytes = samples.length * 2;
    final ByteData buffer = ByteData(44 + dataBytes);

    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, 36 + dataBytes, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // PCM subchunk size
    buffer.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    buffer.setUint32(24, rate, Endian.little); // SampleRate
    buffer.setUint32(28, rate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataBytes, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final int pcm = (samples[i].clamp(-1.0, 1.0) * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcm, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
