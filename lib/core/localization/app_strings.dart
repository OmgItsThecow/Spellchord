import '../models/harmonic_function.dart';
import '../models/interval_profile.dart';
import '../models/scale_mode.dart';

/// Supported interface languages.
enum AppLanguage {
  en,
  es,
}

/// UI complexity level toggled from the startup selector or top bar.
enum ComplexityMode {
  basic,
  advanced,
}

/// Bilingual English / Spanish dictionary for all labels, explanations, and
/// beginner vs. advanced harmony terminology.
class AppStrings {
  const AppStrings(this.lang);

  final AppLanguage lang;

  bool get isEs => lang == AppLanguage.es;

  String get appTitle => 'SPELLCHORD';

  String get appSubtitle => isEs
      ? 'Explorador Armónico y Modal'
      : 'Harmonic & Modal Explorer';

  String get appSubtitleBasic => isEs
      ? 'Explorador Armónico y Modal'
      : 'Harmonic & Modal Explorer';

  String get basicModeLabel => isEs ? 'Básico' : 'Basic';
  String get advancedModeLabel => isEs ? 'Avanzado' : 'Advanced';

  String get switchToBasicTip => isEs
      ? 'Cambiar a Modo Básico (vista simplificada para principiantes sin números MIDI ni alteraciones complejas).'
      : 'Switch to Basic Mode (simplified beginner layout without raw MIDI numbers or complex alterations).';

  String get switchToAdvancedTip => isEs
      ? 'Cambiar a Modo Avanzado (números MIDI, los 7 modos, tabla SATB por voz y afinaciones personalizadas).'
      : 'Switch to Advanced Mode (full MIDI numbers, all 7 modes, SATB voice table, and custom guitar tunings).';

  String get toggleLanguageTip => isEs
      ? 'Cambiar el idioma de la interfaz entre español e inglés.'
      : 'Switch interface language between English and Spanish.';

  String get defaultHelpPrompt => isEs
      ? 'Pasa el cursor (escritorio) o mantén presionado (Android) cualquier botón para ver qué hace.'
      : 'Hover over (desktop) or long-press (Android) any button or control to see what it does.';

  // --- Key Center Bar ---

  String get keyAuto => isEs ? 'AUTO' : 'AUTO KEY';
  String get keyLocked => isEs ? 'FIJADA' : 'KEY LOCKED';
  String get keyBasicLabel => isEs ? 'TONALIDAD' : 'KEY';
  String get presetLabel => isEs ? 'EJEMPLO' : 'PRESET';
  String get loadProgressionHint =>
      isEs ? 'Cargar Progresión...' : 'Load Progression...';

  String optimalVlLabel(int cost, {required bool isBasic}) {
    if (isBasic) {
      return isEs ? 'Suavizar Todo' : 'Smooth All';
    }
    return isEs ? 'Enlace Óptimo ($cost st)' : 'Optimal VL ($cost st)';
  }

  String basicScaleLabel(ScaleMode mode) {
    if (mode == ScaleMode.aeolian || mode.isMinorFamily) {
      return isEs ? 'Menor' : 'Minor';
    }
    return isEs ? 'Mayor' : 'Major';
  }

  String get keyRootTip => isEs
      ? 'Elige la nota tónica para transponer los acordes de la progresión y actualizar el análisis.'
      : 'Select the tonal center root note to transpose the progression chords and update analysis.';

  String get keyScaleTip => isEs
      ? 'Elige la escala o modo para adaptar los acordes diatónicos y el análisis armónico.'
      : 'Choose the scale or mode to adapt diatonic chords and harmonic analysis.';

  String keyLockTip(bool isLocked) {
    if (isLocked) {
      return isEs
          ? 'Desbloquear tonalidad para detectarla automáticamente según los acordes.'
          : 'Unlock key center to auto-detect tonic and mode from the chord progression.';
    }
    return isEs
        ? 'Fijar la tonalidad actual para que los cambios no alteren el análisis.'
        : 'Lock the current tonal center so edits do not shift Roman numeral analysis.';
  }

  String get presetTip => isEs
      ? 'Cargar una progresión de ejemplo con dominantes secundarios, acordes de paso o intercambio modal.'
      : 'Load a curated chord progression template demonstrating secondary dominants, passing chords, or modal interchange.';

