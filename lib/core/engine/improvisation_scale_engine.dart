import '../models/chord_spec.dart';
import '../models/harmonic_function.dart';
import '../models/interval_profile.dart';
import '../models/midi_pitch.dart';
import '../models/scale_mode.dart';

/// A single improvisation scale or modal inflection paired with its aesthetic vibe.
class ImprovisationScaleRecommendation {
  const ImprovisationScaleRecommendation({
    required this.title,
    required this.subtitle,
    required this.pitchClasses,
    required this.noteNamesSummary,
    required this.aestheticExperience,
    this.isChordSpecific = false,
  });

  final String title;
  final String subtitle;
  final List<int> pitchClasses;
  final String noteNamesSummary;
  final String aestheticExperience;
  final bool isChordSpecific;
}

/// Complete secret oracle output for a chord progression and currently selected chord.
class ImprovisationInsightResult {
  const ImprovisationInsightResult({
    required this.progressionScales,
    required this.selectedChordScale,
  });

  final List<ImprovisationScaleRecommendation> progressionScales;
  final ImprovisationScaleRecommendation selectedChordScale;
}

/// Deterministic improvisation advisor pairing harmonic context with sensory
/// "aesthetic experience" descriptions in English or Spanish.
class ImprovisationScaleEngine {
  ImprovisationScaleEngine._();

  static const List<int> _majorPentatonicIntervals = <int>[0, 2, 4, 7, 9];
  static const List<int> _minorPentatonicAdd9Intervals = <int>[0, 2, 3, 5, 7, 10];
  static const List<int> _harmonicMinorIntervals = <int>[0, 2, 3, 5, 7, 8, 11];
  static const List<int> _phrygianDominantIntervals = <int>[0, 1, 4, 5, 7, 8, 10];
  static const List<int> _wholeHalfDimIntervals = <int>[0, 2, 3, 5, 6, 8, 9, 11];

  /// Computes 2 overarching progression scale ideas and 1 inflection for the
  /// chord at [selectedChordIndex].
  static ImprovisationInsightResult analyze({
    required List<ChordSpec> progression,
    required List<HarmonicAnalysisResult> analyses,
    required int selectedChordIndex,
    required int keyTonicPc,
    required ScaleMode keyMode,
    required bool preferFlat,
    required bool isEs,
  }) {
    if (progression.isEmpty) {
      final List<int> fallbackPcs = _transpose(_majorPentatonicIntervals, 0);
      final ImprovisationScaleRecommendation emptyRec =
          ImprovisationScaleRecommendation(
        title: isEs ? 'C Pentatónica Mayor + 9na' : 'C Major Pentatonic + 9th',
        subtitle: isEs ? 'ESCALA DE PROGRESIÓN' : 'OVERARCHING SCALE',
        pitchClasses: fallbackPcs,
        noteNamesSummary: _formatPcs(fallbackPcs, preferFlat: preferFlat),
        aestheticExperience: isEs
            ? 'Añade acordes a la progresión para revelar colores modales para improvisar.'
            : 'Add chords to the progression to unlock tailored modal improvisation vibes.',
      );
      return ImprovisationInsightResult(
        progressionScales: <ImprovisationScaleRecommendation>[emptyRec],
        selectedChordScale: emptyRec,
      );
    }

    final int? marusaParentMajorPc = _detectMarusaParentMajorPc(progression);
    final List<ImprovisationScaleRecommendation> progressionScales =
        marusaParentMajorPc != null
            ? _buildMarusaScales(
                parentMajorPc: marusaParentMajorPc,
                preferFlat: preferFlat,
                isEs: isEs,
              )
            : _buildGeneralProgressionScales(
                progression: progression,
                analyses: analyses,
                keyTonicPc: keyTonicPc,
                keyMode: keyMode,
                preferFlat: preferFlat,
                isEs: isEs,
              );

    final int safeIndex =
        selectedChordIndex.clamp(0, progression.length - 1);
    final ChordSpec selectedChord = progression[safeIndex];
    final HarmonicAnalysisResult? selectedAnalysis =
        safeIndex < analyses.length ? analyses[safeIndex] : null;

    final ImprovisationScaleRecommendation selectedChordScale =
        _buildSelectedChordScale(
      chord: selectedChord,
      analysis: selectedAnalysis,
      marusaParentMajorPc: marusaParentMajorPc,
      keyTonicPc: keyTonicPc,
      keyMode: keyMode,
      preferFlat: preferFlat,
      isEs: isEs,
    );

    return ImprovisationInsightResult(
      progressionScales: progressionScales,
      selectedChordScale: selectedChordScale,
    );
  }

