/// The seven diatonic modes represented mathematically by semitone offsets.
enum ScaleMode {
  ionian,
  dorian,
  phrygian,
  lydian,
  mixolydian,
  aeolian,
  locrian,
}

extension ScaleModeX on ScaleMode {
  String get label {
    switch (this) {
      case ScaleMode.ionian:
        return 'Ionian (Major)';
      case ScaleMode.dorian:
        return 'Dorian';
      case ScaleMode.phrygian:
        return 'Phrygian';
      case ScaleMode.lydian:
        return 'Lydian';
      case ScaleMode.mixolydian:
        return 'Mixolydian';
      case ScaleMode.aeolian:
        return 'Aeolian (Natural Minor)';
      case ScaleMode.locrian:
        return 'Locrian';
    }
  }

  String get shortLabel {
    switch (this) {
      case ScaleMode.ionian:
        return 'Ionian';
      case ScaleMode.dorian:
        return 'Dorian';
      case ScaleMode.phrygian:
        return 'Phrygian';
      case ScaleMode.lydian:
        return 'Lydian';
      case ScaleMode.mixolydian:
        return 'Mixolydian';
      case ScaleMode.aeolian:
        return 'Aeolian';
      case ScaleMode.locrian:
        return 'Locrian';
    }
  }

  List<int> get semitoneIntervals {
    switch (this) {
      case ScaleMode.ionian:
        return const <int>[0, 2, 4, 5, 7, 9, 11];
      case ScaleMode.dorian:
        return const <int>[0, 2, 3, 5, 7, 9, 10];
      case ScaleMode.phrygian:
        return const <int>[0, 1, 3, 5, 7, 8, 10];
      case ScaleMode.lydian:
        return const <int>[0, 2, 4, 6, 7, 9, 11];
      case ScaleMode.mixolydian:
        return const <int>[0, 2, 4, 5, 7, 9, 10];
      case ScaleMode.aeolian:
        return const <int>[0, 2, 3, 5, 7, 8, 10];
      case ScaleMode.locrian:
        return const <int>[0, 1, 3, 5, 6, 8, 10];
    }
  }

  bool get isMinorFamily =>
      this == ScaleMode.dorian ||
      this == ScaleMode.phrygian ||
      this == ScaleMode.aeolian ||
      this == ScaleMode.locrian;

  String get characteristicNoteDescription {
    switch (this) {
      case ScaleMode.ionian:
        return 'Natural 3rd, 6th & 7th (Major reference)';
      case ScaleMode.dorian:
        return 'Minor 3rd with Natural 6th (6) and b7';
      case ScaleMode.phrygian:
        return 'Flat 2nd (b2) with Minor 3rd, b6 & b7';
      case ScaleMode.lydian:
        return 'Major triad with Raised 4th (#4)';
      case ScaleMode.mixolydian:
        return 'Major triad with Flat 7th (b7)';
      case ScaleMode.aeolian:
        return 'Natural Minor: b3, b6 & b7';
      case ScaleMode.locrian:
        return 'Diminished tonic color: b2 & b5';
    }
  }

  /// Parallel modes suitable for modal interchange comparison against [this].
  static List<ScaleMode> get parallelModes => const <ScaleMode>[
        ScaleMode.dorian,
        ScaleMode.phrygian,
        ScaleMode.lydian,
        ScaleMode.mixolydian,
        ScaleMode.aeolian,
        ScaleMode.locrian,
        ScaleMode.ionian,
      ];

  /// Returns all 7 pitch classes [0..11] for the given [tonicPc].
  Set<int> pitchClassSet(int tonicPc) {
    final int root = ((tonicPc % 12) + 12) % 12;
    return semitoneIntervals.map((int iv) => (root + iv) % 12).toSet();
  }

  /// Returns the pitch class [0..11] for scale degree [degreeIndex] (0..6).
  int degreePitchClass(int tonicPc, int degreeIndex) {
    final int root = ((tonicPc % 12) + 12) % 12;
    final int idx = ((degreeIndex % 7) + 7) % 7;
    return (root + semitoneIntervals[idx]) % 12;
  }
}