  String presetDisplayName(String presetKey) {
    switch (presetKey) {
      case 'Pop Anthem + Minor iv':
        return isEs
            ? 'Pop Clásico + iv Menor (C–G–Am–F–Fm)'
            : 'Pop Anthem + Minor iv (C–G–Am–F–Fm)';
      case '50s / Soul Turnaround':
        return isEs
            ? 'Soul / Años 50 (G–Em7–Am7–D7)'
            : '50s / Soul Turnaround (G–Em7–Am7–D7)';
      case 'Andalusian Cadence':
        return isEs
            ? 'Cadencia Andaluza (Am–G–Fmaj7–E7)'
            : 'Andalusian Cadence (Am–G–Fmaj7–E7)';
      case 'Royal Road (J-Pop)':
        return isEs
            ? 'Royal Road J-Pop (Fmaj7–G7–Em7–Am7)'
            : 'Royal Road J-Pop (Fmaj7–G7–Em7–Am7)';
      case 'Marusa (Just the Two of Us)':
        return isEs
            ? 'Progresión Marusa / Just the Two of Us (Fmaj7–Em7–Am7–Gm7–C7)'
            : 'Marusa / Just the Two of Us (Fmaj7–Em7–Am7–Gm7–C7)';
      case 'Bossa Nova Turnaround':
        return isEs
            ? 'Bossa Nova (Fmaj7–G9–Gm7–C13)'
            : 'Bossa Nova Turnaround (Fmaj7–G9–Gm7–C13)';
      case 'ii-V-I + Sec Dom':
        return isEs
            ? 'Jazz ii-V-I + Dom. Sec. (Dm9–G13–Cmaj9–A7b9)'
            : 'ii-V-I + Sec Dom (Dm9–G13–Cmaj9–A7b9)';
      case 'Modal Interchange':
        return isEs ? 'Intercambio Modal (bVI–bVII–iv)' : 'Modal Interchange';
      case 'Diminished Passing':
        return isEs ? 'Acordes de Paso Disminuidos' : 'Diminished Passing';
      case 'Neo-Soul Extended':
        return isEs ? 'Neo-Soul Extendido' : 'Neo-Soul Extended';
      default:
        return presetKey;
    }
  }

  String get savePresetLabel => isEs ? 'Guardar' : 'Save';
  String get savePresetDialogTitle =>
      isEs ? 'Guardar Progresión Personalizada' : 'Save Custom Preset';
  String get presetNameHint => isEs
      ? 'Escribe un nombre (ej. Mi Progresión)...'
      : 'Enter a name (e.g. My Jazz Turnaround)...';
  String get currentProgressionPreviewLabel =>
      isEs ? 'Acordes a guardar:' : 'Chords to save:';
  String get savedUserPresetsSectionLabel =>
      isEs ? 'TUS PROGRESIONES GUARDADAS' : 'YOUR SAVED PRESETS';
  String get noSavedPresetsHint => isEs
      ? 'Aún no has guardado progresiones personalizadas.'
      : 'No custom presets saved yet.';
  String get savePresetBtnLabel => isEs ? 'Guardar Preset' : 'Save Preset';
  String get loadLabel => isEs ? 'Cargar' : 'Load';

  String get savePresetTip => isEs
      ? 'Guardar la progresión de acordes actual como un ajuste personalizado.'
      : 'Save the current chord progression as a custom preset.';

  String deletePresetTip(String name) => isEs
      ? 'Eliminar la progresión guardada "$name".'
      : 'Delete saved preset "$name".';

  String presetSavedFeedback(String name) => isEs
      ? 'Progresión "$name" guardada en tus ajustes.'
      : 'Saved custom preset "$name".';

  String presetDeletedFeedback(String name) => isEs
      ? 'Progresión "$name" eliminada.'
      : 'Deleted custom preset "$name".';

  String optimalVlTip({required bool isBasic}) => isBasic
      ? (isEs
          ? 'Ajustar automáticamente todos los acordes a sus inversiones más suaves.'
          : 'Automatically arrange all chords into their smoothest connecting shapes.')
      : (isEs
          ? 'Quitar inversiones manuales y recalcular la mínima distancia en semitonos en toda la progresión.'
          : 'Clear manual inversion overrides and recalculate minimum-semitone voice leading across all chords.');

  // --- Progression Timeline ---

  String get progressionTitle =>
      isEs ? 'LÍNEA DE PROGRESIÓN' : 'PROGRESSION TIMELINE';

