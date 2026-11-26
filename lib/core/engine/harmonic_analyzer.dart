import '../models/chord_spec.dart';
import '../models/harmonic_function.dart';
import '../models/interval_profile.dart';
import '../models/midi_pitch.dart';
import '../models/scale_mode.dart';

/// Result of automatic tonal center detection across a chord progression.
class KeySignatureResult {
  const KeySignatureResult({
    required this.tonicPc,
    required this.mode,
    required this.confidenceScore,
  });

  final int tonicPc;
  final ScaleMode mode;
  final double confidenceScore;

  String label({bool preferFlat = false}) {
    final String root = MidiPitch.pitchClassName(tonicPc, preferFlat: preferFlat);
    final String modeName = mode == ScaleMode.ionian ? 'Major' : 'Minor';
    return '$root $modeName';
  }
}

/// Deterministic tonal-center detector and Roman-numeral harmonic analyzer.
class HarmonicAnalyzer {
  HarmonicAnalyzer._();

  static const List<ScaleMode> _borrowingPriority = <ScaleMode>[
    ScaleMode.aeolian,
    ScaleMode.dorian,
    ScaleMode.mixolydian,
    ScaleMode.lydian,
    ScaleMode.phrygian,
    ScaleMode.locrian,
    ScaleMode.ionian,
  ];

  /// Evaluates all 24 Major (Ionian) and Natural Minor (Aeolian) keys and
  /// returns the highest-scoring tonal center.
  static KeySignatureResult detectKeyCenter(List<ChordSpec> progression) {
    if (progression.isEmpty) {
      return const KeySignatureResult(
        tonicPc: 0,
        mode: ScaleMode.ionian,
        confidenceScore: 1.0,
      );
    }

    int bestTonic = 0;
    ScaleMode bestMode = ScaleMode.ionian;
    double bestScore = double.negativeInfinity;

    for (final ScaleMode mode in const <ScaleMode>[
      ScaleMode.ionian,
      ScaleMode.aeolian,
    ]) {
      for (int tonic = 0; tonic < 12; tonic++) {
        final double score = _scoreCandidateKey(progression, tonic, mode);
        if (score > bestScore) {
          bestScore = score;
          bestTonic = tonic;
          bestMode = mode;
        }
      }
    }

    return KeySignatureResult(
      tonicPc: bestTonic,
      mode: bestMode,
      confidenceScore: bestScore,
    );
  }

