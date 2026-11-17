import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/engine/voice_leading_engine.dart';
import 'package:harmonic_explorer/core/models/chord_spec.dart';
import 'package:harmonic_explorer/core/models/chord_voicing.dart';
import 'package:harmonic_explorer/core/models/midi_pitch.dart';

void main() {
  group('VoiceLeadingEngine', () {
    test('minimizes total semitone movement and preserves common tones across ii-V-I', () {
      final List<ChordSpec> progression = <ChordSpec>[
        ChordSpec.minor7(2, id: 'dm7'), // Dm7: D F A C
        ChordSpec.dominant7(7, id: 'g7'), // G7: G B D F
        ChordSpec.major7(0, id: 'cmaj7'), // Cmaj7: C E G B
      ];

      final List<ChordVoicing> voicings =
          VoiceLeadingEngine.solveProgression(progression);
      expect(voicings.length, 3);

      // Every MIDI note stays inside valid 0..127 bounds and sorted ascending
      for (final ChordVoicing v in voicings) {
        expect(v.midiNotes.length, 4);
        for (int i = 0; i < v.midiNotes.length; i++) {
          expect(v.midiNotes[i], inInclusiveRange(0, 127));
          if (i > 0) {
            expect(v.midiNotes[i], greaterThan(v.midiNotes[i - 1]));
          }
        }
      }

      // Smooth voice leading across Dm7 -> G7 -> Cmaj7 should require small semitone travel
      expect(voicings[1].totalSemitoneDistance, lessThanOrEqualTo(6));
      expect(voicings[1].commonToneCount, greaterThanOrEqualTo(1));
      expect(voicings[2].totalSemitoneDistance, lessThanOrEqualTo(6));
      expect(voicings[2].commonToneCount, greaterThanOrEqualTo(1));
    });

    test('honors manual inversion override and places correct bass pitch class', () {
      final ChordSpec chord = ChordSpec.major7(0, id: 'cmaj7').copyWith(
        manualInversion: 2, // 2nd inversion -> G (7) in bass
      );

      final List<ChordVoicing> voicings =
          VoiceLeadingEngine.solveProgression(<ChordSpec>[chord]);
      expect(voicings.length, 1);
      expect(voicings.first.inversionIndex, 2);
      expect(MidiPitch.pitchClass(voicings.first.bassMidi), 7);
    });

    test('produces distinct candidate voicings per inversion', () {
      final ChordSpec g7 = ChordSpec.dominant7(7, id: 'g7');
      final List<ChordVoicing> inversions =
          VoiceLeadingEngine.bestVoicingPerInversion(
        g7,
        previousMidi: const <int>[50, 53, 57, 60], // Dm7
      );

      expect(inversions.length, 4);
      final Set<int> bassPcs =
          inversions.map((ChordVoicing v) => v.bassPc).toSet();
      expect(bassPcs, equals(<int>{7, 11, 2, 5}));
    });
  });
}