  String chordsCount(int count) =>
      isEs ? '$count acordes' : '$count chords';

  String get editSelectedLabel => isEs ? 'Editar' : 'Edit Selected';
  String get addChordLabel => isEs ? 'Añadir Acorde' : 'Add Chord';
  String get playChordLabel => isEs ? 'Sonar' : 'Play';
  String get playAllLabel => isEs ? 'Reproducir' : 'Play All';
  String get stopPlaybackLabel => isEs ? 'Detener' : 'Stop';

  String get editSelectedTip => isEs
      ? 'Cambiar la nota raíz, calidad o notas del acorde seleccionado.'
      : 'Modify root note, chord quality, extensions, or alterations for the selected chord.';

  String get addChordTip => isEs
      ? 'Construir y agregar un nuevo acorde al final de la progresión.'
      : 'Build and append a new chord to the progression.';

  String get playChordTip => isEs
      ? 'Escuchar el acorde seleccionado con el timbre del instrumento activo (Piano o Guitarra).'
      : 'Hear the selected chord using the active instrument timbre (Piano or Guitar).';

  String playProgressionTip(bool isPlaying) {
    if (isPlaying) {
      return isEs
          ? 'Detener la reproducción de la progresión.'
          : 'Stop progression playback.';
    }
    return isEs
        ? 'Reproducir toda la progresión en orden usando el instrumento activo.'
        : 'Play through the entire chord progression in order using the active instrument.';
  }

  String soundToggleTip(bool enabled) => isEs
      ? (enabled
          ? 'Silenciar el audio automático de los acordes.'
          : 'Activar el audio sintetizado de piano y guitarra.')
      : (enabled
          ? 'Mute automatic chord audio playback.'
          : 'Enable synthesized piano and guitar chord audio.');

  String soundToggleFeedback(bool enabled) => isEs
      ? (enabled
          ? 'Audio activado (Piano y Guitarra sintetizados).'
          : 'Audio silenciado.')
      : (enabled
          ? 'Audio enabled (Synthesized Piano & Guitar).'
          : 'Audio muted.');

  String basicCategoryLabel(HarmonicCategory category) {
    switch (category) {
      case HarmonicCategory.tonic:
        return isEs ? 'Casa (Reposo)' : 'Home (Stable)';
      case HarmonicCategory.subdominant:
        return isEs ? 'Puente (Color)' : 'Bridge (Move)';
      case HarmonicCategory.dominant:
        return isEs ? 'Tensión (Vuelve)' : 'Tension (Pull)';
      case HarmonicCategory.secondaryDominant:
        return isEs ? 'Impulso Extra' : 'Extra Pull';
      case HarmonicCategory.diminishedPassing:
        return isEs ? 'Acorde de Paso' : 'Passing Step';
      case HarmonicCategory.borrowed:
        return isEs ? 'Color Prestado' : 'Borrowed Color';
      case HarmonicCategory.chromaticMediant:
        return isEs ? 'Giro Cromático' : 'Color Shift';
    }
  }

  String shortInversionLabel(int inv) {
    switch (inv) {
      case 0:
        return isEs ? 'Fund.' : 'Root';
      case 1:
        return isEs ? '1.ª Inv' : '1st Inv';
      case 2:
        return isEs ? '2.ª Inv' : '2nd Inv';
      case 3:
        return isEs ? '3.ª Inv' : '3rd Inv';
      default:
        return isEs ? '$inv.ª Inv' : '${inv}th Inv';
    }
  }

  String inversionLabel(int inv) {
    switch (inv) {
      case 0:
        return isEs ? 'Posición Fundamental' : 'Root Position';
      case 1:
        return isEs ? '1.ª Inversión' : '1st Inversion';
      case 2:
        return isEs ? '2.ª Inversión' : '2nd Inversion';
      case 3:
        return isEs ? '3.ª Inversión' : '3rd Inversion';
      default:
        return isEs ? '$inv.ª Inversión' : '${inv}th Inversion';
    }
  }

  String get manualTag => 'MANUAL';
  String get autoTag => 'AUTO';

  String keepCountLabel(int n) => isEs ? '$n igual' : '$n keep';

  String chordCardTip(String symbol, String roman) => isEs
      ? 'Seleccionar $symbol ($roman) para ver inversiones, acordes prestados y diagramas. Doble clic para editar.'
      : 'Select $symbol ($roman) to inspect voice leading, modal swaps, and instrument diagrams. Double-click to edit.';

