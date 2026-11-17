import 'interval_profile.dart';
import 'midi_pitch.dart';

/// Immutable specification of a chord slot in a progression.
class ChordSpec {
  const ChordSpec({
    required this.id,
    required this.rootPc,
    required this.triad,
    this.seventh = SeventhQuality.none,
    this.extensions = const <ChordExtension>{},
    this.alterations = const <ChordAlteration>{},
    this.manualInversion,
    this.voicingVariantIndex = 0,
  });

  final String id;
  final int rootPc;
  final TriadQuality triad;
  final SeventhQuality seventh;
  final Set<ChordExtension> extensions;
  final Set<ChordAlteration> alterations;

  /// Null means optimal automatic voice-leading inversion; 0 = root, 1 = 1st inv, etc.
  final int? manualInversion;

  /// Allows cycling through alternative register/drop voicings within the active inversion.
  final int voicingVariantIndex;

  int get normalizedRootPc => MidiPitch.pitchClass(rootPc);

  /// Semitone intervals above root (e.g. [0, 4, 7, 10]).
  List<int> get intervals => IntervalProfile.buildIntervals(
        triad: triad,
        seventh: seventh,
        extensions: extensions,
        alterations: alterations,
      );

  /// Ordered chord-tone pitch classes [0..11], starting on root, 3rd, 5th, 7th, extensions.
  List<int> get pitchClasses {
    final int r = normalizedRootPc;
    final List<int> pcs = <int>[];
    for (final int iv in intervals) {
      final int pc = (r + iv) % 12;
      if (!pcs.contains(pc)) {
        pcs.add(pc);
      }
    }
    return pcs;
  }

  /// Pitch classes ordered by harmonic retention priority when voicing count is limited.
  List<int> get prioritizedPitchClasses {
    final int r = normalizedRootPc;
    return IntervalProfile.prioritizedPitchClassOffsets(
      triad: triad,
      seventh: seventh,
      extensions: extensions,
      alterations: alterations,
    ).map((int offset) => (r + offset) % 12).toList();
  }

  int get inversionCount => pitchClasses.length;

  /// Returns the bass pitch class for a given inversion index [inv].
  int bassPitchClassForInversion(int inv) {
    final List<int> pcs = pitchClasses;
    final int safeInv = ((inv % pcs.length) + pcs.length) % pcs.length;
    return pcs[safeInv];
  }

  /// Base chord symbol without inversion slash notation.
  String baseSymbol({bool preferFlat = false}) {
    final String rootName =
        MidiPitch.pitchClassName(normalizedRootPc, preferFlat: preferFlat);
    final String suffix = IntervalProfile.formatSuffix(
      triad: triad,
      seventh: seventh,
      extensions: extensions,
      alterations: alterations,
    );
    return '$rootName$suffix';
  }

  /// Full chord symbol including slash-bass if an inversion is active.
  String symbol({bool preferFlat = false, int? activeInversion}) {
    final String base = baseSymbol(preferFlat: preferFlat);
    final int? inv = activeInversion ?? manualInversion;
    if (inv == null || inv == 0 || pitchClasses.isEmpty) {
      return base;
    }
    final int bassPc = bassPitchClassForInversion(inv);
    if (bassPc == normalizedRootPc) {
      return base;
    }
    final String bassName =
        MidiPitch.pitchClassName(bassPc, preferFlat: preferFlat);
    return '$base/$bassName';
  }

  ChordSpec copyWith({
    String? id,
    int? rootPc,
    TriadQuality? triad,
    SeventhQuality? seventh,
    Set<ChordExtension>? extensions,
    Set<ChordAlteration>? alterations,
    int? manualInversion,
    bool clearManualInversion = false,
    int? voicingVariantIndex,
  }) {
    return ChordSpec(
      id: id ?? this.id,
      rootPc: rootPc ?? this.rootPc,
      triad: triad ?? this.triad,
      seventh: seventh ?? this.seventh,
      extensions: extensions ?? this.extensions,
      alterations: alterations ?? this.alterations,
      manualInversion:
          clearManualInversion ? null : (manualInversion ?? this.manualInversion),
      voicingVariantIndex: voicingVariantIndex ?? this.voicingVariantIndex,
    );
  }