  static double _scoreCandidateKey(
    List<ChordSpec> progression,
    int tonicPc,
    ScaleMode mode,
  ) {
    final Set<int> scalePcs = mode.pitchClassSet(tonicPc);
    final List<int> modeIntervals = mode.semitoneIntervals;
    final bool isIonian = mode == ScaleMode.ionian;
    final int n = progression.length;
    double score = 0.0;

    for (int i = 0; i < n; i++) {
      final ChordSpec chord = progression[i];
      final Set<int> corePcs = _corePitchClasses(chord);
      final int rel = (chord.normalizedRootPc - tonicPc + 12) % 12;

      if (scalePcs.containsAll(corePcs)) {
        score += 3.0;
        // Extra weight when the chord's quality matches the diatonic triad on that degree.
        if (_matchesDiatonicTriad(chord, tonicPc, mode)) {
          score += 1.0;
        }
        // Unique diatonic V7 in Major (Ionian) strongly anchors the tonal center.
        if (isIonian &&
            rel == 7 &&
            chord.triad == TriadQuality.major &&
            chord.seventh == SeventhQuality.dominant7) {
          score += 1.8;
        }
      } else if (!isIonian &&
          _isHarmonicMinorDominantOrLeading(chord, tonicPc)) {
        score += 2.6;
      } else {
        // Partial pitch-class overlap still provides a weak clue.
        final int shared =
            corePcs.where((int pc) => scalePcs.contains(pc)).length;
        score += shared * 0.25;

        // Secondary dominant resolving down a fifth (up 5 semitones) to a non-tonic degree.
        final bool isDomStructure = (chord.triad == TriadQuality.major ||
                chord.triad == TriadQuality.sus4) &&
            (chord.seventh == SeventhQuality.none ||
                chord.seventh == SeventhQuality.dominant7);
        if (isDomStructure) {
          final int targetRel = (rel + 5) % 12;
          if (targetRel != 0 && modeIntervals.contains(targetRel)) {
            final ChordSpec nextCyclic = progression[(i + 1) % n];
            if ((nextCyclic.normalizedRootPc - tonicPc + 12) % 12 ==
                targetRel) {
              score += 1.6;
            }
          }
        }
      }

      // Sequential harmonic transitions.
      if (i < n - 1) {
        final ChordSpec next = progression[i + 1];
        final int relCur = rel;
        final int relNext = (next.normalizedRootPc - tonicPc + 12) % 12;
        final bool curHasMajor3rd =
            chord.intervals.contains(4) || chord.triad == TriadQuality.sus4;
        final bool curIsTonic = _tonicMatchesModeQuality(chord, mode);
        final bool nextIsTonic = _tonicMatchesModeQuality(next, mode);

        if (relCur == 7 && curHasMajor3rd && relNext == 0) {
          score += nextIsTonic ? 4.2 : 1.5;
        } else if ((relCur == 2 || relCur == 5) && relNext == 7) {
          if (!isIonian ||
              next.triad == TriadQuality.major ||
              next.triad == TriadQuality.sus4) {
            score += 2.2;
          }
        } else if (relCur == 5 && relNext == 0 && nextIsTonic) {
          score += 1.2;
        } else if (isIonian &&
            relCur == 0 &&
            curIsTonic &&
            relNext == 7 &&
            (next.triad == TriadQuality.major ||
                next.triad == TriadQuality.sus4)) {
          score += 1.0;
        } else if (isIonian &&
            relCur == 7 &&
            curHasMajor3rd &&
            (relNext == 9 || relNext == 4)) {
          score += 1.5;
        } else if (isIonian &&
            relCur == 4 &&
            relNext == 9 &&
            chord.triad == TriadQuality.minor &&
            next.triad == TriadQuality.minor) {
          score += 0.9;
        } else if (!isIonian &&
            relCur == 10 &&
            chord.triad == TriadQuality.major &&
            chord.seventh != SeventhQuality.dominant7 &&
            relNext == 0 &&
            nextIsTonic) {
          score += 0.8;
        }
      }
    }

    // Cyclic turnaround wrap-around check (V -> I/i or Aeolian bVII -> i).
    if (n >= 3) {
      final ChordSpec last = progression.last;
      final ChordSpec first = progression.first;
      final int relLast = (last.normalizedRootPc - tonicPc + 12) % 12;
      final int relFirst = (first.normalizedRootPc - tonicPc + 12) % 12;
      final bool lastHasMajor3rd =
          last.intervals.contains(4) || last.triad == TriadQuality.sus4;
      final bool firstIsTonic = _tonicMatchesModeQuality(first, mode);

      if (relLast == 7 && lastHasMajor3rd && relFirst == 0 && firstIsTonic) {
        score += 2.0;
      } else if (!isIonian &&
          relLast == 10 &&
          last.triad == TriadQuality.major &&
          last.seventh != SeventhQuality.dominant7 &&
          relFirst == 0 &&
          firstIsTonic) {
        score += 1.4;
      }
    }

    // Marusa ("Just the Two of Us") IVmaj -> iii7/III7 -> vi7 -> v7/I7 parent Major anchor.
    if (isIonian && _isMarusaParentMajor(progression, tonicPc)) {
      score += 14.0;
    }

    // Mild first and final chord tonic anchors (dominant 7ths excluded from Ionian tonic).
    if (progression.first.normalizedRootPc == tonicPc &&
        _tonicMatchesModeQuality(progression.first, mode)) {
      score += 1.6;
    }
    if (progression.last.normalizedRootPc == tonicPc &&
        _tonicMatchesModeQuality(progression.last, mode)) {
      score += 2.6;
    }

    return score;
  }

