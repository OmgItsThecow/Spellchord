import 'scale_mode.dart';

/// Broad harmonic classification for UI badges and muted accent styling.
enum HarmonicCategory {
  tonic,
  subdominant,
  dominant,
  secondaryDominant,
  diminishedPassing,
  borrowed,
  chromaticMediant,
}

extension HarmonicCategoryX on HarmonicCategory {
  String get shortLabel {
    switch (this) {
      case HarmonicCategory.tonic:
        return 'Tonic';
      case HarmonicCategory.subdominant:
        return 'Predominant';
      case HarmonicCategory.dominant:
        return 'Dominant';
      case HarmonicCategory.secondaryDominant:
        return 'Sec. Dom';
      case HarmonicCategory.diminishedPassing:
        return 'Dim. Passing';
      case HarmonicCategory.borrowed:
        return 'Borrowed';
      case HarmonicCategory.chromaticMediant:
        return 'Chromatic';
    }
  }
}

/// Complete harmonic analysis output for a chord in a tonal center.
class HarmonicAnalysisResult {
  const HarmonicAnalysisResult({
    required this.romanNumeral,
    required this.category,
    required this.functionLabel,
    required this.scaleDegreeSemitones,
    this.borrowedFromMode,
    this.targetRoman,
    this.isDiatonic = false,
  });

  final String romanNumeral;
  final HarmonicCategory category;
  final String functionLabel;
  final int scaleDegreeSemitones;
  final ScaleMode? borrowedFromMode;
  final String? targetRoman;
  final bool isDiatonic;
}
