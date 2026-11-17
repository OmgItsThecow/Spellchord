import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/engine/modal_interchange.dart';
import 'package:harmonic_explorer/core/models/chord_spec.dart';
import 'package:harmonic_explorer/core/models/scale_mode.dart';

void main() {
  group('ModalInterchangeExplorer', () {
    test('surfaces classic borrowed chords in C Major across parallel modes', () {
      final ChordSpec selected = ChordSpec.major7(5, id: 'fmaj7'); // IVmaj7 in C
      final List<BorrowedChordSuggestion> suggestions =
          ModalInterchangeExplorer.exploreBorrowedChords(
        keyTonicPc: 0,
        keyMode: ScaleMode.ionian,
        selectedChord: selected,
        previousMidi: const <int>[48, 52, 55, 59], // Cmaj7
      );

      expect(suggestions, isNotEmpty);

      final List<String> numerals =
          suggestions.map((BorrowedChordSuggestion s) => s.romanNumeral).toList();

      // Expect borrowed chords from Aeolian, Phrygian, Lydian, Mixolydian, Dorian
      expect(numerals, contains('iv7'));
      expect(numerals, contains('bVIΔ7'));
      expect(numerals, contains('bVII7'));
      expect(numerals, contains('bIIΔ7'));
      expect(numerals, contains('II7'));

      // Verify source modes exclude the active mode (Ionian)
      for (final BorrowedChordSuggestion s in suggestions) {
        expect(s.sourceMode, isNot(ScaleMode.ionian));
        expect(s.allSourceModes, isNotEmpty);
      }
    });

    test('includes Ionian borrowed options when active key is Aeolian minor', () {
      final ChordSpec selected = ChordSpec.minor7(5, id: 'fm7'); // iv7 in C minor
      final List<BorrowedChordSuggestion> suggestions =
          ModalInterchangeExplorer.exploreBorrowedChords(
        keyTonicPc: 0,
        keyMode: ScaleMode.aeolian,
        selectedChord: selected,
      );

      final bool hasIonianBorrow = suggestions.any(
        (BorrowedChordSuggestion s) =>
            s.allSourceModes.contains(ScaleMode.ionian),
      );
      expect(hasIonianBorrow, isTrue);
    });
  });
}
