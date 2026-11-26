import 'dart:math' as math;
import 'dart:typed_data';

import 'guitar_sample_bank.dart';

/// Instrument timbre for real-time in-memory chord synthesis.
enum SynthInstrument {
  piano,
  guitar,
}

/// Pure-Dart in-memory PCM WAV synthesizer for piano and sample-based electric
/// guitar chords with dream-pop effects (filter, phaser, chorus, flanger, reverb).
class ChordSynthesizer {
  ChordSynthesizer._();

  static const int sampleRate = 22050;

  /// Converts a MIDI note number [0..127] to frequency in Hz (A4 = 440 Hz).
  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  /// Synthesizes [midiNotes] using the requested [instrument] and returns a
  /// complete 16-bit mono RIFF/WAV byte buffer ready for playback.
  ///
  /// When [instrument] is [SynthInstrument.guitar], uses [guitarSamples] (or
  /// [GuitarSampleBank.instance.samples] if loaded) and processes the mixed
  /// chord through a warm dream-pop pedalboard chain (vintage filter, phaser,
  /// chorus, subtle flanger, and dark plate reverb).
  static Uint8List synthesizeChordWav({
    required List<int> midiNotes,
    required SynthInstrument instrument,
    Map<int, Float64List>? guitarSamples,
  }) {
    if (midiNotes.isEmpty) {
      return encodeWavPcm16(Float64List(0), sampleRate);
    }
    final List<int> sorted = List<int>.from(midiNotes)..sort();
    final Float64List samples = instrument == SynthInstrument.piano
        ? _synthesizePiano(sorted)
        : _synthesizeElectricGuitar(
            sorted,
            guitarSamples ?? GuitarSampleBank.instance.samples,
          );
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

  /// Renders a dream-pop electric guitar chord (Men I Trust inspired):
  /// multisampled clean jazz/neck-pickup electric guitar mixed with a subtle
  /// strum and processed through warm vintage filtering, 4-stage phaser,
  /// lush chorus + subtle flanger, and a dark velvety reverb.
  static Float64List _synthesizeElectricGuitar(
    List<int> notes,
    Map<int, Float64List> sampleBank,
  ) {
    const double durationSec = 2.20;
    final int totalSamples = (sampleRate * durationSec).round();
    const int tailFadeSamples = 1764; // ~80 ms smooth fade-out

    final Float64List dryMix = sampleBank.isNotEmpty
        ? _mixSampledGuitar(notes, sampleBank, totalSamples)
        : _mixFallbackElectricGuitar(notes, totalSamples);

    final Float64List wetMix = _applyDreamPopGuitarFx(dryMix);
    _normalizeAndFadeTail(wetMix, tailFadeSamples);
    return wetMix;
  }

  static Float64List _mixSampledGuitar(
    List<int> notes,
    Map<int, Float64List> sampleBank,
    int totalSamples,
  ) {
    final Float64List mix = Float64List(totalSamples);
    const double strumStepSec = 0.011; // Gentle 11 ms per-string strum
    const int attackSamples = 66; // ~3 ms soft de-click attack
    final int lastIdx = math.max(1, notes.length - 1);
    final Iterable<int> availableMidi = sampleBank.keys;

    for (int nIdx = 0; nIdx < notes.length; nIdx++) {
      final int targetMidi = notes[nIdx];
      final int baseMidi =
          GuitarSampleBank.nearestBaseMidi(targetMidi, availableMidi);
      final Float64List src = sampleBank[baseMidi]!;
      final int srcLen = src.length;
      if (srcLen < 2) {
        continue;
      }

      final double pitchRatio = math.pow(2.0, (targetMidi - baseMidi) / 12.0).toDouble();
      final int startSample = (nIdx * strumStepSec * sampleRate).round();
      // Gently balance bass vs. upper strings so chord color tones shine.
      final double stringGain = 0.86 + 0.14 * (nIdx / lastIdx);

      double srcPos = 0.0;
      for (int i = startSample; i < totalSamples; i++) {
        final int idx0 = srcPos.floor();
        if (idx0 + 1 >= srcLen) {
          break;
        }
        final double frac = srcPos - idx0;
        final double s = src[idx0] * (1.0 - frac) + src[idx0 + 1] * frac;

        final int dt = i - startSample;
        final double env = dt < attackSamples ? dt / attackSamples : 1.0;

        mix[i] += s * env * stringGain;
        srcPos += pitchRatio;
      }
    }

    return mix;
  }

  /// Warm clean-electric fallback used only in headless tests where asset
  /// bundles are not loaded; still runs through the exact same DSP FX chain.
  static Float64List _mixFallbackElectricGuitar(
    List<int> notes,
    int totalSamples,
  ) {
    final Float64List mix = Float64List(totalSamples);
    const int harmonicCount = 8;
    const double pluckPos = 0.23;
    const double strumStepSec = 0.011;
    const int attackSamples = 88;
    final int lastIdx = math.max(1, notes.length - 1);

    final List<double> harmonicAmps = List<double>.generate(
      harmonicCount,
      (int h) {
        final int n = h + 1;
        if (n == 1) {
          return 1.0;
        }
        final double pluckWeight = math.sin(math.pi * n * pluckPos).abs();
        return (0.35 + 0.65 * pluckWeight) / math.pow(n, 1.35);
      },
      growable: false,
    );

    for (int nIdx = 0; nIdx < notes.length; nIdx++) {
      final int midi = notes[nIdx];
      final double freq = midiToFrequency(midi);
      final int startSample = (nIdx * strumStepSec * sampleRate).round();
      final double baseDecay = 1.35 + (midi - 40).clamp(0, 48) * 0.022;
      final double stringGain = 0.86 + 0.14 * (nIdx / lastIdx);

      for (int i = startSample; i < totalSamples; i++) {
        final int dt = i - startSample;
        final double t = dt / sampleRate;
        final double attack = dt < attackSamples
            ? 0.5 * (1.0 - math.cos(math.pi * dt / attackSamples))
            : 1.0;

        double sample = 0.0;
        for (int h = 0; h < harmonicCount; h++) {
          final double hFreq = freq * (h + 1);
          if (hFreq >= sampleRate * 0.45) {
            break;
          }
          final double hDecay = baseDecay + math.pow(h, 1.35) * 1.4;
          sample += harmonicAmps[h] *
              math.exp(-t * hDecay) *
              math.sin(2.0 * math.pi * hFreq * t);
        }
        mix[i] += sample * attack * stringGain;
      }
    }

    return mix;
  }

  /// Dream-pop / Men I Trust pedalboard chain:
  /// 1. Gentle warm preamp saturation & pre-leveling
  /// 2. Vintage tone shaping (85 Hz HPF + 3.2 kHz warm 2-pole LPF)
  /// 3. 4-stage analog phaser (slow liquid sweep)
  /// 4. Lush chorus + subtle silky flanger (dual modulated delay lines)
  /// 5. Dark velvety Schroeder plate/room reverb (4 damped combs + 2 all-pass)
  static Float64List _applyDreamPopGuitarFx(Float64List input) {
    final int n = input.length;
    if (n == 0) {
      return input;
    }

    // Pre-normalize dry chord before saturation so overdrive stays consistent.
    double dryPeak = 0.0;
    for (int i = 0; i < n; i++) {
      final double a = input[i].abs();
      if (a > dryPeak) {
        dryPeak = a;
      }
    }
    final double dryScale = dryPeak > 1e-6 ? 0.85 / dryPeak : 1.0;

    // --- 1 & 2. Warm preamp saturation + HPF (85 Hz) + Vintage LPF (3.2 kHz) ---
    final Float64List filtered = Float64List(n);
    // 1-pole HPF @ ~85 Hz
    const double hpRc = 1.0 / (2.0 * math.pi * 85.0);
    const double dt = 1.0 / sampleRate;
    const double hpAlpha = hpRc / (hpRc + dt);
    double hpPrevIn = 0.0;
    double hpPrevOut = 0.0;

    // 2-pole Biquad LPF @ 3200 Hz, Q = 0.72 (warm neck-pickup roll-off)
    const double w0 = 2.0 * math.pi * 3200.0 / sampleRate;
    final double cosW0 = math.cos(w0);
    final double sinW0 = math.sin(w0);
    final double alpha = sinW0 / (2.0 * 0.72);
    final double b0 = ((1.0 - cosW0) * 0.5) / (1.0 + alpha);
    final double b1 = (1.0 - cosW0) / (1.0 + alpha);
    final double b2 = b0;
    final double a1 = (-2.0 * cosW0) / (1.0 + alpha);
    final double a2 = (1.0 - alpha) / (1.0 + alpha);
    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;

    final double tanhNorm = _tanh(1.2);
    for (int i = 0; i < n; i++) {
      final double driven = _tanh(input[i] * dryScale * 1.2) / tanhNorm;
      final double hp = hpAlpha * (hpPrevOut + driven - hpPrevIn);
      hpPrevIn = driven;
      hpPrevOut = hp;

      final double lp = b0 * hp + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = hp;
      y2 = y1;
      y1 = lp;
      filtered[i] = lp;
    }

    // --- 3. 4-Stage Analog Phaser (0.38 Hz LFO, 380–1450 Hz) ---
    final Float64List phased = Float64List(n);
    final Float64List apZ = Float64List(4);
    double phaserFeedback = 0.0;
    const double phaserRate = 2.0 * math.pi * 0.38 / sampleRate;

    for (int i = 0; i < n; i++) {
      final double lfo = 0.5 * (1.0 + math.sin(i * phaserRate + 0.4));
      final double sweepHz = 380.0 + lfo * 1070.0;
      final double t = math.tan(math.pi * sweepHz / sampleRate);
      final double coeff = (t - 1.0) / (t + 1.0);

      double sig = filtered[i] + phaserFeedback * 0.28;
      for (int s = 0; s < 4; s++) {
        final double y = coeff * sig + apZ[s];
        apZ[s] = sig - coeff * y;
        sig = y;
      }
      phaserFeedback = sig;
      phased[i] = filtered[i] * 0.76 + sig * 0.26;
    }

    // --- 4. Lush Chorus + Subtle Flanger (Dual Modulated Delay Lines) ---
    final Float64List modulated = Float64List(n);
    const int modBufLen = 1024; // ~46 ms max delay
    final Float64List chorusBuf = Float64List(modBufLen);
    final Float64List flangerBuf = Float64List(modBufLen);
    int modWrite = 0;

    const double chorusBase = 0.0135 * sampleRate; // 13.5 ms
    const double chorusDepth = 0.0038 * sampleRate; // ±3.8 ms
    const double chorusRate = 2.0 * math.pi * 0.55 / sampleRate;

    const double flangerBase = 0.0052 * sampleRate; // 5.2 ms
    const double flangerDepth = 0.0018 * sampleRate; // ±1.8 ms
    const double flangerRate = 2.0 * math.pi * 0.29 / sampleRate;

    for (int i = 0; i < n; i++) {
      final double x = phased[i];
      chorusBuf[modWrite] = x;

      // Interpolated Chorus tap
      final double cDelay = chorusBase + chorusDepth * math.sin(i * chorusRate);
      final double cReadPos = modWrite - cDelay;
      final double cSample = _readCircularLinear(chorusBuf, cReadPos, modBufLen);

      // Interpolated Flanger tap with gentle feedback
      final double fDelay =
          flangerBase + flangerDepth * math.sin(i * flangerRate + 1.2);
      final double fReadPos = modWrite - fDelay;
      final double fSample =
          _readCircularLinear(flangerBuf, fReadPos, modBufLen);
      flangerBuf[modWrite] = x + fSample * 0.18;

      modulated[i] = x * 0.68 + cSample * 0.26 + fSample * 0.14;
      modWrite = (modWrite + 1) % modBufLen;
    }

    // --- 5. Dark Dreamy Plate/Room Reverb (4 damped combs + 2 all-pass) ---
    const List<int> combDelays = <int>[655, 818, 907, 964]; // ~30–44 ms
    const double combFeedback = 0.78;
    const double combDamp = 0.42; // Dark velvety tail
    final List<Float64List> combBufs =
        combDelays.map((int len) => Float64List(len)).toList(growable: false);
    final List<int> combIdx = List<int>.filled(combDelays.length, 0);
    final Float64List combLp = Float64List(combDelays.length);

    const List<int> apDelays = <int>[111, 37]; // ~5.0 ms, 1.7 ms
    const double apGain = 0.5;
    final List<Float64List> apBufs =
        apDelays.map((int len) => Float64List(len)).toList(growable: false);
    final List<int> apIdx = List<int>.filled(apDelays.length, 0);

    final Float64List output = Float64List(n);
    for (int i = 0; i < n; i++) {
      final double x = modulated[i];
      double combSum = 0.0;
      for (int c = 0; c < combDelays.length; c++) {
        final Float64List buf = combBufs[c];
        final int idx = combIdx[c];
        final double y = buf[idx];
        combLp[c] = y * (1.0 - combDamp) + combLp[c] * combDamp;
        buf[idx] = x + combLp[c] * combFeedback;
        combIdx[c] = (idx + 1) % combDelays[c];
        combSum += y;
      }

      double rev = combSum * 0.25;
      for (int a = 0; a < apDelays.length; a++) {
        final Float64List buf = apBufs[a];
        final int idx = apIdx[a];
        final double delayed = buf[idx];
        final double v = rev + delayed * apGain;
        buf[idx] = v;
        rev = delayed - v * apGain;
        apIdx[a] = (idx + 1) % apDelays[a];
      }

      output[i] = x * 0.72 + rev * 0.34;
    }

    return output;
  }

  static double _readCircularLinear(Float64List buf, double pos, int len) {
    double wrapped = pos % len;
    if (wrapped < 0) {
      wrapped += len;
    }
    final int i0 = wrapped.floor();
    final int i1 = (i0 + 1) % len;
    final double frac = wrapped - i0;
    return buf[i0] * (1.0 - frac) + buf[i1] * frac;
  }

  static double _tanh(double x) {
    final double e2x = math.exp(2.0 * x.clamp(-10.0, 10.0));
    return (e2x - 1.0) / (e2x + 1.0);
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
