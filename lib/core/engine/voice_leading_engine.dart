import 'dart:math' as math;

import '../models/chord_spec.dart';
import '../models/chord_voicing.dart';
import '../models/midi_pitch.dart';

/// Generates valid chord inversions and computes minimum-semitone-distance
/// MIDI voice leadings across a progression.
class VoiceLeadingEngine {
  VoiceLeadingEngine._();

  static const int defaultMinMidi = 48; // C3
  static const int defaultMaxMidi = 79; // G5
  static const int defaultMaxVoices = 4;

  static const double _commonToneReward = 1.5;
  static const double _leapWeight = 0.75;
  static const double _overlapPenalty = 4.0;
  static const double _parallelPerfectPenalty = 3.5;
  static const double _registerAnchorWeight = 0.15;
  static const double _idealRegisterCenter = 61.0; // C#4

  /// Computes optimal (or manually overridden) voicings for the full progression.
  static List<ChordVoicing> solveProgression(
    List<ChordSpec> progression, {
    int maxVoices = defaultMaxVoices,
  }) {
    final List<ChordVoicing> solved = <ChordVoicing>[];
    List<int>? previousMidi;

    for (final ChordSpec chord in progression) {
      final List<ChordVoicing> ranked = rankVoicingsForChord(
        chord,
        previousMidi: previousMidi,
        forcedInversion: chord.manualInversion,
        maxVoices: maxVoices,
      );

      if (ranked.isEmpty) {
        final ChordVoicing fallback = _fallbackVoicing(chord, previousMidi);
        solved.add(fallback);
        previousMidi = fallback.midiNotes;
        continue;
      }

      ChordVoicing chosen;
      if (chord.manualInversion != null) {
        final int safeVariant =
            chord.voicingVariantIndex.clamp(0, ranked.length - 1);
        chosen = ranked[safeVariant];
      } else {
        final int safeVariant =
            chord.voicingVariantIndex.clamp(0, ranked.length - 1);
        chosen = ranked[safeVariant];
      }

      solved.add(chosen);
      previousMidi = chosen.midiNotes;
    }

    return solved;
  }

  /// Returns one representative (lowest-cost) voicing per inversion index
  /// (0, 1, 2, ...) so the UI can compare inversions side by side.
  static List<ChordVoicing> bestVoicingPerInversion(
    ChordSpec chord, {
    List<int>? previousMidi,
    int maxVoices = defaultMaxVoices,
  }) {
    final List<ChordVoicing> out = <ChordVoicing>[];
    for (int inv = 0; inv < chord.inversionCount; inv++) {
      final List<ChordVoicing> candidates = rankVoicingsForChord(
        chord,
        previousMidi: previousMidi,
        forcedInversion: inv,
        maxVoices: maxVoices,
      );
      if (candidates.isNotEmpty) {
        out.add(candidates.first);
      }
    }
    return out;
  }

  /// Generates and ranks all valid MIDI voicings for [chord].
  static List<ChordVoicing> rankVoicingsForChord(
    ChordSpec chord, {
    List<int>? previousMidi,
    int? forcedInversion,
    int maxVoices = defaultMaxVoices,
    int minMidi = defaultMinMidi,
    int maxMidi = defaultMaxMidi,
  }) {
    final int invCount = chord.inversionCount;
    if (invCount == 0) {
      return const <ChordVoicing>[];
    }

    final List<int> inversionsToTest = forcedInversion != null
        ? <int>[((forcedInversion % invCount) + invCount) % invCount]
        : List<int>.generate(invCount, (int i) => i);

    final Map<String, ChordVoicing> uniqueByNotes = <String, ChordVoicing>{};

    for (final int inv in inversionsToTest) {
      final int bassPc = chord.bassPitchClassForInversion(inv);
      final List<int> activePcs = _selectActivePitchClasses(
        chord: chord,
        bassPc: bassPc,
        maxVoices: maxVoices,
      );
      final List<int> upperPcs =
          activePcs.where((int pc) => pc != bassPc).toList();

      // Generate bass placements across the lower playable window.
      final List<int> bassCandidates = <int>[];
      for (int m = minMidi - 3; m <= minMidi + 16; m++) {
        if (m >= MidiPitch.minMidi &&
            m <= MidiPitch.maxMidi &&
            MidiPitch.pitchClass(m) == bassPc) {
          bassCandidates.add(m);
        }
      }

      final List<List<int>> permutations = _permutations(upperPcs);
      for (final int bassMidi in bassCandidates) {
        for (final List<int> perm in permutations) {
          // Close stacked realization from bass upwards.
          final List<int>? closeNotes =
              _stackAscending(bassMidi, perm, maxMidi + 3);
          if (closeNotes != null && closeNotes.last - closeNotes.first <= 24) {
            _registerCandidate(
              uniqueByNotes: uniqueByNotes,
              notes: closeNotes,
              chord: chord,
              inv: inv,
              previousMidi: previousMidi,
            );

            // Drop/open variant: lift the highest voice or spread middle voice by +12
            if (closeNotes.length >= 3) {
              for (int liftIdx = 1; liftIdx < closeNotes.length; liftIdx++) {
                final List<int> openNotes = List<int>.from(closeNotes);
                openNotes[liftIdx] += 12;
                openNotes.sort();
                if (openNotes.last <= maxMidi + 4 &&
                    openNotes.last - openNotes.first <= 24) {
                  _registerCandidate(
                    uniqueByNotes: uniqueByNotes,
                    notes: openNotes,
                    chord: chord,
                    inv: inv,
                    previousMidi: previousMidi,
                  );
                }
              }
            }
          }
        }
      }
    }

    final List<ChordVoicing> ranked = uniqueByNotes.values.toList()
      ..sort((ChordVoicing a, ChordVoicing b) {
        final int costCmp = a.voiceLeadingCost.compareTo(b.voiceLeadingCost);
        if (costCmp != 0) {
          return costCmp;
        }
        final int distCmp =
            a.totalSemitoneDistance.compareTo(b.totalSemitoneDistance);
        if (distCmp != 0) {
          return distCmp;
        }
        return a.inversionIndex.compareTo(b.inversionIndex);
      });

    return ranked;
  }