  /// Detects if [progression] contains the Marusa ("Just the Two of Us") shape:
  /// IVΔ7 -> III7 -> vi7 -> (v7 -> I7) in some Major key center.
  static int? _detectMarusaParentMajorPc(List<ChordSpec> progression) {
    for (int p = 0; p < 12; p++) {
      bool hasIvMaj = false;
      bool hasIiiDom = false;
      bool hasViMin = false;
      bool hasVMinOrITurn = false;

      for (final ChordSpec c in progression) {
        final int rel = (c.normalizedRootPc - p + 12) % 12;
        final bool isMajLike = c.triad == TriadQuality.major &&
            c.seventh != SeventhQuality.dominant7;
        final bool isDom7 =
            c.triad == TriadQuality.major && c.seventh == SeventhQuality.dominant7;
        final bool isMinLike = c.triad == TriadQuality.minor;

        if (rel == 5 && isMajLike) {
          hasIvMaj = true;
        } else if (rel == 4 && isDom7) {
          hasIiiDom = true;
        } else if (rel == 9 && isMinLike) {
          hasViMin = true;
        } else if ((rel == 7 && isMinLike) || (rel == 0 && isDom7)) {
          hasVMinOrITurn = true;
        }
      }

      if (hasIvMaj && hasIiiDom && hasViMin && hasVMinOrITurn) {
        return p;
      }
    }
    return null;
  }

  static List<ImprovisationScaleRecommendation> _buildMarusaScales({
    required int parentMajorPc,
    required bool preferFlat,
    required bool isEs,
  }) {
    final String majName =
        MidiPitch.pitchClassName(parentMajorPc, preferFlat: preferFlat);
    final int relMinPc = (parentMajorPc + 9) % 12;
    final String minName =
        MidiPitch.pitchClassName(relMinPc, preferFlat: preferFlat);

    final List<int> pent9Pcs =
        _transpose(_majorPentatonicIntervals, parentMajorPc);
    final List<int> parentMajPcs =
        _transpose(ScaleMode.ionian.semitoneIntervals, parentMajorPc);
    final int mixoB7Pc = (parentMajorPc + 10) % 12;
    final String mixoB7Name =
        MidiPitch.pitchClassName(mixoB7Pc, preferFlat: preferFlat);

    return <ImprovisationScaleRecommendation>[
      ImprovisationScaleRecommendation(
        title: isEs
            ? '$majName Pentatónica Mayor + 9na ($minName Pent. Menor)'
            : '$majName Major Pentatonic with the 9th ($minName Minor Pent. + 9th)',
        subtitle: isEs
            ? 'ESCALA 1 · VUELO SIN GRAVEDAD'
            : 'SCALE 1 · WEIGHTLESS FLOAT',
        pitchClasses: pent9Pcs,
        noteNamesSummary: _formatPcs(pent9Pcs, preferFlat: preferFlat),
        aestheticExperience: isEs
            ? '$majName Pentatónica Mayor con la 9na sobre la progresión Marusa se siente como deslizarse suavemente sobre las calles de la ciudad sin tocar nunca el pavimento. Al evitar los semitonos tensos e ignorar los desvíos armónicos del final del compás, la melodía se mantiene liviana, nostálgica y distante: flotando con calma sobre los cambios de acordes como ver las gotas de lluvia difuminarse tras la ventana de un tren mientras la armonía se transforma debajo.'
            : '$majName Major Pentatonic with the 9th over the Marusa progression feels like gliding smoothly above the city streets without ever touching the pavement. Because it skips the tense half-steps and ignores the harmonic detours at the end of the bar, the melody stays weightless, nostalgic, and detached—floating calmly over the chord changes like watching rain streaks blur past a train window while the harmony shifts underneath you.',
      ),
      ImprovisationScaleRecommendation(
        title: isEs
            ? '$majName Mayor Padre → $majName Mixolidia en el giro v7–I7'
            : '$majName Parent Major into $majName Mixolydian (v7 – I7 turnaround)',
        subtitle: isEs
            ? 'ESCALA 2 · GIRO NOCTURNO'
            : 'SCALE 2 · NOCTURNAL GRAVITY',
        pitchClasses: <int>[...parentMajPcs, mixoB7Pc],
        noteNamesSummary:
            '${_formatPcs(parentMajPcs, preferFlat: preferFlat)} → +$mixoB7Name (b7)',
        aestheticExperience: isEs
            ? 'La escala Mayor padre entrando en $majName Mixolidia durante el giro v7 – I7 se siente como salir por fin a la calle y percibir el descenso repentino de la temperatura. La escala Mayor aporta una calidez luminosa y familiar en los primeros acordes, pero rebajar esa séptima a $mixoB7Name (Mixolidia) introduce al instante una gravedad agridulce y nocturna que empuja la melodía hacia el acorde IV con una melancolía cinematográfica y serena, en lugar de una resolución brillante.'
            : 'Parent $majName Major scale into $majName Mixolydian on the v7 – I7 turnaround feels like actually stepping out into the street and feeling the sudden drop in temperature. The Major scale carries a familiar, sunlit warmth through the first three chords, but flattening that seventh into $mixoB7Name (Mixolydian) immediately introduces a bittersweet, nocturnal gravity—pulling the melody downward into the IV chord with a quiet, cinematic ache rather than a bright resolution.',
      ),
    ];
  }

