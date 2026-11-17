import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/engine/guitar_voicing_solver.dart';
import 'package:harmonic_explorer/core/models/chord_spec.dart';
import 'package:harmonic_explorer/core/models/midi_pitch.dart';

void main() {
  group('GuitarVoicingSolver', () {
    test('restricts chord voicing calculations strictly to top four strings when masked', () {
      final ChordSpec cmaj7 = ChordSpec.major7(0, id: 'cmaj7');
      final GuitarVoicing voicing = GuitarVoicingSolver.solveChord(
        chord: cmaj7,
        openStringMidi: GuitarTuningPreset.standard.openStringMidi,
        stringMask: GuitarStringMaskPreset.topFour.mask, // [false, false, true, true, true, true]
      );

      // Strings 0 (E2) and 1 (A2) must remain disabled and unplayed
      expect(voicing.stringNotes[0].isEnabled, isFalse);
      expect(voicing.stringNotes[0].fret, isNull);
      expect(voicing.stringNotes[1].isEnabled, isFalse);
      expect(voicing.stringNotes[1].fret, isNull);

      // Top four strings (D, G, B, E) produce active MIDI pitches inside chord pitch classes
      final List<int> active = voicing.activeMidiPitches;
      expect(active.length, 4);
      final Set<int> chordPcs = cmaj7.pitchClasses.toSet();
      for (final int midi in active) {
        expect(chordPcs, contains(MidiPitch.pitchClass(midi)));
      }

      // Playable 4-fret span check
      if (voicing.maxFret > 0) {
        expect(voicing.maxFret - voicing.minFret, lessThanOrEqualTo(4));
      }
    });

    test('adapts dynamically to custom string tunings such as DADGAD', () {
      final ChordSpec dMajor = ChordSpec.major(2, id: 'd_maj');
      final GuitarVoicing voicing = GuitarVoicingSolver.solveChord(
        chord: dMajor,
        openStringMidi: GuitarTuningPreset.dadgad.openStringMidi,
        stringMask: GuitarStringMaskPreset.allSix.mask,
      );

      final List<int> active = voicing.activeMidiPitches;
      expect(active, isNotEmpty);
      final Set<int> chordPcs = dMajor.pitchClasses.toSet();
      for (final int midi in active) {
        expect(chordPcs, contains(MidiPitch.pitchClass(midi)));
      }
      // Verify open strings match DADGAD MIDI integers
      expect(voicing.stringNotes[0].openMidi, 38); // D2
      expect(voicing.stringNotes[5].openMidi, 62); // D4
    });

    test('handles empty string mask gracefully without throwing', () {
      final ChordSpec g7 = ChordSpec.dominant7(7, id: 'g7');
      final GuitarVoicing voicing = GuitarVoicingSolver.solveChord(
        chord: g7,
        openStringMidi: GuitarTuningPreset.standard.openStringMidi,
        stringMask: const <bool>[false, false, false, false, false, false],
      );

      expect(voicing.activeMidiPitches, isEmpty);
      for (final GuitarFretNote note in voicing.stringNotes) {
        expect(note.isEnabled, isFalse);
        expect(note.fret, isNull);
      }
    });
  });
}