  static bool _isMarusaParentMajor(
    List<ChordSpec> progression,
    int tonicPc,
  ) {
    bool hasIvMaj = false;
    bool hasIii = false;
    bool hasViMin = false;
    bool hasVMinOrITurn = false;
    bool hasIiiToVi = false;

    for (int i = 0; i < progression.length; i++) {
      final ChordSpec c = progression[i];
      final int rel = (c.normalizedRootPc - tonicPc + 12) % 12;
      final bool isMajLike = c.triad == TriadQuality.major &&
          c.seventh != SeventhQuality.dominant7;
      final bool isDom7 = c.triad == TriadQuality.major &&
          c.seventh == SeventhQuality.dominant7;
      final bool isMinLike = c.triad == TriadQuality.minor;

      if (rel == 5 && isMajLike) {
        hasIvMaj = true;
      } else if (rel == 4 && (isMinLike || isDom7)) {
        hasIii = true;
      } else if (rel == 9 && isMinLike) {
        hasViMin = true;
      } else if ((rel == 7 && isMinLike) || (rel == 0 && isDom7)) {
        hasVMinOrITurn = true;
      }

      if (i < progression.length - 1) {
        final ChordSpec next = progression[i + 1];
        final int nextRel = (next.normalizedRootPc - tonicPc + 12) % 12;
        if (rel == 4 &&
            (isMinLike || isDom7) &&
            nextRel == 9 &&
            next.triad == TriadQuality.minor) {
          hasIiiToVi = true;
        }
      }
    }

    return hasIvMaj && hasIii && hasViMin && hasVMinOrITurn && hasIiiToVi;
  }

  static bool _tonicMatchesModeQuality(ChordSpec chord, ScaleMode mode) {
    if (mode == ScaleMode.ionian) {
      return (chord.triad == TriadQuality.major ||
              chord.triad == TriadQuality.sus2 ||
              chord.triad == TriadQuality.sus4) &&
          chord.seventh != SeventhQuality.dominant7;
    }
    return chord.triad == TriadQuality.minor;
  }

  static bool _matchesDiatonicTriad(
    ChordSpec chord,
    int tonicPc,
    ScaleMode mode,
  ) {
    final int rel = (chord.normalizedRootPc - tonicPc + 12) % 12;
    final List<int> intervals = mode.semitoneIntervals;
    final int degreeIdx = intervals.indexOf(rel);
    if (degreeIdx < 0) {
      return false;
    }
    final int thirdSemi =
        (intervals[(degreeIdx + 2) % 7] - intervals[degreeIdx] + 12) % 12;
    final int fifthSemi =
        (intervals[(degreeIdx + 4) % 7] - intervals[degreeIdx] + 12) % 12;
    return chord.intervals.contains(thirdSemi) &&
        chord.intervals.contains(fifthSemi);
  }

  static bool _isHarmonicMinorDominantOrLeading(ChordSpec chord, int tonicPc) {
    final int rel = (chord.normalizedRootPc - tonicPc + 12) % 12;
    if (rel == 7 &&
        (chord.triad == TriadQuality.major ||
            chord.triad == TriadQuality.sus4) &&
        (chord.seventh == SeventhQuality.none ||
            chord.seventh == SeventhQuality.dominant7)) {
      return true;
    }
    if (rel == 11 && chord.triad == TriadQuality.diminished) {
      return true;
    }
    return false;
  }