  String get moveLeftTip => isEs
      ? 'Mover este acorde antes en la progresión.'
      : 'Move chord earlier in the progression.';
  String get moveRightTip => isEs
      ? 'Mover este acorde después en la progresión.'
      : 'Move chord later in the progression.';
  String get removeChordTip => isEs
      ? 'Eliminar este acorde de la progresión.'
      : 'Remove this chord from the progression.';

  // --- Chord Builder Dialog ---

  String get addChordTitle => isEs ? 'Añadir Acorde' : 'Add Chord';
  String get editChordTitle => isEs ? 'Editar Acorde' : 'Edit Chord';
  String get rootPcSection =>
      isEs ? 'CLASE DE ALTURA RAÍZ (0–11)' : 'ROOT PITCH CLASS (0–11)';
  String get rootBasicSection => isEs ? 'NOTA RAÍZ' : 'ROOT NOTE';
  String get triadSection =>
      isEs ? 'TRÍADA / ESTRUCTURA BASE' : 'TRIAD / BASE STRUCTURE';
  String get seventhSection =>
      isEs ? 'TIPO DE SÉPTIMA' : 'SEVENTH QUALITY';
  String get extensionsSection => isEs ? 'EXTENSIONES' : 'EXTENSIONS';
  String get alterationsSection => isEs ? 'ALTERACIONES' : 'ALTERATIONS';
  String get cancelLabel => isEs ? 'Cancelar' : 'Cancel';
  String get applyChordLabel => isEs ? 'Aplicar Acorde' : 'Apply Chord';
  String get semitoneIntervalsPrefix =>
      isEs ? 'Intervalos en semitonos' : 'Semitone Intervals';
  String get pitchClassesPrefix =>
      isEs ? 'Clases de altura (mód 12)' : 'Pitch Classes (mod 12)';

  String triadName(TriadQuality t) {
    switch (t) {
      case TriadQuality.major:
        return isEs ? 'Mayor' : 'Major';
      case TriadQuality.minor:
        return isEs ? 'Menor' : 'Minor';
      case TriadQuality.diminished:
        return isEs ? 'Disminuido' : 'Diminished';
      case TriadQuality.augmented:
        return isEs ? 'Aumentado' : 'Augmented';
      case TriadQuality.sus2:
        return 'Sus2';
      case TriadQuality.sus4:
        return 'Sus4';
    }
  }

  String seventhName(SeventhQuality s) {
    switch (s) {
      case SeventhQuality.none:
        return isEs ? 'Solo Tríada' : 'Triad Only';
      case SeventhQuality.major7:
        return 'maj7';
      case SeventhQuality.dominant7:
        return isEs ? '7 (Dom)' : '7 (Dom)';
      case SeventhQuality.minor7:
        return 'm7';
      case SeventhQuality.halfDiminished7:
        return 'm7b5';
      case SeventhQuality.diminished7:
        return 'dim7';
      case SeventhQuality.minorMajor7:
        return 'm(maj7)';
    }
  }

  // --- Voice Leading Panel ---

  String get voiceLeadingTitle =>
      isEs ? 'INVERSIÓN Y CONDUCCIÓN' : 'INVERSION & VOICE LEADING';
  String get voiceLeadingBasicTitle =>
      isEs ? 'CONEXIONES SUAVES' : 'SMOOTH CONNECTIONS';
  String get voiceLeadingTab => isEs ? 'Conducción' : 'Voice Leading';
  String get modalInterchangeTab =>
      isEs ? 'Intercambio Modal' : 'Modal Interchange';

  String get prevInversionTip => isEs
      ? 'Ir a la inversión anterior del acorde.'
      : 'Step to the previous chord inversion.';
  String get nextInversionTip => isEs
      ? 'Ir a la siguiente inversión del acorde.'
      : 'Step to the next chord inversion.';
  String get spacingLabel => isEs ? 'Posición' : 'Spacing';
  String get spacingTip => isEs
      ? 'Alternar entre disposiciones cerradas y abiertas en el teclado.'
      : 'Cycle through alternative close and open/drop keyboard spacings for the active inversion.';
  String autoOptimalLabel({required bool isBasic}) => isBasic
      ? (isEs ? 'Auto Suave' : 'Auto Smooth')
      : (isEs ? 'Auto Óptimo' : 'Auto Optimal');
  String get autoOptimalTip => isEs
      ? 'Quitar el bloqueo manual y elegir la inversión de menor movimiento.'
      : 'Release manual override and restore automatic minimum-distance voice leading for this chord.';

