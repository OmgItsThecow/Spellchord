import '../models/chord_spec.dart';
import '../models/midi_pitch.dart';
import 'voice_leading_engine.dart';

/// Standard and alternate guitar tunings expressed as base open-string MIDI pitches
/// ordered from lowest string (index 0) to highest string (index n-1).
class GuitarTuningPreset {
  const GuitarTuningPreset({
    required this.name,
    required this.openStringMidi,
  });

  final String name;
  final List<int> openStringMidi;

  static const GuitarTuningPreset standard = GuitarTuningPreset(
    name: 'Standard (E-A-D-G-B-E)',
    openStringMidi: <int>[40, 45, 50, 55, 59, 64],
  );

  static const GuitarTuningPreset dropD = GuitarTuningPreset(
    name: 'Drop D (D-A-D-G-B-E)',
    openStringMidi: <int>[38, 45, 50, 55, 59, 64],
  );

  static const GuitarTuningPreset dadgad = GuitarTuningPreset(
    name: 'DADGAD (D-A-D-G-A-D)',
    openStringMidi: <int>[38, 45, 50, 55, 57, 62],
  );

  static const GuitarTuningPreset openG = GuitarTuningPreset(
    name: 'Open G (D-G-D-G-B-D)',
    openStringMidi: <int>[38, 43, 50, 55, 59, 62],
  );

  static const GuitarTuningPreset allFourths = GuitarTuningPreset(
    name: 'All Fourths (E-A-D-G-C-F)',
    openStringMidi: <int>[40, 45, 50, 55, 60, 65],
  );

  static const List<GuitarTuningPreset> all = <GuitarTuningPreset>[
    standard,
    dropD,
    dadgad,
    openG,
    allFourths,
  ];
}

/// Named string-mask filters for common guitar string sets.
class GuitarStringMaskPreset {
  const GuitarStringMaskPreset({
    required this.label,
    required this.mask,
  });

  final String label;
  final List<bool> mask;

  static const GuitarStringMaskPreset allSix = GuitarStringMaskPreset(
    label: 'All 6 Strings',
    mask: <bool>[true, true, true, true, true, true],
  );

  static const GuitarStringMaskPreset topFour = GuitarStringMaskPreset(
    label: 'Top 4 (D-G-B-E)',
    mask: <bool>[false, false, true, true, true, true],
  );

  static const GuitarStringMaskPreset middleFour = GuitarStringMaskPreset(
    label: 'Mid 4 (A-D-G-B)',
    mask: <bool>[false, true, true, true, true, false],
  );

  static const GuitarStringMaskPreset bottomFour = GuitarStringMaskPreset(
    label: 'Low 4 (E-A-D-G)',
    mask: <bool>[true, true, true, true, false, false],
  );

  static const List<GuitarStringMaskPreset> presetsForSixStrings =
      <GuitarStringMaskPreset>[
    allSix,
    topFour,
    middleFour,
    bottomFour,
  ];
}

/// Per-string state of a computed guitar chord voicing.
class GuitarFretNote {
  const GuitarFretNote({
    required this.stringIndex,
    required this.openMidi,
    required this.isEnabled,
    required this.fret,
    required this.isRoot,
    required this.isBass,
  });

  final int stringIndex;
  final int openMidi;

  /// Controlled by the user's boolean string mask. False means muted/excluded.
  final bool isEnabled;

  /// Fret number (0 = open, 1..14 = fretted, null = muted/unplayed).
  final int? fret;
  final bool isRoot;
  final bool isBass;

  int? get soundedMidi =>
      (isEnabled && fret != null) ? MidiPitch.clampMidi(openMidi + fret!) : null;
}

/// Complete playable fretboard voicing across all strings in the tuning array.
class GuitarVoicing {
  const GuitarVoicing({
    required this.stringNotes,
    required this.inversionIndex,
    required this.score,
    required this.minFret,
    required this.maxFret,
  });

  final List<GuitarFretNote> stringNotes;
  final int inversionIndex;
  final double score;
  final int minFret;
  final int maxFret;

  List<int> get activeMidiPitches {
    final List<int> notes = <int>[];
    for (final GuitarFretNote sn in stringNotes) {
      final int? midi = sn.soundedMidi;
      if (midi != null) {
        notes.add(midi);
      }
    }
    notes.sort();
    return notes;
  }

  int? get bassMidi {
    final List<int> notes = activeMidiPitches;
    return notes.isEmpty ? null : notes.first;
  }
}

/// Computes playable guitar voicings driven by an arbitrary open-string MIDI
/// array and boolean string-filtering mask.
class GuitarVoicingSolver {
  GuitarVoicingSolver._();

