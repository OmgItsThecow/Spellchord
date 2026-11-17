import 'midi_pitch.dart';

/// Movement of a single voice between the preceding chord and current chord.
class VoiceMotion {
  const VoiceMotion({
    required this.voiceIndex,
    required this.fromMidi,
    required this.toMidi,
  });

  final int voiceIndex;
  final int? fromMidi;
  final int toMidi;

  int get deltaSemitones => fromMidi == null ? 0 : toMidi - fromMidi!;
  int get absDistance => deltaSemitones.abs();
  bool get isCommonTone => fromMidi != null && deltaSemitones == 0;
  bool get isStepwise => fromMidi != null && absDistance >= 1 && absDistance <= 2;

  String voiceName(int totalVoices) {
    if (voiceIndex == 0) {
      return 'Bass';
    }
    if (voiceIndex == totalVoices - 1) {
      return 'Soprano';
    }
    if (totalVoices >= 4 && voiceIndex == 1) {
      return 'Tenor';
    }
    if (totalVoices >= 4 && voiceIndex == 2) {
      return 'Alto';
    }
    return 'Voice ${voiceIndex + 1}';
  }
}

/// Concrete MIDI voicing produced by the voice-leading engine.
class ChordVoicing {
  const ChordVoicing({
    required this.midiNotes,
    required this.rootPc,
    required this.inversionIndex,
    required this.voiceLeadingCost,
    required this.motions,
    this.spacingLabel = 'Close',
  });

  /// Sorted ascending MIDI pitches (0..127).
  final List<int> midiNotes;
  final int rootPc;
  final int inversionIndex;
  final double voiceLeadingCost;
  final List<VoiceMotion> motions;
  final String spacingLabel;

  int get bassMidi => midiNotes.first;
  int get bassPc => MidiPitch.pitchClass(bassMidi);

  int get totalSemitoneDistance =>
      motions.fold<int>(0, (int sum, VoiceMotion m) => sum + m.absDistance);

  int get commonToneCount =>
      motions.where((VoiceMotion m) => m.isCommonTone).length;

  int get stepwiseVoiceCount =>
      motions.where((VoiceMotion m) => m.isStepwise).length;

  String get inversionLabel => inversionLabelFor(inversionIndex);

  String get shortInversionLabel {
    switch (inversionIndex) {
      case 0:
        return 'Root';
      case 1:
        return '1st Inv';
      case 2:
        return '2nd Inv';
      case 3:
        return '3rd Inv';
      default:
        return '${inversionIndex}th Inv';
    }
  }

  static String inversionLabelFor(int inv) {
    switch (inv) {
      case 0:
        return 'Root Position';
      case 1:
        return '1st Inversion';
      case 2:
        return '2nd Inversion';
      case 3:
        return '3rd Inversion';
      default:
        return '${inv}th Inversion';
    }
  }
}