  String inversionChipTip(String label, String bassName) => isEs
      ? 'Usar $label (nota /$bassName en el bajo) y actualizar los siguientes acordes.'
      : 'Lock $label (/$bassName) for this chord and update downstream voice leading.';

  String get totalTravelLabel => isEs ? 'Distancia' : 'Total Travel';
  String get commonTonesLabel => isEs ? 'Notas Comunes' : 'Common Tones';
  String get stepwiseLabel => isEs ? 'Por Grados' : 'Stepwise';
  String get initialChordLabel => isEs ? 'Acorde Inicial' : 'Initial Chord';
  String semitonesCount(int n) => isEs ? '$n semitonos' : '$n semitones';

  String basicConnectionSummary({
    required bool isFirst,
    required int commonTones,
    required int totalDistance,
    required String bassNote,
  }) {
    if (isFirst) {
      return isEs
          ? 'Acorde inicial con $bassNote en el bajo. Toca una inversión abajo para cambiar la nota más grave.'
          : 'Starting chord with $bassNote in the bass. Pick an inversion below to change the lowest note.';
    }
    if (commonTones > 0) {
      return isEs
          ? '$commonTones nota(s) se mantienen iguales desde el acorde anterior; las demás se mueven $totalDistance semitonos en total.'
          : '$commonTones note(s) stay in place from the previous chord; the remaining notes move $totalDistance semitones total.';
    }
    return isEs
        ? 'Las voces avanzan $totalDistance semitonos en total desde el acorde anterior (bajo actual: $bassNote).'
        : 'Notes shift $totalDistance semitones total from the previous chord (current bass: $bassNote).';
  }

  String bassNoteBadge(String bassName) =>
      isEs ? 'Bajo: $bassName' : 'Bass: $bassName';

  String basicInversionMetrics(int common, int dist, {required bool isFirst}) {
    if (isFirst) {
      return isEs ? 'Inicio limpio' : 'Clean start';
    }
    return isEs ? '$common igual · $dist st' : '$common keep · $dist st';
  }

  // --- Modal Interchange Panel ---

  String get modalInterchangeTitle =>
      isEs ? 'INTERCAMBIO MODAL' : 'MODAL INTERCHANGE EXPLORER';
  String get modalInterchangeBasicTitle =>
      isEs ? 'IDEAS DE ACORDES PRESTADOS' : 'BORROWED CHORD IDEAS';
  String get allParallelModesLabel =>
      isEs ? 'Todos los Modos' : 'All Parallel Modes';
  String get noBorrowedMatches => isEs
      ? 'No hay sustituciones que coincidan con este filtro.'
      : 'No borrowed substitutions match this filter.';
  String get substituteLabel => isEs ? 'Sustituir' : 'Substitute';
  String get trySwapLabel => isEs ? 'Probar' : 'Try Swap';

  String get basicModalGuide => isEs
      ? 'Cambia el acorde actual por una de estas 3 opciones suaves tomadas de escalas paralelas:'
      : 'Swap the current chord with one of these top 3 smooth chords borrowed from parallel scales:';

  String get advancedModalGuide => isEs
      ? 'Explora acordes prestados de escalas paralelas con la misma tónica para añadir color armónico:'
      : 'Explore chords borrowed from parallel scales sharing the same tonic to add harmonic color:';

  String get allModesTip => isEs
      ? 'Mostrar acordes prestados de todos los modos paralelos.'
      : 'Show borrowed chord substitutions across all parallel modes.';

  String modeFilterTip(ScaleMode m) => isEs
      ? 'Filtrar acordes prestados del modo ${m.shortLabel}.'
      : 'Filter borrowed chords to those originating in ${m.label} (${m.characteristicNoteDescription}).';

  String vlTravelSummary(int dist, int shared) => isEs
      ? 'Movimiento: $dist st · $shared notas en común'
      : 'VL travel: $dist st · $shared shared tones';

  String borrowedFromLabel(ScaleMode mode) =>
      isEs ? 'De ${mode.shortLabel}' : 'From ${mode.shortLabel}';

  String substituteTip(String symbol, String roman, ScaleMode mode) => isEs
      ? 'Reemplazar el acorde seleccionado por $symbol ($roman) tomado de ${mode.shortLabel}.'
      : 'Replace the selected progression chord with $symbol ($roman) borrowed from ${mode.shortLabel}.';