  static void _registerCandidate({
    required Map<String, ChordVoicing> uniqueByNotes,
    required List<int> notes,
    required ChordSpec chord,
    required int inv,
    required List<int>? previousMidi,
  }) {
    final String key = notes.join(',');
    final TransitionEval eval = evaluateTransition(previousMidi, notes);
    final double initialBias = previousMidi == null && inv > 0 ? inv * 0.45 : 0.0;
    final double totalCost = eval.cost + initialBias;

    final String spacing =
        (notes.last - notes.first) <= 12 ? 'Close' : 'Open / Drop';

    final ChordVoicing voicing = ChordVoicing(
      midiNotes: List<int>.unmodifiable(notes),
      rootPc: chord.normalizedRootPc,
      inversionIndex: inv,
      voiceLeadingCost: totalCost,
      motions: List<VoiceMotion>.unmodifiable(eval.motions),
      spacingLabel: spacing,
    );

    final ChordVoicing? existing = uniqueByNotes[key];
    if (existing == null || voicing.voiceLeadingCost < existing.voiceLeadingCost) {
      uniqueByNotes[key] = voicing;
    }
  }

  /// Deterministic objective function measuring semitone travel, common tones,
  /// stepwise motion, voice overlap, parallel 5ths/8ves, and register drift.
  static TransitionEval evaluateTransition(
    List<int>? prevMidi,
    List<int> candidateMidi,
  ) {
    final double meanPitch =
        candidateMidi.reduce((int a, int b) => a + b) / candidateMidi.length;
    final double registerDrift =
        (meanPitch - _idealRegisterCenter).abs() * _registerAnchorWeight;

    if (prevMidi == null || prevMidi.isEmpty) {
      final List<VoiceMotion> initialMotions = <VoiceMotion>[
        for (int i = 0; i < candidateMidi.length; i++)
          VoiceMotion(voiceIndex: i, fromMidi: null, toMidi: candidateMidi[i]),
      ];
      final double spread =
          (candidateMidi.last - candidateMidi.first).toDouble();
      final double compactnessBias = (spread - 11.0).abs() * 0.08;
      return TransitionEval(
        cost: registerDrift + compactnessBias,
        motions: initialMotions,
      );
    }

    final List<int> alignedPrev =
        _alignPreviousVoices(prevMidi, candidateMidi);

    double totalDistance = 0.0;
    int commonTones = 0;
    double leapPenalty = 0.0;
    double overlapPenalty = 0.0;
    final List<VoiceMotion> motions = <VoiceMotion>[];

    for (int j = 0; j < candidateMidi.length; j++) {
      final int from = alignedPrev[j];
      final int to = candidateMidi[j];
      final int dist = (to - from).abs();

      motions.add(VoiceMotion(voiceIndex: j, fromMidi: from, toMidi: to));
      totalDistance += dist;

      if (dist == 0) {
        commonTones++;
      } else if (dist > 2) {
        final int excess = dist - 2;
        leapPenalty += _leapWeight * excess * excess;
      }

      if (j + 1 < candidateMidi.length) {
        if (to > alignedPrev[j + 1] || candidateMidi[j + 1] < from) {
          overlapPenalty += _overlapPenalty;
        }
      }
    }

    // Penalize parallel perfect fifths and octaves moving in the same direction.
    double parallelPenalty = 0.0;
    for (int i = 0; i < candidateMidi.length; i++) {
      for (int j = i + 1; j < candidateMidi.length; j++) {
        final int prevDeltaI = candidateMidi[i] - alignedPrev[i];
        final int prevDeltaJ = candidateMidi[j] - alignedPrev[j];
        if (prevDeltaI == 0 || prevDeltaJ == 0) {
          continue;
        }
        final bool sameDirection =
            (prevDeltaI > 0 && prevDeltaJ > 0) ||
                (prevDeltaI < 0 && prevDeltaJ < 0);
        if (!sameDirection) {
          continue;
        }
        final int prevInterval = (alignedPrev[j] - alignedPrev[i]) % 12;
        final int nextInterval = (candidateMidi[j] - candidateMidi[i]) % 12;
        final bool prevPerfect = prevInterval == 0 || prevInterval == 7;
        final bool nextPerfect = nextInterval == 0 || nextInterval == 7;
        if (prevPerfect && nextPerfect && prevInterval == nextInterval) {
          parallelPenalty += _parallelPerfectPenalty;
        }
      }
    }

    final double cost = totalDistance -
        (_commonToneReward * commonTones) +
        leapPenalty +
        overlapPenalty +
        parallelPenalty +
        registerDrift;

    return TransitionEval(cost: cost, motions: motions);
  }