  static List<ImprovisationScaleRecommendation> _buildGeneralProgressionScales({
    required List<ChordSpec> progression,
    required List<HarmonicAnalysisResult> analyses,
    required int keyTonicPc,
    required ScaleMode keyMode,
    required bool preferFlat,
    required bool isEs,
  }) {
    final String tonicName =
        MidiPitch.pitchClassName(keyTonicPc, preferFlat: preferFlat);
    final bool hasSecondaryDom = analyses.any(
      (HarmonicAnalysisResult a) =>
          a.category == HarmonicCategory.secondaryDominant,
    );
    final bool hasBorrowed = analyses.any(
      (HarmonicAnalysisResult a) => a.category == HarmonicCategory.borrowed,
    );

    if (keyMode.isMinorFamily) {
      final List<int> minPent9 =
          _transpose(_minorPentatonicAdd9Intervals, keyTonicPc);
      final List<int> dorianPcs =
          _transpose(ScaleMode.dorian.semitoneIntervals, keyTonicPc);
      final List<int> harmMinorPcs =
          _transpose(_harmonicMinorIntervals, keyTonicPc);
      final bool hasMajorV = progression.any((ChordSpec c) {
        final int rel = (c.normalizedRootPc - keyTonicPc + 12) % 12;
        return rel == 7 && c.triad == TriadQuality.major;
      });

      return <ImprovisationScaleRecommendation>[
        ImprovisationScaleRecommendation(
          title: isEs
              ? '$tonicName Pentatónica Menor + 9na'
              : '$tonicName Minor Pentatonic with the 9th',
          subtitle: isEs
              ? 'ESCALA 1 · NÚCLEO ATMOSFÉRICO'
              : 'SCALE 1 · ATMOSPHERIC CORE',
          pitchClasses: minPent9,
          noteNamesSummary: _formatPcs(minPent9, preferFlat: preferFlat),
          aestheticExperience: isEs
              ? '$tonicName Pentatónica Menor con la 9na envuelve esta progresión en una penumbra azulada y reflexiva. Esa 9na añadida suaviza el filo del modo menor y deja respirar las frases como ecos lejanos sobre asfalto húmedo tras el anochecer.'
              : '$tonicName Minor Pentatonic with the 9th wraps this progression in an amber-lit twilight haze. That added 9th softens the stark edges of minor harmony, letting phrases hover like quiet afterthoughts hanging in cool evening air.',
        ),
        if (hasMajorV)
          ImprovisationScaleRecommendation(
            title: isEs
                ? '$tonicName Eolia → $tonicName Menor Armónica en el V7'
                : '$tonicName Aeolian into $tonicName Harmonic Minor',
            subtitle: isEs
                ? 'ESCALA 2 · TENSIÓN MAGNÉTICA'
                : 'SCALE 2 · MAGNETIC TENSION',
            pitchClasses: harmMinorPcs,
            noteNamesSummary: _formatPcs(harmMinorPcs, preferFlat: preferFlat),
            aestheticExperience: isEs
                ? 'Pasar de la calma natural de $tonicName Eolia al semitono elevado de $tonicName Menor Armónica sobre el V7 se siente como cruzar un umbral iluminado por antorchas: la gravedad de repente se inclina hacia la tónica con una urgencia dramática y casi teatral.'
                : 'Stepping from natural $tonicName Aeolian into $tonicName Harmonic Minor across the V7 feels like turning down a narrow stone alley lit by a single warm lamp—suddenly every step leans forward with dramatic, theatrical inevitability toward home.',
          )
        else
          ImprovisationScaleRecommendation(
            title: isEs ? '$tonicName Dórica' : '$tonicName Dorian',
            subtitle: isEs
                ? 'ESCALA 2 · CONTRASTE LUMINOSO'
                : 'SCALE 2 · URBAN GROOVE',
            pitchClasses: dorianPcs,
            noteNamesSummary: _formatPcs(dorianPcs, preferFlat: preferFlat),
            aestheticExperience: isEs
                ? '$tonicName Dórica introduce una sexta mayor que entra como un rayo de neón tibio en una habitación oscura: conserva el pulso introspectivo del menor pero con un groove elegante que se niega a caer en la tristeza absoluta.'
                : '$tonicName Dorian brings in the natural 6th like warm neon cutting across midnight pavement—keeping the melancholic depth intact while giving every melodic turn a soulful, forward-moving resilience.',
          ),
      ];
    }

    // Major-family progressions
    final List<int> majPent9 =
        _transpose(_majorPentatonicIntervals, keyTonicPc);
    final List<int> lydianPcs =
        _transpose(ScaleMode.lydian.semitoneIntervals, keyTonicPc);
    final List<int> ionianPcs =
        _transpose(ScaleMode.ionian.semitoneIntervals, keyTonicPc);
    final List<int> aeolianPcs =
        _transpose(ScaleMode.aeolian.semitoneIntervals, keyTonicPc);

    final ImprovisationScaleRecommendation secondScale;
    if (hasBorrowed) {
      secondScale = ImprovisationScaleRecommendation(
        title: isEs
            ? '$tonicName Mayor ↔ $tonicName Eolia / Mixolidia (Cruce Modal)'
            : '$tonicName Major ↔ $tonicName Aeolian / Mixolydian Shift',
        subtitle: isEs
            ? 'ESCALA 2 · SOMBRA Y CLAROSCURO'
            : 'SCALE 2 · BITTERSWEET SHADOW',
        pitchClasses: aeolianPcs,
        noteNamesSummary:
            '${_formatPcs(ionianPcs, preferFlat: preferFlat)} → ${_formatPcs(aeolianPcs, preferFlat: true)}',
        aestheticExperience: isEs
            ? 'Alternar entre $tonicName Mayor y su modo paralelo menor ($tonicName Eolia) en los acordes prestados se siente como ver pasar una nube sobre un jardín soleado: la luz diatónica se enfría por un instante en una nostalgia cinematográfica antes de volver a abrirse.'
            : 'Shifting from $tonicName Major into parallel $tonicName Aeolian over the borrowed chords feels like a sudden cloud drifting across late-afternoon sun—turning sunlit clarity into brief, heart-tugging nostalgia before the light returns.',
      );
    } else if (hasSecondaryDom) {
      secondScale = ImprovisationScaleRecommendation(
        title: isEs
            ? '$tonicName Mayor Padre + Notas Guía Cromáticas'
            : '$tonicName Parent Major + Chromatic Guide Tones',
        subtitle: isEs
            ? 'ESCALA 2 · IMPULSO Y TENSIÓN'
            : 'SCALE 2 · FORWARD PULL',
        pitchClasses: ionianPcs,
        noteNamesSummary: _formatPcs(ionianPcs, preferFlat: preferFlat),
        aestheticExperience: isEs
            ? 'Caminar por $tonicName Mayor dejando que las terceras alteradas de cada dominante secundario inclinen la frase se siente como viajar en carretera de noche: cada desvío cromático acelera el pulso por un segundo antes de aterrizar suavemente en el acorde objetivo.'
            : 'Weaving through $tonicName Major while bending into the altered 3rds of each secondary dominant feels like catching every green light on an empty avenue—each chromatic detour tightens gravity for half a bar before landing effortlessly on target.',
      );
    } else {
      secondScale = ImprovisationScaleRecommendation(
        title: isEs ? '$tonicName Lidia' : '$tonicName Lydian',
        subtitle: isEs
            ? 'ESCALA 2 · HORIZONTE SUSPENDIDO'
            : 'SCALE 2 · SUSPENDED HORIZON',
        pitchClasses: lydianPcs,
        noteNamesSummary: _formatPcs(lydianPcs, preferFlat: preferFlat),
        aestheticExperience: isEs
            ? '$tonicName Lidia eleva la cuarta justa y suspende la sensación de gravedad: se siente como despegar lentamente sobre nubes iluminadas al atardecer, con un asombro etéreo que nunca tiene prisa por caer a tierra.'
            : '$tonicName Lydian raises the 4th to dissolve downward gravity—sounding like rising gently above sunlit clouds at golden hour, bright and wide-eyed without any hurry to settle back to earth.',
      );
    }

    return <ImprovisationScaleRecommendation>[
      ImprovisationScaleRecommendation(
        title: isEs
            ? '$tonicName Pentatónica Mayor + 9na'
            : '$tonicName Major Pentatonic with the 9th',
        subtitle: isEs
            ? 'ESCALA 1 · VUELO SUAVE'
            : 'SCALE 1 · WEIGHTLESS MELODY',
        pitchClasses: majPent9,
        noteNamesSummary: _formatPcs(majPent9, preferFlat: preferFlat),
        aestheticExperience: isEs
            ? '$tonicName Pentatónica Mayor con la 9na flota limpiamente por encima de toda la progresión. Al omitir los semitonos tensos, cada frase respira con una calma luminosa y nostálgica, como observar las luces de la ciudad desde la altura mientras la armonía cambia debajo.'
            : '$tonicName Major Pentatonic with the 9th floats effortlessly above the whole progression. By skipping tense half-steps, every phrase stays weightless, warm, and unhurried—like watching city lights drift past a train window while the chords shift underneath.',
      ),
      secondScale,
    ];
  }

