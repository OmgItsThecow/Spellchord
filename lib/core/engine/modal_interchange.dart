import '../models/chord_spec.dart';
import '../models/harmonic_function.dart';
import '../models/interval_profile.dart';
import '../models/midi_pitch.dart';
import '../models/scale_mode.dart';
import 'harmonic_analyzer.dart';
import 'voice_leading_engine.dart';

/// A candidate borrowed chord substitution derived from a parallel mode.
class BorrowedChordSuggestion {
  const BorrowedChordSuggestion({
    required this.chord,
    required this.romanNumeral,
    required this.sourceMode,
    required this.allSourceModes,
    required this.category,
    required this.scaleDegreeIndex,
    required this.voiceLeadingDistance,
    required this.commonTonesWithCurrent,
    required this.explanation,
  });

  final ChordSpec chord;
  final String romanNumeral;
  final ScaleMode sourceMode;
  final List<ScaleMode> allSourceModes;
  final HarmonicCategory category;
  final int scaleDegreeIndex;
  final double voiceLeadingDistance;
  final int commonTonesWithCurrent;
  final String explanation;
}

/// Compares the active tonal center against all parallel modes (Dorian,
/// Phrygian, Lydian, Mixolydian, Aeolian, Locrian, plus Ionian when minor)
/// and surfaces valid borrowed chord substitutions with voice-leading metrics.
class ModalInterchangeExplorer {
  ModalInterchangeExplorer._();

  static const List<ScaleMode> _comparisonOrder = <ScaleMode>[
    ScaleMode.aeolian,
    ScaleMode.dorian,
    ScaleMode.mixolydian,
    ScaleMode.lydian,
    ScaleMode.phrygian,
    ScaleMode.locrian,
    ScaleMode.ionian,
  ];

  /// Generates deduplicated borrowed chord substitutions for [selectedChord]
  /// in the active tonal center ([keyTonicPc], [keyMode]).
  static List<BorrowedChordSuggestion> exploreBorrowedChords({
    required int keyTonicPc,
    required ScaleMode keyMode,
    required ChordSpec selectedChord,
    List<int>? previousMidi,
    bool includeTriads = true,
    bool includeSevenths = true,
    bool preferFlat = false,
  }) {
    final int normTonic = MidiPitch.pitchClass(keyTonicPc);
    final Set<int> activeKeyPcs = keyMode.pitchClassSet(normTonic);
    final Set<int> selectedPcs = selectedChord.pitchClasses.toSet();

    final Map<String, _BorrowedAccum> accumulated = <String, _BorrowedAccum>{};

    for (final ScaleMode mode in _comparisonOrder) {
      if (mode == keyMode) {
        continue;
      }

      final List<int> modeIntervals = mode.semitoneIntervals;
      for (int deg = 0; deg < 7; deg++) {
        final int rootOffset = modeIntervals[deg];
        final int rootPc = (normTonic + rootOffset) % 12;

        final int thirdInterval =
            (modeIntervals[(deg + 2) % 7] - rootOffset + 12) % 12;
        final int fifthInterval =
            (modeIntervals[(deg + 4) % 7] - rootOffset + 12) % 12;
        final int seventhInterval =
            (modeIntervals[(deg + 6) % 7] - rootOffset + 12) % 12;

        final TriadQuality? triad = _triadFromIntervals(thirdInterval, fifthInterval);
        if (triad == null) {
          continue;
        }

        if (includeTriads) {
          final ChordSpec triadChord = ChordSpec(
            id: 'borrowed_${mode.name}_${deg}_triad',
            rootPc: rootPc,
            triad: triad,
          );
          _maybeAccumulate(
            accumulated: accumulated,
            candidate: triadChord,
            mode: mode,
            degreeIndex: deg,
            activeKeyPcs: activeKeyPcs,
            selectedChord: selectedChord,
          );
        }

        if (includeSevenths) {
          final SeventhQuality? seventh =
              _seventhFromIntervals(triad, seventhInterval);
          if (seventh != null) {
            final ChordSpec seventhChord = ChordSpec(
              id: 'borrowed_${mode.name}_${deg}_7th',
              rootPc: rootPc,
              triad: triad,
              seventh: seventh,
            );
            _maybeAccumulate(
              accumulated: accumulated,
              candidate: seventhChord,
              mode: mode,
              degreeIndex: deg,
              activeKeyPcs: activeKeyPcs,
              selectedChord: selectedChord,
            );
          }
        }
      }
    }

    final List<BorrowedChordSuggestion> results = <BorrowedChordSuggestion>[];
    for (final _BorrowedAccum entry in accumulated.values) {
      final String modalRoman = HarmonicAnalyzer.modalRomanNumeral(
        entry.chord,
        keyTonicPc: normTonic,
      );

      final double vlDist = VoiceLeadingEngine.minimalVoiceLeadingDistance(
        candidateChord: entry.chord,
        previousMidi: previousMidi,
      );

      final Set<int> candPcs = entry.chord.pitchClasses.toSet();
      final int sharedWithCurrent =
          candPcs.where((int pc) => selectedPcs.contains(pc)).length;

      final ScaleMode primaryMode = entry.modes.first;
      final String keyName =
          MidiPitch.pitchClassName(normTonic, preferFlat: preferFlat);
      final String chordSymbol = entry.chord.baseSymbol(preferFlat: preferFlat);

      final String explanation =
          'Borrowed $modalRoman ($chordSymbol) from $keyName '
          '${primaryMode.shortLabel} (${primaryMode.characteristicNoteDescription})';

      results.add(
        BorrowedChordSuggestion(
          chord: entry.chord,
          romanNumeral: modalRoman,
          sourceMode: primaryMode,
          allSourceModes: List<ScaleMode>.unmodifiable(entry.modes),
          category: HarmonicCategory.borrowed,
          scaleDegreeIndex: entry.degreeIndex,
          voiceLeadingDistance: vlDist,
          commonTonesWithCurrent: sharedWithCurrent,
          explanation: explanation,
        ),
      );
    }

    // Prioritize:
    // 1. Chords on same scale degree or +/-1 semitone from selected chord
    // 2. Smooth voice-leading distance from preceding chord
    // 3. Shared common tones with selected chord
    results.sort((BorrowedChordSuggestion a, BorrowedChordSuggestion b) {
      final int aRootDist = MidiPitch.minimalPitchClassDistance(
        a.chord.normalizedRootPc,
        selectedChord.normalizedRootPc,
      );
      final int bRootDist = MidiPitch.minimalPitchClassDistance(
        b.chord.normalizedRootPc,
        selectedChord.normalizedRootPc,
      );
      final bool aSameSlot = aRootDist <= 1;
      final bool bSameSlot = bRootDist <= 1;
      if (aSameSlot != bSameSlot) {
        return aSameSlot ? -1 : 1;
      }

      final int vlCmp =
          a.voiceLeadingDistance.compareTo(b.voiceLeadingDistance);
      if (vlCmp != 0) {
        return vlCmp;
      }

      final int commonCmp =
          b.commonTonesWithCurrent.compareTo(a.commonTonesWithCurrent);
      if (commonCmp != 0) {
        return commonCmp;
      }

      return a.scaleDegreeIndex.compareTo(b.scaleDegreeIndex);
    });

    return results;
  }