  /// Checks pitch-class equivalence with another chord (ignoring id/inversion).
  bool hasSamePitchClasses(ChordSpec other) {
    final Set<int> a = pitchClasses.toSet();
    final Set<int> b = other.pitchClasses.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  /// Serializes this chord specification into a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'rootPc': normalizedRootPc,
        'triad': triad.name,
        'seventh': seventh.name,
        'extensions': extensions.map((ChordExtension e) => e.name).toList(),
        'alterations': alterations.map((ChordAlteration a) => a.name).toList(),
        'manualInversion': manualInversion,
        'voicingVariantIndex': voicingVariantIndex,
      };

  /// Reconstructs a [ChordSpec] from a JSON map produced by [toJson].
  factory ChordSpec.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawExt =
        json['extensions'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> rawAlt =
        json['alterations'] as List<dynamic>? ?? const <dynamic>[];

    final Set<ChordExtension> parsedExt = <ChordExtension>{};
    for (final dynamic item in rawExt) {
      final ChordExtension? ext =
          _enumByName(ChordExtension.values, item?.toString());
      if (ext != null) {
        parsedExt.add(ext);
      }
    }

    final Set<ChordAlteration> parsedAlt = <ChordAlteration>{};
    for (final dynamic item in rawAlt) {
      final ChordAlteration? alt =
          _enumByName(ChordAlteration.values, item?.toString());
      if (alt != null) {
        parsedAlt.add(alt);
      }
    }

    return ChordSpec(
      id: json['id']?.toString() ??
          'chord_${DateTime.now().microsecondsSinceEpoch}',
      rootPc: MidiPitch.pitchClass((json['rootPc'] as num?)?.toInt() ?? 0),
      triad: _enumByName(TriadQuality.values, json['triad']?.toString()) ??
          TriadQuality.major,
      seventh:
          _enumByName(SeventhQuality.values, json['seventh']?.toString()) ??
              SeventhQuality.none,
      extensions: Set<ChordExtension>.unmodifiable(parsedExt),
      alterations: Set<ChordAlteration>.unmodifiable(parsedAlt),
      manualInversion: (json['manualInversion'] as num?)?.toInt(),
      voicingVariantIndex: (json['voicingVariantIndex'] as num?)?.toInt() ?? 0,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    if (name == null) {
      return null;
    }
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  factory ChordSpec.major(int rootPc, {String? id}) => ChordSpec(
        id: id ?? 'maj_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.major,
      );

  factory ChordSpec.minor(int rootPc, {String? id}) => ChordSpec(
        id: id ?? 'min_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.minor,
      );

  factory ChordSpec.major7(
    int rootPc, {
    String? id,
    Set<ChordExtension> extensions = const <ChordExtension>{},
  }) =>
      ChordSpec(
        id: id ?? 'maj7_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.major,
        seventh: SeventhQuality.major7,
        extensions: extensions,
      );

  factory ChordSpec.minor7(
    int rootPc, {
    String? id,
    Set<ChordExtension> extensions = const <ChordExtension>{},
  }) =>
      ChordSpec(
        id: id ?? 'min7_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.minor,
        seventh: SeventhQuality.minor7,
        extensions: extensions,
      );

  factory ChordSpec.dominant7(
    int rootPc, {
    String? id,
    Set<ChordExtension> extensions = const <ChordExtension>{},
    Set<ChordAlteration> alterations = const <ChordAlteration>{},
  }) =>
      ChordSpec(
        id: id ?? 'dom7_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.major,
        seventh: SeventhQuality.dominant7,
        extensions: extensions,
        alterations: alterations,
      );

  factory ChordSpec.halfDim7(int rootPc, {String? id}) => ChordSpec(
        id: id ?? 'hdim7_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.diminished,
        seventh: SeventhQuality.halfDiminished7,
      );

  factory ChordSpec.dim7(int rootPc, {String? id}) => ChordSpec(
        id: id ?? 'dim7_${rootPc}_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: MidiPitch.pitchClass(rootPc),
        triad: TriadQuality.diminished,
        seventh: SeventhQuality.diminished7,
      );
}