  /// Assigns a Roman numeral and harmonic function category to [chord]
  /// within the active tonal center ([keyTonicPc], [keyMode]).
  static HarmonicAnalysisResult analyzeChord({
    required ChordSpec chord,
    required int keyTonicPc,
    required ScaleMode keyMode,
    ChordSpec? nextChord,
  }) {
    final int normKey = MidiPitch.pitchClass(keyTonicPc);
    final int rel = (chord.normalizedRootPc - normKey + 12) % 12;
    final Set<int> keyPcs = keyMode.pitchClassSet(normKey);
    final Set<int> corePcs = _corePitchClasses(chord);

    // 1. Strict diatonic match against active key mode.
    if (keyPcs.contains(chord.normalizedRootPc) && keyPcs.containsAll(corePcs)) {
      final int degreeIdx = keyMode.semitoneIntervals.indexOf(rel);
      final HarmonicCategory cat = _diatonicCategoryForDegree(degreeIdx);
      final String roman = _buildRomanNumeral(rel, chord);
      return HarmonicAnalysisResult(
        romanNumeral: roman,
        category: cat,
        functionLabel: cat.shortLabel,
        scaleDegreeSemitones: rel,
        isDiatonic: true,
      );
    }

    // 2. Harmonic minor V / V7 / vii°7 in Aeolian keys.
    if (keyMode == ScaleMode.aeolian &&
        _isHarmonicMinorDominantOrLeading(chord, normKey)) {
      final String roman = _buildRomanNumeral(rel, chord);
      return HarmonicAnalysisResult(
        romanNumeral: roman,
        category: HarmonicCategory.dominant,
        functionLabel: 'Dominant (Harmonic Minor)',
        scaleDegreeSemitones: rel,
        isDiatonic: true,
      );
    }

    // 3. Secondary Dominant (V/x or V7/x).
    final HarmonicAnalysisResult? secDom =
        _trySecondaryDominant(chord, normKey, keyMode, rel);
    if (secDom != null) {
      return secDom;
    }

    // 4. Diminished Passing / Secondary Leading-Tone Chord.
    final HarmonicAnalysisResult? dimPassing =
        _tryDiminishedPassing(chord, normKey, keyMode, rel, nextChord);
    if (dimPassing != null) {
      return dimPassing;
    }

    // 5. Borrowed Chord (Modal Interchange from parallel modes).
    final HarmonicAnalysisResult? borrowed =
        _tryBorrowedChord(chord, normKey, keyMode, rel);
    if (borrowed != null) {
      return borrowed;
    }

    // 6. Chromatic Mediant / Altered Non-Diatonic fallback.
    final String fallbackRoman = _buildRomanNumeral(rel, chord);
    return HarmonicAnalysisResult(
      romanNumeral: fallbackRoman,
      category: HarmonicCategory.chromaticMediant,
      functionLabel: 'Chromatic',
      scaleDegreeSemitones: rel,
    );
  }

  /// Analyzes every chord in [progression] sequentially.
  static List<HarmonicAnalysisResult> analyzeProgression({
    required List<ChordSpec> progression,
    required int keyTonicPc,
    required ScaleMode keyMode,
  }) {
    final List<HarmonicAnalysisResult> out = <HarmonicAnalysisResult>[];
    for (int i = 0; i < progression.length; i++) {
      final ChordSpec? next =
          i + 1 < progression.length ? progression[i + 1] : null;
      out.add(
        analyzeChord(
          chord: progression[i],
          keyTonicPc: keyTonicPc,
          keyMode: keyMode,
          nextChord: next,
        ),
      );
    }
    return out;
  }

  /// Returns the pure Roman numeral relative to [keyTonicPc] without
  /// reclassifying as secondary dominant or passing chord.
  static String modalRomanNumeral(
    ChordSpec chord, {
    required int keyTonicPc,
  }) {
    final int rel =
        (chord.normalizedRootPc - MidiPitch.pitchClass(keyTonicPc) + 12) % 12;
    return _buildRomanNumeral(rel, chord);
  }

  static HarmonicAnalysisResult? _trySecondaryDominant(
    ChordSpec chord,
    int keyTonicPc,
    ScaleMode keyMode,
    int rel,
  ) {
    final bool isDominantStructure =
        (chord.triad == TriadQuality.major || chord.triad == TriadQuality.sus4) &&
            (chord.seventh == SeventhQuality.none ||
                chord.seventh == SeventhQuality.dominant7);
    if (!isDominantStructure) {
      return null;
    }

    // Target pitch class lies a perfect fifth below (or +5 semitones above) the chord root.
    final int targetPc = (chord.normalizedRootPc + 5) % 12;
    if (targetPc == keyTonicPc) {
      return null;
    }

    final int targetRel = (targetPc - keyTonicPc + 12) % 12;
    final int targetDegIdx = keyMode.semitoneIntervals.indexOf(targetRel);
    if (targetDegIdx < 0) {
      return null;
    }

    // Determine whether the diatonic triad on that target degree is major or minor (skipping dim).
    final List<int> ivs = keyMode.semitoneIntervals;
    final int thirdSemi =
        (ivs[(targetDegIdx + 2) % 7] - ivs[targetDegIdx] + 12) % 12;
    final int fifthSemi =
        (ivs[(targetDegIdx + 4) % 7] - ivs[targetDegIdx] + 12) % 12;
    if (fifthSemi != 7) {
      return null;
    }

    final String targetRoman = _degreeNumeral(
      targetRel,
      uppercase: thirdSemi == 4,
    );
    final String sevTag =
        chord.seventh == SeventhQuality.dominant7 ? _dominantQualityTag(chord) : '';
    final String roman = 'V$sevTag/$targetRoman';

    return HarmonicAnalysisResult(
      romanNumeral: roman,
      category: HarmonicCategory.secondaryDominant,
      functionLabel: 'Sec. Dom (of $targetRoman)',
      scaleDegreeSemitones: rel,
      targetRoman: targetRoman,
    );
  }

