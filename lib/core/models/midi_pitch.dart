/// Deterministic MIDI pitch (0..127) and pitch-class (0..11) utilities.
class MidiPitch {
  MidiPitch._();

  static const int minMidi = 0;
  static const int maxMidi = 127;

  static const List<String> sharpNames = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const List<String> flatNames = <String>[
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static const Set<int> _blackPitchClasses = <int>{1, 3, 6, 8, 10};

  /// Clamps a MIDI pitch to the valid [0, 127] range.
  static int clampMidi(int midi) => midi.clamp(minMidi, maxMidi);

  /// Returns the normalized pitch class [0..11] for any MIDI integer.
  static int pitchClass(int midi) => ((midi % 12) + 12) % 12;

  /// Returns the scientific pitch octave (C4 == MIDI 60 => octave 4).
  static int octave(int midi) => (midi ~/ 12) - 1;

  /// Converts a pitch class [0..11] and octave into a clamped MIDI integer.
  static int toMidi(int pitchClass, int octave) {
    final int pc = ((pitchClass % 12) + 12) % 12;
    return ((octave + 1) * 12 + pc).clamp(minMidi, maxMidi);
  }

  /// Unsigned semitone distance between two MIDI integers.
  static int semitoneDistance(int midiA, int midiB) => (midiB - midiA).abs();

  /// Signed semitone movement from [fromMidi] to [toMidi].
  static int signedSemitoneDelta(int fromMidi, int toMidi) => toMidi - fromMidi;

  /// Shortest unsigned distance [0..6] between two pitch classes mod 12.
  static int minimalPitchClassDistance(int pcA, int pcB) {
    final int diff = (pitchClass(pcB) - pitchClass(pcA) + 12) % 12;
    return diff <= 6 ? diff : 12 - diff;
  }

  /// Human-readable pitch-class name (e.g. 'C#', 'Bb').
  static String pitchClassName(int pc, {bool preferFlat = false}) {
    final int normalized = pitchClass(pc);
    return preferFlat ? flatNames[normalized] : sharpNames[normalized];
  }

  /// Human-readable note name with octave (e.g. 'C4') and optional MIDI integer.
  static String midiLabel(
    int midi, {
    bool preferFlat = false,
    bool includeMidiNumber = true,
  }) {
    final int clamped = clampMidi(midi);
    final String name = pitchClassName(pitchClass(clamped), preferFlat: preferFlat);
    final int oct = octave(clamped);
    return includeMidiNumber ? '$name$oct ($clamped)' : '$name$oct';
  }

  /// Returns true if the given MIDI pitch falls on a black piano key.
  static bool isBlackKey(int midi) =>
      _blackPitchClasses.contains(pitchClass(midi));

  /// Signed interval label for UI display (e.g. '0 (Common)', '+1 st', '-2 st').
  static String formatDelta(int delta) {
    if (delta == 0) {
      return '0 st';
    }
    return delta > 0 ? '+$delta st' : '$delta st';
  }
}
