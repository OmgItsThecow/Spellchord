/// Core triad qualities defined by semitone intervals from the root.
enum TriadQuality {
  major,
  minor,
  diminished,
  augmented,
  sus2,
  sus4,
}

/// Seventh chord extensions layered atop a triad quality.
enum SeventhQuality {
  none,
  major7,
  dominant7,
  minor7,
  halfDiminished7,
  diminished7,
  minorMajor7,
}

/// Upper-structure extensions (9th, 11th, 13th) in semitones above the root.
enum ChordExtension {
  add9,
  ninth,
  eleventh,
  thirteenth,
}

/// Chromatic alterations applied to 5th, 9th, 11th, or 13th degrees.
enum ChordAlteration {
  flat5,
  sharp5,
  flat9,
  sharp9,
  sharp11,
  flat13,
}

/// Deterministic translator from chord quality enums to MIDI semitone intervals
/// and standardized chord symbols.
class IntervalProfile {
  IntervalProfile._();

  static List<int> triadIntervals(TriadQuality triad) {
    switch (triad) {
      case TriadQuality.major:
        return const <int>[0, 4, 7];
      case TriadQuality.minor:
        return const <int>[0, 3, 7];
      case TriadQuality.diminished:
        return const <int>[0, 3, 6];
      case TriadQuality.augmented:
        return const <int>[0, 4, 8];
      case TriadQuality.sus2:
        return const <int>[0, 2, 7];
      case TriadQuality.sus4:
        return const <int>[0, 5, 7];
    }
  }

  static int? seventhSemitone(SeventhQuality seventh) {
    switch (seventh) {
      case SeventhQuality.none:
        return null;
      case SeventhQuality.major7:
      case SeventhQuality.minorMajor7:
        return 11;
      case SeventhQuality.dominant7:
      case SeventhQuality.minor7:
      case SeventhQuality.halfDiminished7:
        return 10;
      case SeventhQuality.diminished7:
        return 9;
    }
  }

  /// Builds the sorted, deduplicated semitone interval list (e.g. [0, 4, 7, 10, 14]).
  static List<int> buildIntervals({
    required TriadQuality triad,
    SeventhQuality seventh = SeventhQuality.none,
    Set<ChordExtension> extensions = const <ChordExtension>{},
    Set<ChordAlteration> alterations = const <ChordAlteration>{},
  }) {
    final List<int> base = List<int>.from(triadIntervals(triad));

    // Apply 5th alterations cleanly by replacing perfect 5th (7) when present.
    if (alterations.contains(ChordAlteration.flat5)) {
      base.remove(7);
      if (!base.contains(6)) {
        base.add(6);
      }
    }
    if (alterations.contains(ChordAlteration.sharp5)) {
      base.remove(7);
      if (!base.contains(8)) {
        base.add(8);
      }
    }

    // Half-diminished guarantees a b5 if user chose minor triad + halfDim7.
    if (seventh == SeventhQuality.halfDiminished7) {
      base.remove(7);
      if (!base.contains(6)) {
        base.add(6);
      }
    }
    if (seventh == SeventhQuality.diminished7) {
      base.remove(7);
      if (!base.contains(6)) {
        base.add(6);
      }
    }

    final int? sev = seventhSemitone(seventh);
    if (sev != null && !base.contains(sev)) {
      base.add(sev);
    }

    // Add natural extensions.
    if (extensions.contains(ChordExtension.add9) ||
        extensions.contains(ChordExtension.ninth)) {
      base.add(14);
    }
    if (extensions.contains(ChordExtension.eleventh)) {
      if (extensions.contains(ChordExtension.ninth) == false &&
          seventh != SeventhQuality.none) {
        // Keep eleventh explicit even without 9th for clean suspended/11th color.
      }
      base.add(17);
    }
    if (extensions.contains(ChordExtension.thirteenth)) {
      base.add(21);
    }

    // Add upper chromatic alterations.
    if (alterations.contains(ChordAlteration.flat9)) {
      base.remove(14);
      base.add(13);
    }
    if (alterations.contains(ChordAlteration.sharp9)) {
      base.add(15);
    }
    if (alterations.contains(ChordAlteration.sharp11)) {
      base.remove(17);
      base.add(18);
    }
    if (alterations.contains(ChordAlteration.flat13)) {
      base.remove(21);
      base.add(20);
    }

    final List<int> uniqueSorted = base.toSet().toList()..sort();
    return uniqueSorted;
  }