  static const int maxFretNumber = 14;
  static const int maxPlayableFretSpan = 4;

  /// Solves voicings across a progression respecting [openStringMidi] and [stringMask].
  static List<GuitarVoicing> solveProgression({
    required List<ChordSpec> progression,
    required List<int> openStringMidi,
    required List<bool> stringMask,
    List<int>? targetInversions,
  }) {
    final List<GuitarVoicing> solved = <GuitarVoicing>[];
    List<int>? prevMidi;

    for (int i = 0; i < progression.length; i++) {
      final ChordSpec chord = progression[i];
      final int? forcedInv = chord.manualInversion ??
          (targetInversions != null && i < targetInversions.length
              ? targetInversions[i]
              : null);

      final GuitarVoicing voicing = solveChord(
        chord: chord,
        openStringMidi: openStringMidi,
        stringMask: stringMask,
        targetInversion: forcedInv,
        previousGuitarMidi: prevMidi,
      );

      solved.add(voicing);
      final List<int> active = voicing.activeMidiPitches;
      if (active.isNotEmpty) {
        prevMidi = active;
      }
    }

    return solved;
  }

  /// Finds the optimal playable guitar voicing for [chord] using only enabled
  /// strings (`stringMask[i] == true`) within a 4-fret hand span.
  static GuitarVoicing solveChord({
    required ChordSpec chord,
    required List<int> openStringMidi,
    required List<bool> stringMask,
    int? targetInversion,
    List<int>? previousGuitarMidi,
  }) {
    final int numStrings = openStringMidi.length;
    final List<bool> normalizedMask = List<bool>.generate(
      numStrings,
      (int i) => i < stringMask.length ? stringMask[i] : true,
    );

    final List<int> enabledStrings = <int>[
      for (int i = 0; i < numStrings; i++)
        if (normalizedMask[i]) i,
    ];

    if (enabledStrings.isEmpty) {
      return GuitarVoicing(
        stringNotes: <GuitarFretNote>[
          for (int i = 0; i < numStrings; i++)
            GuitarFretNote(
              stringIndex: i,
              openMidi: openStringMidi[i],
              isEnabled: false,
              fret: null,
              isRoot: false,
              isBass: false,
            ),
        ],
        inversionIndex: targetInversion ?? 0,
        score: 0.0,
        minFret: 0,
        maxFret: 0,
      );
    }

    final int invCount = chord.inversionCount.clamp(1, 12);
    final List<int> primaryInversions = targetInversion != null
        ? <int>[((targetInversion % invCount) + invCount) % invCount]
        : List<int>.generate(invCount, (int i) => i);

    final Set<int> allowedPcs = chord.pitchClasses.toSet();
    final List<GuitarVoicing> candidates = <GuitarVoicing>[];

    // Contiguous enabled-string subsets (e.g., all 4 enabled top strings,
    // or strings 5..1 when all 6 are enabled).
    final int minSliceLength = enabledStrings.length.clamp(1, 4);

    void collectForInversions(List<int> inversions) {
      for (final int inv in inversions) {
        final int bassPc = chord.bassPitchClassForInversion(inv);

        for (int startIdx = 0;
            startIdx <= enabledStrings.length - minSliceLength;
            startIdx++) {
          final List<int> subStrings = enabledStrings.sublist(startIdx);
          final int budget = subStrings.length;
          final List<int> essentialPcs = _essentialPitchClasses(
            chord: chord,
            bassPc: bassPc,
            maxVoices: budget,
          );

          _searchWindowsForSlice(
            chord: chord,
            openStringMidi: openStringMidi,
            normalizedMask: normalizedMask,
            subStrings: subStrings,
            bassPc: bassPc,
            inversionIndex: inv,
            essentialPcs: essentialPcs,
            allowedPcs: allowedPcs,
            previousGuitarMidi: previousGuitarMidi,
            candidates: candidates,
          );
        }
      }
    }

    collectForInversions(primaryInversions);

    // If a forced inversion cannot be realized on the currently active string mask
    // and tuning, fall back to any playable inversion on the enabled strings.
    if (candidates.isEmpty && targetInversion != null && invCount > 1) {
      final List<int> otherInversions = <int>[
        for (int i = 0; i < invCount; i++)
          if (i != primaryInversions.first) i,
      ];
      collectForInversions(otherInversions);
    }

    if (candidates.isNotEmpty) {
      candidates.sort((GuitarVoicing a, GuitarVoicing b) {
        return a.score.compareTo(b.score);
      });
      return candidates.first;
    }

    // Graceful fallback when fewer than 3 strings are enabled or custom tuning
    // prevents a complete chord realization.
    return _partialFallbackVoicing(
      chord: chord,
      openStringMidi: openStringMidi,
      normalizedMask: normalizedMask,
      enabledStrings: enabledStrings,
      inversionIndex: primaryInversions.first,
    );
  }

