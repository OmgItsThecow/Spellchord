import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/audio/chord_synthesizer.dart';
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
  });

  group('ExplorerController Audio Controls', () {
    test('toggles sound and triggers playback safely in headless tests', () {
      final ExplorerController controller =
          ExplorerController(loadPersistedPresets: false);
      addTearDown(controller.dispose);

      expect(controller.soundEnabled, isTrue);
      controller.playSelectedChord();

      controller.setVisualizerMode(VisualizerMode.guitar);
      controller.playSelectedChord();

      controller.toggleSound();
      expect(controller.soundEnabled, isFalse);

      controller.toggleSound();
      expect(controller.soundEnabled, isTrue);
    });
  });
}
