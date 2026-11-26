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

    test('prefers open Dmaj7 (0-2-2-2) over fret 12 when switching duplicated Dmaj7/A to root position on top 4 strings', () {
      final ChordSpec dmaj7OverA = ChordSpec.major7(
        2,
        id: 'dmaj7_a',
      ).copyWith(manualInversion: 2); // Dmaj7/A
      final ChordSpec dmaj7Root = ChordSpec.major7(
        2,
        id: 'dmaj7_root',
      ).copyWith(manualInversion: 0); // Dmaj7

      final List<GuitarVoicing> solved = GuitarVoicingSolver.solveProgression(
        progression: <ChordSpec>[dmaj7OverA, dmaj7Root],
        openStringMidi: GuitarTuningPreset.standard.openStringMidi,
        stringMask: GuitarStringMaskPreset.topFour.mask,
      );

      final GuitarVoicing rootVoicing = solved[1];
      // D string (index 2) should be open (fret 0), and top frets at 2 (0-2-2-2)
      expect(rootVoicing.stringNotes[2].fret, 0);
      expect(rootVoicing.maxFret, lessThanOrEqualTo(4));
    });
  });
}