  static void _maybeAccumulate({
    required Map<String, _BorrowedAccum> accumulated,
    required ChordSpec candidate,
    required ScaleMode mode,
    required int degreeIndex,
    required Set<int> activeKeyPcs,
    required ChordSpec selectedChord,
  }) {
    final Set<int> candPcs = candidate.pitchClasses.toSet();
    // Skip chords completely diatonic to the active key center.
    if (activeKeyPcs.containsAll(candPcs)) {
      return;
    }
    // Skip identical replacement of the exact same chord already in the slot.
    if (candidate.normalizedRootPc == selectedChord.normalizedRootPc &&
        candidate.triad == selectedChord.triad &&
        candidate.seventh == selectedChord.seventh) {
      return;
    }

    final String key =
        '${candidate.normalizedRootPc}_${candidate.triad.name}_${candidate.seventh.name}';
    final _BorrowedAccum? existing = accumulated[key];
    if (existing != null) {
      if (!existing.modes.contains(mode)) {
        existing.modes.add(mode);
      }
      return;
    }

    accumulated[key] = _BorrowedAccum(
      chord: candidate,
      degreeIndex: degreeIndex,
      modes: <ScaleMode>[mode],
    );
  }

  static TriadQuality? _triadFromIntervals(int third, int fifth) {
    if (third == 4 && fifth == 7) {
      return TriadQuality.major;
    }
    if (third == 3 && fifth == 7) {
      return TriadQuality.minor;
    }
    if (third == 3 && fifth == 6) {
      return TriadQuality.diminished;
    }
    if (third == 4 && fifth == 8) {
      return TriadQuality.augmented;
    }
    return null;
  }

  static SeventhQuality? _seventhFromIntervals(
    TriadQuality triad,
    int seventhInterval,
  ) {
    if (triad == TriadQuality.major) {
      if (seventhInterval == 11) {
        return SeventhQuality.major7;
      }
      if (seventhInterval == 10) {
        return SeventhQuality.dominant7;
      }
    } else if (triad == TriadQuality.minor) {
      if (seventhInterval == 10) {
        return SeventhQuality.minor7;
      }
      if (seventhInterval == 11) {
        return SeventhQuality.minorMajor7;
      }
    } else if (triad == TriadQuality.diminished) {
      if (seventhInterval == 10) {
        return SeventhQuality.halfDiminished7;
      }
      if (seventhInterval == 9) {
        return SeventhQuality.diminished7;
      }
    }
    return null;
  }
}

class _BorrowedAccum {
  _BorrowedAccum({
    required this.chord,
    required this.degreeIndex,
    required this.modes,
  });

  final ChordSpec chord;
  final int degreeIndex;
  final List<ScaleMode> modes;
}