  static HarmonicAnalysisResult? _tryDiminishedPassing(
    ChordSpec chord,
    int keyTonicPc,
    ScaleMode keyMode,
    int rel,
    ChordSpec? nextChord,
  ) {
    final bool isDimQuality = chord.triad == TriadQuality.diminished ||
        chord.seventh == SeventhQuality.diminished7 ||
        chord.seventh == SeventhQuality.halfDiminished7;
    if (!isDimQuality) {
      return null;
    }

    final String suffix = chord.seventh == SeventhQuality.diminished7
        ? '°7'
        : chord.seventh == SeventhQuality.halfDiminished7
            ? 'ø7'
            : '°';

    // Check upward half-step resolution target in key or next chord.
    final int upTargetPc = (chord.normalizedRootPc + 1) % 12;
    final int upTargetRel = (upTargetPc - keyTonicPc + 12) % 12;
    final int upDegIdx = keyMode.semitoneIntervals.indexOf(upTargetRel);

    if (upDegIdx > 0) {
      final List<int> ivs = keyMode.semitoneIntervals;
      final int thirdSemi = (ivs[(upDegIdx + 2) % 7] - ivs[upDegIdx] + 12) % 12;
      final int fifthSemi = (ivs[(upDegIdx + 4) % 7] - ivs[upDegIdx] + 12) % 12;
      if (fifthSemi == 7) {
        final String targetRoman =
            _degreeNumeral(upTargetRel, uppercase: thirdSemi == 4);
        return HarmonicAnalysisResult(
          romanNumeral: 'vii$suffix/$targetRoman',
          category: HarmonicCategory.diminishedPassing,
          functionLabel: 'Dim. Passing (to $targetRoman)',
          scaleDegreeSemitones: rel,
          targetRoman: targetRoman,
        );
      }
    }

    // Check chromatic passing resolution to the following chord (+/- 1 semitone).
    if (nextChord != null) {
      final int stepToNext =
          (nextChord.normalizedRootPc - chord.normalizedRootPc + 12) % 12;
      if (stepToNext == 1 || stepToNext == 11) {
        final String roman = _buildRomanNumeral(rel, chord);
        final String dir = stepToNext == 1 ? 'Ascending' : 'Descending';
        return HarmonicAnalysisResult(
          romanNumeral: roman,
          category: HarmonicCategory.diminishedPassing,
          functionLabel: '$dir Dim. Passing',
          scaleDegreeSemitones: rel,
        );
      }
    }

    // Any remaining chromatic diminished chord still functions as diminished passing/color.
    return HarmonicAnalysisResult(
      romanNumeral: _buildRomanNumeral(rel, chord),
      category: HarmonicCategory.diminishedPassing,
      functionLabel: 'Diminished Passing',
      scaleDegreeSemitones: rel,
    );
  }

  static HarmonicAnalysisResult? _tryBorrowedChord(
    ChordSpec chord,
    int keyTonicPc,
    ScaleMode keyMode,
    int rel,
  ) {
    final Set<int> corePcs = _corePitchClasses(chord);

    for (final ScaleMode parallel in _borrowingPriority) {
      if (parallel == keyMode) {
        continue;
      }
      final Set<int> modePcs = parallel.pitchClassSet(keyTonicPc);
      if (modePcs.contains(chord.normalizedRootPc) &&
          modePcs.containsAll(corePcs)) {
        final String roman = _buildRomanNumeral(rel, chord);
        return HarmonicAnalysisResult(
          romanNumeral: roman,
          category: HarmonicCategory.borrowed,
          functionLabel: 'Borrowed (${parallel.shortLabel})',
          scaleDegreeSemitones: rel,
          borrowedFromMode: parallel,
        );
      }
    }

    return null;
  }