  // --- Visualizers ---

  String get pianoModeLabel => isEs ? 'Modo Piano' : 'Piano Mode';
  String get guitarModeLabel => isEs ? 'Modo Guitarra' : 'Guitar Mode';

  String get pianoModeTip => isEs
      ? 'Cambiar la vista inferior al teclado interactivo de 2 octavas.'
      : 'Switch lower workspace to the 2-octave interactive MIDI piano keyboard visualizer.';
  String get guitarModeTip => isEs
      ? 'Cambiar la vista inferior al diapasón de guitarra con filtro de cuerdas.'
      : 'Switch lower workspace to the configurable guitar fretboard matrix with string-mask toggles.';

  String get bassRootLegend => isEs ? 'Bajo / Raíz' : 'Bass / Root';
  String get upperTonesLegend => isEs ? 'Voces Sup.' : 'Upper Tones';
  String get commonToneLegend => isEs ? 'Nota Común' : 'Common Tone';

  String get pianoRangeLabel => isEs ? 'Rango' : 'Range';
  String get pianoTapHint => isEs
      ? 'Toca cualquier nota del acorde para ponerla en el bajo'
      : 'Click any chord tone key to set inversion bass';
  String get octaveDownTip => isEs
      ? 'Bajar una octava el rango visible del teclado.'
      : 'Shift visible 2-octave keyboard range down by 1 octave.';
  String get octaveUpTip => isEs
      ? 'Subir una octava el rango visible del teclado.'
      : 'Shift visible 2-octave keyboard range up by 1 octave.';

  String get guitarTuningLabel => isEs ? 'AFINACIÓN:' : 'TUNING:';
  String get guitarMaskLabel =>
      isEs ? 'FILTRO DE CUERDAS:' : 'STRING MASK:';
  String get guitarMaskBasicLabel => isEs ? 'CUERDAS:' : 'STRINGS:';
  String get guitarTuningTip => isEs
      ? 'Elegir una afinación estándar o alternativa para la guitarra.'
      : 'Choose a standard or alternate open-string MIDI guitar tuning.';

  String maskPresetLabel(String rawLabel) {
    if (!isEs) {
      return rawLabel;
    }
    if (rawLabel.startsWith('All 6')) {
      return 'Las 6 Cuerdas';
    }
    if (rawLabel.startsWith('Top 4')) {
      return '4 Agudas (D-G-B-E)';
    }
    if (rawLabel.startsWith('Mid 4')) {
      return '4 Medias (A-D-G-B)';
    }
    if (rawLabel.startsWith('Low 4')) {
      return '4 Graves (E-A-D-G)';
    }
    return rawLabel;
  }

  String maskPresetTip(String localizedLabel) => isEs
      ? 'Limitar el cálculo y diagrama del acorde al grupo: $localizedLabel.'
      : 'Filter chord voicings to use only the $localizedLabel string group.';

  String stringToggleTip(int stringNumber, bool enabled) => isEs
      ? 'Activar o silenciar la Cuerda $stringNumber (${enabled ? "Activa" : "Silenciada"}). Las cuerdas silenciadas se excluyen del cálculo.'
      : 'Toggle String $stringNumber (${enabled ? "Active" : "Muted"}). Muted strings are excluded from chord voicing calculations.';

  String tuneDownTip(int stringNumber, int openMidi) => isEs
      ? 'Bajar la Cuerda $stringNumber 1 semitono (MIDI actual: $openMidi).'
      : 'Tune String $stringNumber down by 1 semitone (current MIDI: $openMidi).';

  String tuneUpTip(int stringNumber, int openMidi) => isEs
      ? 'Subir la Cuerda $stringNumber 1 semitono (MIDI actual: $openMidi).'
      : 'Tune String $stringNumber up by 1 semitone (current MIDI: $openMidi).';

  String fretWindowLabel(int startFret, int endFret) =>
      isEs ? 'Trastes $startFret–$endFret' : 'Frets $startFret–$endFret';
  String get fretLeftTip => isEs
      ? 'Mover la vista del diapasón hacia los trastes más bajos.'
      : 'Shift visible fretboard window toward lower frets.';
  String get fretRightTip => isEs
      ? 'Mover la vista del diapasón hacia los trastes más altos.'
      : 'Shift visible fretboard window toward higher frets.';
  String get fineTuneToggleLabel => isEs ? 'Afinar ±1' : 'Fine Tune ±1';
  String get fineTuneToggleTip => isEs
      ? 'Mostrar u ocultar los botones +/- para afinar cada cuerda por semitonos.'
      : 'Show or hide per-string +/- semitone tuning steppers.';