  static ImprovisationScaleRecommendation _buildSelectedChordScale({
    required ChordSpec chord,
    required HarmonicAnalysisResult? analysis,
    required int? marusaParentMajorPc,
    required int keyTonicPc,
    required ScaleMode keyMode,
    required bool preferFlat,
    required bool isEs,
  }) {
    final String chordSymbol = chord.symbol(preferFlat: preferFlat);
    final String chordRoot = MidiPitch.pitchClassName(
      chord.normalizedRootPc,
      preferFlat: preferFlat,
    );

    if (marusaParentMajorPc != null) {
      final int rel = (chord.normalizedRootPc - marusaParentMajorPc + 12) % 12;
      final String parentName = MidiPitch.pitchClassName(
        marusaParentMajorPc,
        preferFlat: preferFlat,
      );
      if (rel == 4 && chord.seventh == SeventhQuality.dominant7) {
        final List<int> phrygDom = _transpose(
          _phrygianDominantIntervals,
          chord.normalizedRootPc,
        );
        return ImprovisationScaleRecommendation(
          title: isEs
              ? '$chordRoot Frigia Dominante (sobre $chordSymbol)'
              : '$chordRoot Phrygian Dominant (over $chordSymbol)',
          subtitle: isEs
              ? 'MATIZ SOBRE EL III7'
              : 'INFLECTION ON III7',
          pitchClasses: phrygDom,
          noteNamesSummary: _formatPcs(phrygDom, preferFlat: preferFlat),
          aestheticExperience: isEs
              ? 'Sobre $chordSymbol, esa 3.ª mayor ajena a la escala abre una tensión magnética de neón y terciopelo: una curva oriental y urbana que pide a gritos resolver en la calma del acorde vi.'
              : 'Over $chordSymbol, that out-of-key major 3rd ignites a velvet-and-neon tension—an intimate, restless curve that pulls the ear straight toward the sanctuary of the vi chord.',
          isChordSpecific: true,
        );
      }
      if ((rel == 7 && chord.triad == TriadQuality.minor) ||
          (rel == 0 && chord.seventh == SeventhQuality.dominant7)) {
        final List<int> mixoPcs = _transpose(
          ScaleMode.mixolydian.semitoneIntervals,
          marusaParentMajorPc,
        );
        return ImprovisationScaleRecommendation(
          title: isEs
              ? '$parentName Mixolidia (sobre $chordSymbol)'
              : '$parentName Mixolydian (over $chordSymbol)',
          subtitle: isEs
              ? 'EL GIRO DE TEMPERATURA (b7)'
              : 'TEMPERATURE DROP (b7)',
          pitchClasses: mixoPcs,
          noteNamesSummary: _formatPcs(mixoPcs, preferFlat: true),
          aestheticExperience: isEs
              ? 'Justo aquí en $chordSymbol es donde baja la temperatura: cambiar la 7.ª mayor por la b7 Mixolidia derrite la luz del día y empuja la frase con dulzura hacia el Fmaj7.'
              : 'Right here on $chordSymbol is where the air turns crisp: trading the natural 7th for Mixolydian b7 dissolves daylight and leans gently down into the IVmaj7.',
          isChordSpecific: true,
        );
      }
    }

    if (analysis != null) {
      if (analysis.category == HarmonicCategory.secondaryDominant) {
        final bool isMinorTarget =
            analysis.targetRoman == 'ii' ||
            analysis.targetRoman == 'iii' ||
            analysis.targetRoman == 'vi';
        final List<int> pcs = _transpose(
          isMinorTarget
              ? _phrygianDominantIntervals
              : ScaleMode.mixolydian.semitoneIntervals,
          chord.normalizedRootPc,
        );
        final String modeLabel = isMinorTarget
            ? (isEs ? 'Frigia Dominante' : 'Phrygian Dominant')
            : (isEs ? 'Mixolidia' : 'Mixolydian');
        return ImprovisationScaleRecommendation(
          title: '$chordRoot $modeLabel ($chordSymbol)',
          subtitle: isEs
              ? 'IMPULSO SECUNDARIO (${analysis.romanNumeral})'
              : 'SECONDARY PULL (${analysis.romanNumeral})',
          pitchClasses: pcs,
          noteNamesSummary: _formatPcs(pcs, preferFlat: preferFlat),
          aestheticExperience: isEs
              ? 'Sobre este dominante secundario (${analysis.romanNumeral}), $chordRoot $modeLabel actúa como un imán repentino: enfoca el contraste cromático un instante antes de aterrizar en ${analysis.targetRoman ?? "el siguiente acorde"}.'
              : 'Over this secondary dominant (${analysis.romanNumeral}), $chordRoot $modeLabel acts like a sudden spotlight—sharpening harmonic gravity for one beat before landing cleanly on ${analysis.targetRoman ?? "the next chord"}.',
          isChordSpecific: true,
        );
      }

      if (analysis.category == HarmonicCategory.borrowed &&
          analysis.borrowedFromMode != null) {
        final ScaleMode bMode = analysis.borrowedFromMode!;
        final String tonicName = MidiPitch.pitchClassName(
          keyTonicPc,
          preferFlat: true,
        );
        final List<int> pcs =
            _transpose(bMode.semitoneIntervals, keyTonicPc);
        return ImprovisationScaleRecommendation(
          title: '$tonicName ${bMode.shortLabel} ($chordSymbol)',
          subtitle: isEs
              ? 'COLOR PRESTADO (${analysis.romanNumeral})'
              : 'BORROWED COLOR (${analysis.romanNumeral})',
          pitchClasses: pcs,
          noteNamesSummary: _formatPcs(pcs, preferFlat: true),
          aestheticExperience: isEs
              ? 'Como $chordSymbol viene prestado de ${bMode.shortLabel}, entrar aquí en $tonicName ${bMode.shortLabel} tiñe la escena con un filtro cinematográfico inesperado antes de volver a casa.'
              : 'Because $chordSymbol is borrowed from ${bMode.shortLabel}, stepping into $tonicName ${bMode.shortLabel} tints the scene like a sudden film color grade before returning home.',
          isChordSpecific: true,
        );
      }

      if (analysis.category == HarmonicCategory.diminishedPassing) {
        final List<int> pcs =
            _transpose(_wholeHalfDimIntervals, chord.normalizedRootPc);
        return ImprovisationScaleRecommendation(
          title: isEs
              ? '$chordRoot Disminuida Tono-Semitono ($chordSymbol)'
              : '$chordRoot Whole-Half Diminished ($chordSymbol)',
          subtitle: isEs ? 'PUENTE SIMÉTRICO' : 'SYMMETRIC BRIDGE',
          pitchClasses: pcs,
          noteNamesSummary: _formatPcs(pcs, preferFlat: preferFlat),
          aestheticExperience: isEs
              ? 'Sobre $chordSymbol, la escala disminuida tono-semitono suspende la sensación de piso firme como una escalera en espiral que desliza la melodía medio tono hacia el siguiente acorde.'
              : 'Over $chordSymbol, the Whole-Half Diminished scale suspends the floor like a spiral staircase—gliding the melody cleanly by half-step into the target chord.',
          isChordSpecific: true,
        );
      }
    }

    // Default diatonic chord inflection
    final ScaleMode localMode = chord.triad == TriadQuality.minor
        ? ScaleMode.dorian
        : (chord.seventh == SeventhQuality.dominant7
            ? ScaleMode.mixolydian
            : (analysis?.scaleDegreeSemitones == 5
                ? ScaleMode.lydian
                : keyMode));
    final List<int> pcs = _transpose(
      localMode.semitoneIntervals,
      localMode == keyMode ? keyTonicPc : chord.normalizedRootPc,
    );
    final String rootLabel = localMode == keyMode
        ? MidiPitch.pitchClassName(keyTonicPc, preferFlat: preferFlat)
        : chordRoot;
    return ImprovisationScaleRecommendation(
      title: '$rootLabel ${localMode.shortLabel} ($chordSymbol)',
      subtitle: isEs ? 'COLOR DEL ACORDE ACTUAL' : 'ACTIVE CHORD COLOR',
      pitchClasses: pcs,
      noteNamesSummary: _formatPcs(pcs, preferFlat: preferFlat),
      aestheticExperience: isEs
          ? 'Sobre $chordSymbol, apoyar las frases en la 3.ª y 7.ª del acorde dentro de $rootLabel ${localMode.shortLabel} mantiene el relato melódico íntimo, respirable y conectado con el pulso de la armonía.'
          : 'Over $chordSymbol, resting phrases on the chord’s 3rd and 7th inside $rootLabel ${localMode.shortLabel} keeps your melody intimate, grounded, and woven directly into the harmony.',
      isChordSpecific: true,
    );
  }

  static List<int> _transpose(List<int> intervals, int rootPc) {
    return intervals.map((int i) => (rootPc + i) % 12).toList();
  }

  static String _formatPcs(List<int> pcs, {required bool preferFlat}) {
    return pcs
        .map((int pc) => MidiPitch.pitchClassName(pc, preferFlat: preferFlat))
        .join(' · ');
  }
}