  static HarmonicCategory _diatonicCategoryForDegree(int degreeIndex) {
    switch (degreeIndex) {
      case 0:
      case 2:
      case 5:
        return HarmonicCategory.tonic;
      case 1:
      case 3:
        return HarmonicCategory.subdominant;
      case 4:
      case 6:
        return HarmonicCategory.dominant;
      default:
        return HarmonicCategory.tonic;
    }
  }

  /// Extracts root, 3rd/sus, 5th, and 7th pitch classes so upper chromatic
  /// tensions do not obscure the chord's core functional identity.
  static Set<int> _corePitchClasses(ChordSpec chord) {
    final int r = chord.normalizedRootPc;
    final Set<int> pcs = <int>{r};
    for (final int iv in chord.intervals) {
      if (iv <= 11) {
        pcs.add((r + iv) % 12);
      }
    }
    return pcs;
  }

  static String _degreeNumeral(int relSemitones, {required bool uppercase}) {
    const Map<int, String> upperMap = <int, String>{
      0: 'I',
      1: 'bII',
      2: 'II',
      3: 'bIII',
      4: 'III',
      5: 'IV',
      6: '#IV',
      7: 'V',
      8: 'bVI',
      9: 'VI',
      10: 'bVII',
      11: 'VII',
    };
    final String base = upperMap[relSemitones % 12] ?? 'I';
    if (uppercase) {
      return base;
    }
    // Preserve leading accidental ('b' or '#') while lowercasing Roman numerals.
    if (base.startsWith('b') || base.startsWith('#')) {
      return '${base[0]}${base.substring(1).toLowerCase()}';
    }
    return base.toLowerCase();
  }

  static String _dominantQualityTag(ChordSpec chord) {
    if (chord.extensions.contains(ChordExtension.thirteenth)) {
      return '13';
    }
    if (chord.extensions.contains(ChordExtension.eleventh)) {
      return '11';
    }
    if (chord.extensions.contains(ChordExtension.ninth)) {
      return '9';
    }
    return '7';
  }

  static String _buildRomanNumeral(int relSemitones, ChordSpec chord) {
    final bool isLower = chord.triad == TriadQuality.minor ||
        chord.triad == TriadQuality.diminished ||
        chord.seventh == SeventhQuality.halfDiminished7 ||
        chord.seventh == SeventhQuality.diminished7;
    final String base = _degreeNumeral(relSemitones, uppercase: !isLower);

    final StringBuffer suffix = StringBuffer();
    if (chord.seventh == SeventhQuality.none) {
      if (chord.triad == TriadQuality.diminished) {
        suffix.write('°');
      } else if (chord.triad == TriadQuality.augmented) {
        suffix.write('+');
      } else if (chord.triad == TriadQuality.sus4) {
        suffix.write('sus4');
      } else if (chord.triad == TriadQuality.sus2) {
        suffix.write('sus2');
      }
    } else {
      switch (chord.seventh) {
        case SeventhQuality.none:
          break;
        case SeventhQuality.major7:
          suffix.write(chord.triad == TriadQuality.minor ? '(Δ7)' : 'Δ7');
          break;
        case SeventhQuality.dominant7:
          suffix.write(_dominantQualityTag(chord));
          break;
        case SeventhQuality.minor7:
          if (chord.extensions.contains(ChordExtension.ninth)) {
            suffix.write('9');
          } else {
            suffix.write('7');
          }
          break;
        case SeventhQuality.halfDiminished7:
          suffix.write('ø7');
          break;
        case SeventhQuality.diminished7:
          suffix.write('°7');
          break;
        case SeventhQuality.minorMajor7:
          suffix.write('(Δ7)');
          break;
      }
    }

    if (chord.alterations.contains(ChordAlteration.flat9)) {
      suffix.write('(b9)');
    } else if (chord.alterations.contains(ChordAlteration.sharp9)) {
      suffix.write('(#9)');
    }

    return '$base$suffix';
  }
}