  // --- Narrow Tabs ---

  String get voiceLeadingTabTip => isEs
      ? 'Ver inversiones y movimiento de notas para el acorde seleccionado.'
      : 'Inspect inversions and voice-by-voice MIDI semitone motion for the selected chord.';
  String get modalInterchangeTabTip => isEs
      ? 'Explorar acordes prestados de modos paralelos y sustituir el acorde actual.'
      : 'Compare parallel modes and substitute borrowed chords into the selected slot.';

  // --- Secret Improvisation Oracle ---

  String get secretImprovTab => isEs ? '✦ Oráculo Improv' : '✦ Improv Oracle';
  String get secretImprovTabTip => isEs
      ? 'Ver escalas de improvisación recomendadas y su experiencia estética.'
      : 'Inspect recommended improvisation scales and their aesthetic experience.';
  String get secretImprovTitle => isEs
      ? 'ORÁCULO SECRETO · ESCALAS Y EXPERIENCIA ESTÉTICA'
      : 'SECRET ORACLE · IMPROVISATION SCALES & AESTHETIC VIBE';
  String get secretImprovSubtitle => isEs
      ? 'Desbloqueado por seguir rockeando el mundo y guardar tu propio preset.'
      : 'Unlocked by keeping on rocking the world and saving your own preset.';
  String get overarchingScalesHeader =>
      isEs ? 'ESCALAS PARA LA PROGRESIÓN' : 'OVERARCHING PROGRESSION SCALES';
  String selectedChordScaleHeader(String chordSymbol) => isEs
      ? 'MATIZ PARA EL ACORDE ACTUAL ($chordSymbol)'
      : 'SELECTED CHORD INFLECTION ($chordSymbol)';
  String secretUnlockedBanner(String presetName) => isEs
      ? '¡Secreto desbloqueado al guardar "$presetName"! Se abrió el Oráculo de Improvisación.'
      : 'Secret unlocked by saving "$presetName"! Improvisation Oracle revealed.';

  // --- Startup Onboarding (Credits & Workspace Setup) ---

  String get creditsCreatedBy => isEs
      ? 'Creado por SniffingWizard y OMGitstheCow en colaboración con la IA'
      : 'Created by SniffingWizard and OMGitstheCow in collab with the AI';

  String get creditsDismissButton => isEs ? 'No me importa' : "I don't care";

  String get creditsKeepRocking =>
      isEs ? 'Sigue rockeando el mundo' : 'Keep rocking the world';

  String get setupTitle => isEs
      ? 'Configura tu espacio de trabajo'
      : 'Choose your workspace setup';

  String get setupSubtitle => isEs
      ? 'Elige tu nivel de experiencia y el modo de instrumento'
      : 'Pick your experience level and instrument mode';

  String get setupLevelHeading =>
      isEs ? 'Nivel de experiencia' : 'Experience level';

  String get setupBasicSubtitle => isEs
      ? 'Guiado · Sin números MIDI'
      : 'Guided · No raw MIDI numbers';

  String get setupAdvancedSubtitle => isEs
      ? 'MIDI completo y motor de 7 modos'
      : 'Full MIDI & 7-mode engine';

  String get setupInstrumentHeading =>
      isEs ? 'Modo de instrumento' : 'Instrument mode';

  String get setupPianoTitle => 'Piano';

  String get setupPianoSubtitle => isEs
      ? 'Teclado interactivo y enlace de voces'
      : 'Interactive keyboard & voice leading';

  String get setupGuitarTitle => isEs ? 'Guitarra' : 'Guitar';

  String get setupGuitarSubtitle => isEs
      ? 'Diapasón, voicings y afinaciones'
      : 'Fretboard voicings & custom tunings';

  String get setupContinueButton => isEs ? 'Comenzar' : 'Start Exploring';

  String get setupFooterHint => isEs
      ? 'Puedes cambiar Básico/Avanzado, Piano/Guitarra y EN/ES en cualquier momento en la barra superior.'
      : 'You can switch Basic/Advanced, Piano/Guitar, and EN/ES anytime in the workspace.';
}