  /// Returns pitch-class offsets modulo 12 ordered by harmonic priority:
  /// Root -> 3rd/Sus -> 7th -> Extensions/Alterations -> 5th.
  static List<int> prioritizedPitchClassOffsets({
    required TriadQuality triad,
    SeventhQuality seventh = SeventhQuality.none,
    Set<ChordExtension> extensions = const <ChordExtension>{},
    Set<ChordAlteration> alterations = const <ChordAlteration>{},
  }) {
    final List<int> intervals = buildIntervals(
      triad: triad,
      seventh: seventh,
      extensions: extensions,
      alterations: alterations,
    );

    final List<int> ordered = <int>[];
    void addIfPresent(int semitone) {
      if (intervals.contains(semitone)) {
        final int pc = semitone % 12;
        if (!ordered.contains(pc)) {
          ordered.add(pc);
        }
      }
    }

    // 1. Root
    addIfPresent(0);
    // 2. 3rd or Sus degree
    for (final int third in const <int>[3, 4, 2, 5]) {
      addIfPresent(third);
    }
    // 3. 7th
    for (final int sev in const <int>[11, 10, 9]) {
      addIfPresent(sev);
    }
    // 4. Extensions & chromatic alterations (except P5)
    for (final int ext in const <int>[13, 14, 15, 17, 18, 20, 21, 6, 8]) {
      addIfPresent(ext);
    }
    // 5. Perfect 5th omitted first when voices are scarce
    addIfPresent(7);

    return ordered;
  }

  /// Formats the chord suffix (e.g. 'maj7', 'm7b5', '7(b9,#11)', 'dim7').
  static String formatSuffix({
    required TriadQuality triad,
    SeventhQuality seventh = SeventhQuality.none,
    Set<ChordExtension> extensions = const <ChordExtension>{},
    Set<ChordAlteration> alterations = const <ChordAlteration>{},
  }) {
    final StringBuffer sb = StringBuffer();

    final bool hasFlat5 = alterations.contains(ChordAlteration.flat5);
    final bool hasSharp5 = alterations.contains(ChordAlteration.sharp5);

    if (seventh == SeventhQuality.none) {
      switch (triad) {
        case TriadQuality.major:
          break;
        case TriadQuality.minor:
          sb.write('m');
          break;
        case TriadQuality.diminished:
          sb.write('dim');
          break;
        case TriadQuality.augmented:
          sb.write('aug');
          break;
        case TriadQuality.sus2:
          sb.write('sus2');
          break;
        case TriadQuality.sus4:
          sb.write('sus4');
          break;
      }
    } else {
      switch (seventh) {
        case SeventhQuality.none:
          break;
        case SeventhQuality.major7:
          if (triad == TriadQuality.minor) {
            sb.write('m(maj7)');
          } else if (triad == TriadQuality.augmented || hasSharp5) {
            sb.write('maj7(#5)');
          } else {
            sb.write(extensions.contains(ChordExtension.thirteenth)
                ? 'maj13'
                : extensions.contains(ChordExtension.ninth)
                    ? 'maj9'
                    : 'maj7');
          }
          break;
        case SeventhQuality.dominant7:
          final String susTag = triad == TriadQuality.sus4
              ? 'sus4'
              : triad == TriadQuality.sus2
                  ? 'sus2'
                  : '';
          if (extensions.contains(ChordExtension.thirteenth) && susTag.isEmpty) {
            sb.write('13');
          } else if (extensions.contains(ChordExtension.eleventh) &&
              susTag.isEmpty) {
            sb.write('11');
          } else if (extensions.contains(ChordExtension.ninth) &&
              susTag.isEmpty) {
            sb.write('9');
          } else {
            sb.write('7$susTag');
          }
          break;
        case SeventhQuality.minor7:
          if (extensions.contains(ChordExtension.thirteenth)) {
            sb.write('m13');
          } else if (extensions.contains(ChordExtension.eleventh)) {
            sb.write('m11');
          } else if (extensions.contains(ChordExtension.ninth)) {
            sb.write('m9');
          } else {
            sb.write('m7');
          }
          break;
        case SeventhQuality.halfDiminished7:
          sb.write('m7b5');
          break;
        case SeventhQuality.diminished7:
          sb.write('dim7');
          break;
        case SeventhQuality.minorMajor7:
          sb.write('m(maj7)');
          break;
      }
    }

    if (extensions.contains(ChordExtension.add9) &&
        !extensions.contains(ChordExtension.ninth)) {
      sb.write('(add9)');
    } else if (seventh == SeventhQuality.none) {
      if (extensions.contains(ChordExtension.ninth)) {
        sb.write('(9)');
      }
      if (extensions.contains(ChordExtension.eleventh)) {
        sb.write('(11)');
      }
      if (extensions.contains(ChordExtension.thirteenth)) {
        sb.write('(13)');
      }
    }

    final List<String> altTags = <String>[];
    if (hasFlat5 &&
        seventh != SeventhQuality.halfDiminished7 &&
        seventh != SeventhQuality.diminished7) {
      altTags.add('b5');
    }
    if (hasSharp5 &&
        triad != TriadQuality.augmented &&
        !(seventh == SeventhQuality.major7 && hasSharp5)) {
      altTags.add('#5');
    }
    if (alterations.contains(ChordAlteration.flat9)) {
      altTags.add('b9');
    }
    if (alterations.contains(ChordAlteration.sharp9)) {
      altTags.add('#9');
    }
    if (alterations.contains(ChordAlteration.sharp11)) {
      altTags.add('#11');
    }
    if (alterations.contains(ChordAlteration.flat13)) {
      altTags.add('b13');
    }

    if (altTags.isNotEmpty) {
      sb.write('(${altTags.join(',')})');
    }

    return sb.toString();
  }
}
