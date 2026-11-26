import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/audio/chord_synthesizer.dart';
import 'package:harmonic_explorer/core/audio/guitar_sample_bank.dart';
import 'package:harmonic_explorer/state/explorer_controller.dart';

void main() {
  group('ChordSynthesizer', () {
    test('converts MIDI 69 to 440 Hz', () {
      expect(ChordSynthesizer.midiToFrequency(69), closeTo(440.0, 1e-6));
      expect(ChordSynthesizer.midiToFrequency(57), closeTo(220.0, 1e-6));
    });

    test('synthesizes valid RIFF WAV bytes for piano and guitar chords', () {
      final List<int> cMaj7 = <int>[48, 52, 55, 59];

      for (final SynthInstrument instrument in SynthInstrument.values) {
        final Uint8List wav = ChordSynthesizer.synthesizeChordWav(
          midiNotes: cMaj7,
          instrument: instrument,
        );

        expect(wav.length, greaterThan(44));
        // 'RIFF'
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        // 'WAVE'
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        // 'fmt '
        expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
        // 'data'
        expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

        // Verify non-zero audio energy in PCM samples
        final ByteData data = ByteData.sublistView(wav, 44);
        int maxAbs = 0;
        for (int offset = 0; offset + 1 < data.lengthInBytes; offset += 2) {
          final int sample = data.getInt16(offset, Endian.little).abs();
          if (sample > maxAbs) {
            maxAbs = sample;
          }
        }
        expect(maxAbs, greaterThan(1000));
      }
    });

    test('handles empty note list gracefully', () {
      final Uint8List wav = ChordSynthesizer.synthesizeChordWav(
        midiNotes: const <int>[],
        instrument: SynthInstrument.piano,
      );
      expect(wav.length, 44);
    });

    test('guitar synthesis sustains clear chord tone without noise dominance', () {
      final Uint8List wav = ChordSynthesizer.synthesizeChordWav(
        midiNotes: const <int>[40, 47, 52, 56, 59, 64],
        instrument: SynthInstrument.guitar,
      );
      final ByteData data = ByteData.sublistView(wav, 44);
      const int rate = ChordSynthesizer.sampleRate;
      final int sustainStart = (0.15 * rate).round();
      final int sustainEnd = (0.60 * rate).round();

      double sumSq = 0.0;
      int count = 0;
      for (int i = sustainStart; i < sustainEnd; i++) {
        final double sample = data.getInt16(i * 2, Endian.little) / 32767.0;
        sumSq += sample * sample;
        count++;
      }
      final double sustainRms = sumSq > 0 ? (sumSq / count) : 0.0;
      // Sustain region should carry substantial musical energy (RMS > 0.12).
      expect(sustainRms, greaterThan(0.12 * 0.12));
    });

    test('decodes all bundled electric guitar multisamples and renders dream-pop chord', () {
      final Map<int, Float64List> bank = <int, Float64List>{};
      for (final MapEntry<int, String> entry
          in GuitarSampleBank.sampleAssets.entries) {
        final File file = File(entry.value);
        expect(file.existsSync(), isTrue, reason: 'Missing ${entry.value}');
        final Float64List decoded =
            GuitarSampleBank.decodeWavPcm16(file.readAsBytesSync());
        expect(decoded.length, greaterThan(10000));
        bank[entry.key] = decoded;
      }

      expect(GuitarSampleBank.nearestBaseMidi(42, bank.keys), 40);
      expect(GuitarSampleBank.nearestBaseMidi(58, bank.keys), 56);
      expect(GuitarSampleBank.nearestBaseMidi(65, bank.keys), 64);

      final Uint8List wav = ChordSynthesizer.synthesizeChordWav(
        midiNotes: const <int>[48, 55, 59, 64, 67],
        instrument: SynthInstrument.guitar,
        guitarSamples: bank,
      );
      expect(wav.length, greaterThan(44 + 40000 * 2));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    });
  });

  group('ExplorerController Audio Controls', () {
    test('toggles sound and triggers playback safely in headless tests', () {
      final ExplorerController controller = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(controller.dispose);

      expect(controller.soundEnabled, isTrue);
      controller.playSelectedChord();

      controller.setVisualizerMode(VisualizerMode.guitar);
      controller.playSelectedChord();

      controller.togglePlayProgression();
      expect(controller.isPlayingProgression, isTrue);
      controller.togglePlayProgression();
      expect(controller.isPlayingProgression, isFalse);

      controller.toggleSound();
      expect(controller.soundEnabled, isFalse);

      controller.toggleSound();
      expect(controller.soundEnabled, isTrue);
    });
  });
}