  static void _searchWindowsForSlice({
    required ChordSpec chord,
    required List<int> openStringMidi,
    required List<bool> normalizedMask,
    required List<int> subStrings,
    required int bassPc,
    required int inversionIndex,
    required List<int> essentialPcs,
    required Set<int> allowedPcs,
    required List<int>? previousGuitarMidi,
    required List<GuitarVoicing> candidates,
  }) {
    final int bassString = subStrings.first;
    final List<int> bassOpenOrFretted = <int>[];
    for (int f = 0; f <= maxFretNumber; f++) {
      if (MidiPitch.pitchClass(openStringMidi[bassString] + f) == bassPc) {
        bassOpenOrFretted.add(f);
      }
    }

    for (final int bassFret in bassOpenOrFretted) {
      // Establish permissible fret window anchored near bassFret.
      final int minWindow = bassFret == 0 ? 1 : (bassFret - 3).clamp(1, maxFretNumber);
      final int maxWindow =
          bassFret == 0 ? 4 : (bassFret + maxPlayableFretSpan).clamp(1, maxFretNumber);

      for (int wStart = minWindow; wStart <= maxWindow; wStart++) {
        final int wEnd = (wStart + maxPlayableFretSpan - 1).clamp(wStart, maxFretNumber);
        if (bassFret != 0 && (bassFret < wStart || bassFret > wEnd)) {
          continue;
        }

        // Gather allowed frets for each remaining string in subStrings.
        final List<List<int>> perStringOptions = <List<int>>[
          <int>[bassFret],
        ];
        bool possible = true;

        for (int idx = 1; idx < subStrings.length; idx++) {
          final int s = subStrings[idx];
          final List<int> opts = <int>[];
          // Allow open string when in low position (wStart <= 3).
          if (wStart <= 3 &&
              allowedPcs.contains(MidiPitch.pitchClass(openStringMidi[s]))) {
            opts.add(0);
          }
          for (int f = wStart; f <= wEnd; f++) {
            final int midi = openStringMidi[s] + f;
            if (allowedPcs.contains(MidiPitch.pitchClass(midi))) {
              opts.add(f);
            }
          }
          if (opts.isEmpty) {
            possible = false;
            break;
          }
          perStringOptions.add(opts);
        }

        if (!possible) {
          continue;
        }

        _enumerateFretCombinations(
          chord: chord,
          openStringMidi: openStringMidi,
          normalizedMask: normalizedMask,
          subStrings: subStrings,
          perStringOptions: perStringOptions,
          essentialPcs: essentialPcs,
          inversionIndex: inversionIndex,
          previousGuitarMidi: previousGuitarMidi,
          candidates: candidates,
        );
      }
    }
  }