  /// Aligns [prev] voices to [cand] voices in ascending order without crossings.
  static List<int> _alignPreviousVoices(List<int> prev, List<int> cand) {
    if (prev.length == cand.length) {
      return prev;
    }

    final List<int> aligned = <int>[];
    if (prev.length < cand.length) {
      // Expand shorter previous chord by finding nearest valid voice per target slot.
      for (int j = 0; j < cand.length; j++) {
        if (j == 0) {
          aligned.add(prev.first);
        } else if (j == cand.length - 1) {
          aligned.add(prev.last);
        } else {
          final double ratio = j / (cand.length - 1);
          final int mappedIdx =
              (ratio * (prev.length - 1)).round().clamp(0, prev.length - 1);
          aligned.add(prev[mappedIdx]);
        }
      }
      return aligned;
    }

    // prev.length > cand.length: select optimal order-preserving subsequence of prev.
    int cursor = 0;
    for (int j = 0; j < cand.length; j++) {
      final int remainingNeeded = cand.length - 1 - j;
      final int maxAllowedIdx = prev.length - 1 - remainingNeeded;
      int bestIdx = cursor;
      int bestDist = 1 << 20;
      for (int k = cursor; k <= maxAllowedIdx; k++) {
        final int dist = (cand[j] - prev[k]).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = k;
        }
      }
      aligned.add(prev[bestIdx]);
      cursor = bestIdx + 1;
    }
    return aligned;
  }

  static List<int> _selectActivePitchClasses({
    required ChordSpec chord,
    required int bassPc,
    required int maxVoices,
  }) {
    final List<int> pcs = <int>[bassPc];
    for (final int pc in chord.prioritizedPitchClasses) {
      if (pcs.length >= maxVoices) {
        break;
      }
      if (!pcs.contains(pc)) {
        pcs.add(pc);
      }
    }
    return pcs;
  }

  static List<int>? _stackAscending(
    int bassMidi,
    List<int> upperPcs,
    int upperLimit,
  ) {
    final List<int> notes = <int>[bassMidi];
    int prev = bassMidi;
    for (final int pc in upperPcs) {
      int candidate = prev + 1;
      while (MidiPitch.pitchClass(candidate) != pc) {
        candidate++;
      }
      if (candidate > upperLimit || candidate > MidiPitch.maxMidi) {
        return null;
      }
      notes.add(candidate);
      prev = candidate;
    }
    return notes;
  }

  static List<List<int>> _permutations(List<int> items) {
    if (items.isEmpty) {
      return const <List<int>>[<int>[]];
    }
    if (items.length == 1) {
      return <List<int>>[items];
    }
    final List<List<int>> results = <List<int>>[];
    for (int i = 0; i < items.length; i++) {
      final int head = items[i];
      final List<int> rest = <int>[
        for (int j = 0; j < items.length; j++)
          if (j != i) items[j],
      ];
      for (final List<int> tail in _permutations(rest)) {
        results.add(<int>[head, ...tail]);
      }
    }
    return results;
  }

  static ChordVoicing _fallbackVoicing(ChordSpec chord, List<int>? prevMidi) {
    final List<int> notes = <int>[
      for (final int iv in chord.intervals)
        MidiPitch.clampMidi(48 + chord.normalizedRootPc + iv),
    ]..sort();
    final TransitionEval eval = evaluateTransition(prevMidi, notes);
    return ChordVoicing(
      midiNotes: notes,
      rootPc: chord.normalizedRootPc,
      inversionIndex: 0,
      voiceLeadingCost: eval.cost,
      motions: eval.motions,
      spacingLabel: 'Root Stack',
    );
  }

  /// Helper to measure raw voice-leading distance between two arbitrary chords
  /// (used by Modal Interchange Explorer to rank borrowed substitutions).
  static double minimalVoiceLeadingDistance({
    required ChordSpec candidateChord,
    required List<int>? previousMidi,
  }) {
    final List<ChordVoicing> ranked = rankVoicingsForChord(
      candidateChord,
      previousMidi: previousMidi,
    );
    if (ranked.isEmpty) {
      return math.max(0.0, 99.0);
    }
    return ranked.first.totalSemitoneDistance.toDouble();
  }
}

/// Evaluation breakdown for a voice-leading transition.
class TransitionEval {
  const TransitionEval({
    required this.cost,
    required this.motions,
  });

  final double cost;
  final List<VoiceMotion> motions;
}