  static void _enumerateFretCombinations({
    required ChordSpec chord,
    required List<int> openStringMidi,
    required List<bool> normalizedMask,
    required List<int> subStrings,
    required List<List<int>> perStringOptions,
    required List<int> essentialPcs,
    required int inversionIndex,
    required List<int>? previousGuitarMidi,
    required List<GuitarVoicing> candidates,
  }) {
    final List<int> currentFrets = List<int>.filled(subStrings.length, 0);

    void dfs(int depth) {
      if (depth == subStrings.length) {
        final List<int> soundedMidi = <int>[];
        final Set<int> soundedPcs = <int>{};
        int minPositiveFret = 99;
        int maxPositiveFret = 0;

        for (int i = 0; i < subStrings.length; i++) {
          final int s = subStrings[i];
          final int f = currentFrets[i];
          final int midi = openStringMidi[s] + f;
          soundedMidi.add(midi);
          soundedPcs.add(MidiPitch.pitchClass(midi));
          if (f > 0) {
            if (f < minPositiveFret) {
              minPositiveFret = f;
            }
            if (f > maxPositiveFret) {
              maxPositiveFret = f;
            }
          }
        }

        // Enforce ergonomic fret span <= 4 across fretted notes.
        if (maxPositiveFret > 0 &&
            (maxPositiveFret - minPositiveFret) > maxPlayableFretSpan) {
          return;
        }

        // Verify essential chord-tone coverage.
        if (!soundedPcs.containsAll(essentialPcs)) {
          return;
        }

        // Verify bass note is genuinely the lowest sounded MIDI pitch.
        final int lowestMidi = soundedMidi.first;
        for (int i = 1; i < soundedMidi.length; i++) {
          if (soundedMidi[i] < lowestMidi) {
            return;
          }
        }

        final List<int> sortedMidi = List<int>.from(soundedMidi)..sort();
        final double vlCost = VoiceLeadingEngine.evaluateTransition(
          previousGuitarMidi,
          sortedMidi,
        ).cost;

        final int fretSpan =
            maxPositiveFret == 0 ? 0 : (maxPositiveFret - minPositiveFret);
        final double positionBias = maxPositiveFret * 0.25;
        final double spanPenalty = fretSpan * 0.6;
        final double utilizationBonus = -subStrings.length * 0.35;
        final double invBias =
            previousGuitarMidi == null && inversionIndex > 0 ? 1.2 : 0.0;

        final double totalScore =
            vlCost + positionBias + spanPenalty + utilizationBonus + invBias;

        final Map<int, int> fretByString = <int, int>{
          for (int i = 0; i < subStrings.length; i++)
            subStrings[i]: currentFrets[i],
        };

        final List<GuitarFretNote> notes = <GuitarFretNote>[];
        for (int s = 0; s < openStringMidi.length; s++) {
          final int? fret = normalizedMask[s] ? fretByString[s] : null;
          final int? midi =
              fret != null ? MidiPitch.clampMidi(openStringMidi[s] + fret) : null;
          notes.add(
            GuitarFretNote(
              stringIndex: s,
              openMidi: openStringMidi[s],
              isEnabled: normalizedMask[s],
              fret: fret,
              isRoot: midi != null &&
                  MidiPitch.pitchClass(midi) == chord.normalizedRootPc,
              isBass: s == subStrings.first && fret != null,
            ),
          );
        }

        candidates.add(
          GuitarVoicing(
            stringNotes: notes,
            inversionIndex: inversionIndex,
            score: totalScore,
            minFret: maxPositiveFret == 0 ? 0 : minPositiveFret,
            maxFret: maxPositiveFret,
          ),
        );
        return;
      }

      for (final int f in perStringOptions[depth]) {
        currentFrets[depth] = f;
        dfs(depth + 1);
      }
    }

    dfs(0);
  }

  static List<int> _essentialPitchClasses({
    required ChordSpec chord,
    required int bassPc,
    required int maxVoices,
  }) {
    final List<int> pcs = <int>[bassPc];
    final int targetCount = maxVoices.clamp(1, 4);
    for (final int pc in chord.prioritizedPitchClasses) {
      if (pcs.length >= targetCount) {
        break;
      }
      if (!pcs.contains(pc)) {
        pcs.add(pc);
      }
    }
    return pcs;
  }

  static GuitarVoicing _partialFallbackVoicing({
    required ChordSpec chord,
    required List<int> openStringMidi,
    required List<bool> normalizedMask,
    required List<int> enabledStrings,
    required int inversionIndex,
  }) {
    final Set<int> chordPcs = chord.pitchClasses.toSet();
    final Map<int, int> chosenFrets = <int, int>{};

    for (final int s in enabledStrings) {
      for (int f = 0; f <= 7; f++) {
        if (chordPcs.contains(MidiPitch.pitchClass(openStringMidi[s] + f))) {
          chosenFrets[s] = f;
          break;
        }
      }
    }

    final int? firstSoundedString =
        chosenFrets.keys.isEmpty ? null : chosenFrets.keys.reduce((a, b) => a < b ? a : b);

    final List<GuitarFretNote> notes = <GuitarFretNote>[];
    int minF = 99;
    int maxF = 0;

    for (int s = 0; s < openStringMidi.length; s++) {
      final int? f = normalizedMask[s] ? chosenFrets[s] : null;
      if (f != null && f > 0) {
        if (f < minF) {
          minF = f;
        }
        if (f > maxF) {
          maxF = f;
        }
      }
      final int? midi =
          f != null ? MidiPitch.clampMidi(openStringMidi[s] + f) : null;
      notes.add(
        GuitarFretNote(
          stringIndex: s,
          openMidi: openStringMidi[s],
          isEnabled: normalizedMask[s],
          fret: f,
          isRoot: midi != null &&
              MidiPitch.pitchClass(midi) == chord.normalizedRootPc,
          isBass: s == firstSoundedString && f != null,
        ),
      );
    }

    return GuitarVoicing(
      stringNotes: notes,
      inversionIndex: inversionIndex,
      score: 999.0,
      minFret: maxF == 0 ? 0 : minF,
      maxFret: maxF,
    );
  }
}
