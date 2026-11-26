import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/audio/chord_audio_player.dart';
import '../core/audio/chord_synthesizer.dart';
import '../core/engine/guitar_voicing_solver.dart';
import '../core/engine/harmonic_analyzer.dart';
import '../core/engine/improvisation_scale_engine.dart';
import '../core/engine/modal_interchange.dart';
import '../core/engine/voice_leading_engine.dart';
import '../core/localization/app_strings.dart';
import '../core/models/chord_spec.dart';
import '../core/models/chord_voicing.dart';
import '../core/models/harmonic_function.dart';
import '../core/models/interval_profile.dart';
import '../core/models/midi_pitch.dart';
import '../core/models/scale_mode.dart';
import '../core/storage/preset_storage.dart';

enum VisualizerMode {
  piano,
  guitar,
}

/// Central reactive state controller driving harmonic analysis, MIDI voice
/// leading, modal interchange suggestions, and piano/guitar visualizers.
class ExplorerController extends ChangeNotifier {
  ExplorerController({
    bool loadPersistedPresets = true,
    bool enableAudio = true,
  })  : _enableAudio = enableAudio,
        _audioPlayer = enableAudio ? ChordAudioPlayer() : null {
    _progression = _buildPreset('Dream-Pop Nocturne');
    _activePresetName = 'Dream-Pop Nocturne';
    _recompute();
    if (loadPersistedPresets) {
      _initUserPresets();
    }
  }

  static const List<String> presetNames = <String>[
    'Dream-Pop Nocturne',
    'Pop Anthem + Minor iv',
    '50s / Soul Turnaround',
    'Andalusian Cadence',
    'Royal Road (J-Pop)',
    'Marusa (Just the Two of Us)',
    'Bossa Nova Turnaround',
    'ii-V-I + Sec Dom',
    'Modal Interchange',
    'Diminished Passing',
    'Neo-Soul Extended',
  ];

  static const Set<int> _flatKeyTonics = <int>{1, 3, 5, 6, 8, 10};

  List<ChordSpec> _progression = <ChordSpec>[];
  int _selectedChordIndex = 0;

  final Map<String, List<ChordSpec>> _userPresets = <String, List<ChordSpec>>{};
  String? _activePresetName;

  bool _isKeyLocked = false;
  int _lockedKeyTonicPc = 0;
  ScaleMode _lockedKeyMode = ScaleMode.ionian;
  KeySignatureResult _detectedKey = const KeySignatureResult(
    tonicPc: 0,
    mode: ScaleMode.ionian,
    confidenceScore: 1.0,
  );

  List<HarmonicAnalysisResult> _analyses = <HarmonicAnalysisResult>[];
  List<ChordVoicing> _pianoVoicings = <ChordVoicing>[];
  List<ChordVoicing> _candidateInversionsForSelected = <ChordVoicing>[];
  List<ChordVoicing> _allRankedForSelected = <ChordVoicing>[];
  List<BorrowedChordSuggestion> _modalSuggestionsForSelected =
      <BorrowedChordSuggestion>[];
  ScaleMode? _modalFilterMode;
  ImprovisationInsightResult? _improvInsight;

  VisualizerMode _visualizerMode = VisualizerMode.piano;
  List<int> _guitarTuningMidi =
      List<int>.from(GuitarTuningPreset.standard.openStringMidi);
  List<bool> _guitarStringMask =
      List<bool>.from(GuitarStringMaskPreset.allSix.mask);
  List<GuitarVoicing> _guitarVoicings = <GuitarVoicing>[];

  final bool _enableAudio;
  final ChordAudioPlayer? _audioPlayer;
  bool _soundEnabled = true;
  bool _isPlayingProgression = false;
  Timer? _progressionTimer;

  String _activeHelpMessage =
      'Hover over (desktop) or long-press (Android) any button or control to see what it does.';

  AppLanguage _language = AppLanguage.en;
  bool _hasDismissedCredits = false;
  bool _secretRockPrimed = false;
  bool _secretImprovRevealed = false;
  bool _hasSelectedLanguage = false;
  bool _hasCompletedSetup = false;
  ComplexityMode _complexityMode = ComplexityMode.basic;

  // --- Read-only Getters ---

  bool get soundEnabled => _soundEnabled;
  bool get isPlayingProgression => _isPlayingProgression;
  AppLanguage get language => _language;
  bool get hasDismissedCredits => _hasDismissedCredits;
  bool get isSecretRockPrimed => _secretRockPrimed;
  bool get isSecretImprovRevealed => _secretImprovRevealed;
  ImprovisationInsightResult? get improvInsight => _improvInsight;
  bool get hasSelectedLanguage => _hasSelectedLanguage;
  bool get hasCompletedSetup => _hasCompletedSetup;

  @override
  void dispose() {
    _progressionTimer?.cancel();
    _progressionTimer = null;
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _stopAudio() {
    final ChordAudioPlayer? audioPlayer = _audioPlayer;
    if (!_enableAudio || audioPlayer == null) {
      return;
    }
    unawaited(audioPlayer.stop());
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    if (!_soundEnabled) {
      stopProgressionPlayback();
      _stopAudio();
    }
    _activeHelpMessage = strings.soundToggleFeedback(_soundEnabled);
    notifyListeners();
  }

  void playSelectedChord({bool force = false}) {
    final ChordAudioPlayer? audioPlayer = _audioPlayer;
    if (!_enableAudio || audioPlayer == null || (!_soundEnabled && !force)) {
      return;
    }
    final bool isGuitar = _visualizerMode == VisualizerMode.guitar;
    final List<int> notes = isGuitar
        ? (selectedGuitarVoicing?.activeMidiPitches.isNotEmpty == true
            ? selectedGuitarVoicing!.activeMidiPitches
            : (selectedPianoVoicing?.midiNotes ?? const <int>[]))
        : (selectedPianoVoicing?.midiNotes ?? const <int>[]);
    if (notes.isEmpty) {
      return;
    }
    unawaited(
      audioPlayer.playChord(
        midiNotes: notes,
        instrument:
            isGuitar ? SynthInstrument.guitar : SynthInstrument.piano,
      ),
    );
  }

  void stopProgressionPlayback() {
    _progressionTimer?.cancel();
    _progressionTimer = null;
    if (_isPlayingProgression) {
      _isPlayingProgression = false;
      notifyListeners();
    }
  }

  void togglePlayProgression() {
    if (_isPlayingProgression) {
      stopProgressionPlayback();
      _stopAudio();
      return;
    }
    if (_progression.isEmpty) {
      return;
    }
    if (!_soundEnabled) {
      _soundEnabled = true;
    }
    _isPlayingProgression = true;
    _selectedChordIndex = 0;
    _recomputeSelectionDetails();
    notifyListeners();
    playSelectedChord(force: true);

    _progressionTimer = Timer.periodic(
      const Duration(milliseconds: 950),
      (Timer timer) {
        if (!_isPlayingProgression ||
            _selectedChordIndex + 1 >= _progression.length) {
          stopProgressionPlayback();
          return;
        }
        _selectedChordIndex += 1;
        _recomputeSelectionDetails();
        notifyListeners();
        playSelectedChord(force: true);
      },
    );
  }

  void dismissCredits({bool secretRockTap = false}) {
    if (secretRockTap) {
      _secretRockPrimed = true;
    }
    if (_hasDismissedCredits) {
      return;
    }
    _hasDismissedCredits = true;
    notifyListeners();
  }

  ComplexityMode get complexityMode => _complexityMode;
  bool get isBasicMode => _complexityMode == ComplexityMode.basic;
  AppStrings get strings => AppStrings(_language);

  String get activeHelpMessage => _activeHelpMessage;

  void setHelpMessage(String message) {
    if (_activeHelpMessage == message) {
      return;
    }
    _activeHelpMessage = message;
    notifyListeners();
  }

  void selectLanguage(
    AppLanguage lang, {
    ComplexityMode? initialMode,
  }) {
    _language = lang;
    if (initialMode != null) {
      _complexityMode = initialMode;
      if (_complexityMode == ComplexityMode.basic) {
        _normalizeBasicState();
      }
    }
    _hasSelectedLanguage = true;
    _activeHelpMessage = AppStrings(lang).defaultHelpPrompt;
    _recompute();
    notifyListeners();
  }

  void completeInitialSetup({
    required ComplexityMode complexityMode,
    required VisualizerMode visualizerMode,
  }) {
    _complexityMode = complexityMode;
    _visualizerMode = visualizerMode;
    if (_complexityMode == ComplexityMode.basic) {
      _normalizeBasicState();
    }
    _hasCompletedSetup = true;
    _activeHelpMessage = strings.defaultHelpPrompt;
    _recompute();
    notifyListeners();
  }

  void toggleLanguage() {
    _language =
        _language == AppLanguage.en ? AppLanguage.es : AppLanguage.en;
    _activeHelpMessage = AppStrings(_language).defaultHelpPrompt;
    _recomputeSelectionDetails();
    notifyListeners();
  }

  void setComplexityMode(ComplexityMode mode) {
    if (_complexityMode == mode) {
      return;
    }
    _complexityMode = mode;
    if (mode == ComplexityMode.basic) {
      _normalizeBasicState();
      _activeHelpMessage = strings.switchToBasicTip;
    } else {
      _activeHelpMessage = strings.switchToAdvancedTip;
    }
    _recompute();
    notifyListeners();
  }

  void toggleComplexityMode() {
    setComplexityMode(
      isBasicMode ? ComplexityMode.advanced : ComplexityMode.basic,
    );
  }

  void _normalizeBasicState() {
    if (_isKeyLocked &&
        _lockedKeyMode != ScaleMode.ionian &&
        _lockedKeyMode != ScaleMode.aeolian) {
      _lockedKeyMode =
          _lockedKeyMode.isMinorFamily ? ScaleMode.aeolian : ScaleMode.ionian;
    }
    _modalFilterMode = null;
  }

  List<ChordSpec> get progression => List<ChordSpec>.unmodifiable(_progression);
  int get selectedChordIndex => _selectedChordIndex;

  ChordSpec? get selectedChord =>
      (_selectedChordIndex >= 0 && _selectedChordIndex < _progression.length)
          ? _progression[_selectedChordIndex]
          : null;

  bool get isKeyLocked => _isKeyLocked;
  int get lockedKeyTonicPc => _lockedKeyTonicPc;
  ScaleMode get lockedKeyMode => _lockedKeyMode;
  KeySignatureResult get detectedKey => _detectedKey;

  int get activeKeyTonicPc =>
      _isKeyLocked ? _lockedKeyTonicPc : _detectedKey.tonicPc;
  ScaleMode get activeKeyMode =>
      _isKeyLocked ? _lockedKeyMode : _detectedKey.mode;

  bool get preferFlats =>
      _flatKeyTonics.contains(activeKeyTonicPc) ||
      activeKeyMode == ScaleMode.aeolian ||
      activeKeyMode == ScaleMode.dorian ||
      activeKeyMode == ScaleMode.phrygian ||
      activeKeyMode == ScaleMode.locrian;

  List<HarmonicAnalysisResult> get analyses =>
      List<HarmonicAnalysisResult>.unmodifiable(_analyses);
  List<ChordVoicing> get pianoVoicings =>
      List<ChordVoicing>.unmodifiable(_pianoVoicings);
  List<ChordVoicing> get candidateInversionsForSelected =>
      List<ChordVoicing>.unmodifiable(_candidateInversionsForSelected);
  List<ChordVoicing> get allRankedForSelected =>
      List<ChordVoicing>.unmodifiable(_allRankedForSelected);

  ChordVoicing? get selectedPianoVoicing =>
      (_selectedChordIndex >= 0 && _selectedChordIndex < _pianoVoicings.length)
          ? _pianoVoicings[_selectedChordIndex]
          : null;

  ChordVoicing? get previousPianoVoicing =>
      (_selectedChordIndex > 0 && _selectedChordIndex - 1 < _pianoVoicings.length)
          ? _pianoVoicings[_selectedChordIndex - 1]
          : null;

  HarmonicAnalysisResult? get selectedAnalysis =>
      (_selectedChordIndex >= 0 && _selectedChordIndex < _analyses.length)
          ? _analyses[_selectedChordIndex]
          : null;

  List<BorrowedChordSuggestion> get modalSuggestionsForSelected {
    if (_modalFilterMode == null) {
      return List<BorrowedChordSuggestion>.unmodifiable(
        _modalSuggestionsForSelected,
      );
    }
    return List<BorrowedChordSuggestion>.unmodifiable(
      _modalSuggestionsForSelected.where(
        (BorrowedChordSuggestion s) =>
            s.allSourceModes.contains(_modalFilterMode),
      ),
    );
  }

  List<BorrowedChordSuggestion> get allModalSuggestionsForSelected =>
      List<BorrowedChordSuggestion>.unmodifiable(_modalSuggestionsForSelected);

  ScaleMode? get modalFilterMode => _modalFilterMode;

  VisualizerMode get visualizerMode => _visualizerMode;
  List<int> get guitarTuningMidi => List<int>.unmodifiable(_guitarTuningMidi);
  List<bool> get guitarStringMask => List<bool>.unmodifiable(_guitarStringMask);
  List<GuitarVoicing> get guitarVoicings =>
      List<GuitarVoicing>.unmodifiable(_guitarVoicings);

  GuitarVoicing? get selectedGuitarVoicing =>
      (_selectedChordIndex >= 0 && _selectedChordIndex < _guitarVoicings.length)
          ? _guitarVoicings[_selectedChordIndex]
          : null;

  int get totalProgressionSemitoneCost => _pianoVoicings.fold<int>(
        0,
        (int sum, ChordVoicing v) => sum + v.totalSemitoneDistance,
      );

  List<String> get userPresetNames =>
      List<String>.unmodifiable(_userPresets.keys);

  List<String> get allPresetNames => <String>[
        ..._userPresets.keys,
        ...presetNames.where((String p) => !_userPresets.containsKey(p)),
      ];

  String? get activePresetName => _activePresetName;

  bool isUserPreset(String name) => _userPresets.containsKey(name);

  Future<void> _initUserPresets() async {
    final Map<String, List<ChordSpec>> loaded =
        await PresetStorage.loadUserPresets();
    if (loaded.isEmpty) {
      return;
    }
    _userPresets
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  // --- Progression Mutations ---

  void selectChord(int index) {
    if (index < 0 || index >= _progression.length) {
      return;
    }
    stopProgressionPlayback();
    if (_selectedChordIndex == index) {
      playSelectedChord();
      return;
    }
    _selectedChordIndex = index;
    _recomputeSelectionDetails();
    notifyListeners();
    playSelectedChord();
  }

  void addChord(ChordSpec chord) {
    stopProgressionPlayback();
    _progression.add(chord);
    _activePresetName = null;
    _selectedChordIndex = _progression.length - 1;
    _recompute();
    notifyListeners();
    playSelectedChord();
  }

  void updateChordAt(int index, ChordSpec updated) {
    if (index < 0 || index >= _progression.length) {
      return;
    }
    stopProgressionPlayback();
    _progression[index] = updated;
    _activePresetName = null;
    _selectedChordIndex = index;
    _recompute();
    notifyListeners();
    playSelectedChord();
  }

  void removeChordAt(int index) {
    if (_progression.length <= 1 || index < 0 || index >= _progression.length) {
      return;
    }
    _progression.removeAt(index);
    _activePresetName = null;
    if (_selectedChordIndex >= _progression.length) {
      _selectedChordIndex = _progression.length - 1;
    }
    _recompute();
    notifyListeners();
  }

  void reorderChord(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _progression.length ||
        newIndex < 0 ||
        newIndex >= _progression.length ||
        oldIndex == newIndex) {
      return;
    }
    final ChordSpec item = _progression.removeAt(oldIndex);
    _progression.insert(newIndex, item);
    _activePresetName = null;
    _selectedChordIndex = newIndex;
    _recompute();
    notifyListeners();
  }

  void loadPresetProgression(String presetName) {
    final List<ChordSpec>? custom = _userPresets[presetName];
    if (custom != null) {
      _progression = custom.map((ChordSpec c) => c.copyWith()).toList();
    } else {
      _progression = _buildPreset(presetName);
    }
    _activePresetName = presetName;
    _selectedChordIndex = 0;
    _isKeyLocked = false;
    _recompute();
    notifyListeners();
  }

  /// Saves the active progression as a named custom preset and persists it.
  Future<void> saveUserPreset(String name, {bool persist = true}) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || _progression.isEmpty) {
      return;
    }
    _userPresets[trimmed] =
        _progression.map((ChordSpec c) => c.copyWith()).toList();
    _activePresetName = trimmed;
    if (_secretRockPrimed && !_secretImprovRevealed) {
      _secretImprovRevealed = true;
      _recomputeSelectionDetails();
      _activeHelpMessage = strings.secretUnlockedBanner(trimmed);
    } else {
      _activeHelpMessage = strings.presetSavedFeedback(trimmed);
    }
    notifyListeners();
    if (persist) {
      await PresetStorage.saveUserPresets(_userPresets);
    }
  }

  /// Deletes a saved custom preset by [name] and updates persisted storage.
  Future<void> deleteUserPreset(String name, {bool persist = true}) async {
    if (!_userPresets.containsKey(name)) {
      return;
    }
    _userPresets.remove(name);
    if (_activePresetName == name) {
      _activePresetName = null;
    }
    _activeHelpMessage = strings.presetDeletedFeedback(name);
    notifyListeners();
    if (persist) {
      await PresetStorage.saveUserPresets(_userPresets);
    }
  }

  // --- Inversion & Voice Leading Overrides ---

  void setManualInversion(int chordIndex, int? inversionIndex) {
    if (chordIndex < 0 || chordIndex >= _progression.length) {
      return;
    }
    final ChordSpec current = _progression[chordIndex];
    _progression[chordIndex] = inversionIndex == null
        ? current.copyWith(clearManualInversion: true, voicingVariantIndex: 0)
        : current.copyWith(
            manualInversion:
                ((inversionIndex % current.inversionCount) +
                        current.inversionCount) %
                    current.inversionCount,
            voicingVariantIndex: 0,
          );
    _recompute();
    notifyListeners();
    if (chordIndex == _selectedChordIndex) {
      playSelectedChord();
    }
  }

  void stepInversion(int chordIndex, int delta) {
    if (chordIndex < 0 ||
        chordIndex >= _progression.length ||
        chordIndex >= _pianoVoicings.length) {
      return;
    }
    final ChordSpec current = _progression[chordIndex];
    final int currentInv =
        current.manualInversion ?? _pianoVoicings[chordIndex].inversionIndex;
    final int count = current.inversionCount.clamp(1, 12);
    final int nextInv = ((currentInv + delta) % count + count) % count;
    setManualInversion(chordIndex, nextInv);
  }

  void cycleVoicingVariant(int chordIndex) {
    if (chordIndex < 0 || chordIndex >= _progression.length) {
      return;
    }
    final ChordSpec current = _progression[chordIndex];
    final int totalAvailable = _allRankedForSelected.isEmpty
        ? 1
        : _allRankedForSelected.length.clamp(1, 8);
    final int nextVariant = (current.voicingVariantIndex + 1) % totalAvailable;
    _progression[chordIndex] = current.copyWith(voicingVariantIndex: nextVariant);
    _recompute();
    notifyListeners();
    if (chordIndex == _selectedChordIndex) {
      playSelectedChord();
    }
  }

  void resetAllInversionsToOptimal() {
    for (int i = 0; i < _progression.length; i++) {
      _progression[i] = _progression[i].copyWith(
        clearManualInversion: true,
        voicingVariantIndex: 0,
      );
    }
    _recompute();
    notifyListeners();
  }

  // --- Key Center & Modal Interchange Controls ---

  void toggleKeyLock() {
    if (!_isKeyLocked) {
      _lockedKeyTonicPc = _detectedKey.tonicPc;
      _lockedKeyMode = _detectedKey.mode;
      _isKeyLocked = true;
    } else {
      _isKeyLocked = false;
    }
    _recompute();
    notifyListeners();
  }

  void setLockedKey(int tonicPc, ScaleMode mode) {
    final int oldTonic = activeKeyTonicPc;
    final ScaleMode oldMode = activeKeyMode;
    final int newTonic = MidiPitch.pitchClass(tonicPc);

    if (newTonic != oldTonic || mode != oldMode) {
      _progression = _transposeAndAdaptProgression(
        progression: _progression,
        oldTonicPc: oldTonic,
        oldMode: oldMode,
        newTonicPc: newTonic,
        newMode: mode,
      );
    }

    _lockedKeyTonicPc = newTonic;
    _lockedKeyMode = mode;
    _isKeyLocked = true;
    _recompute();
    notifyListeners();
  }

  List<ChordSpec> _transposeAndAdaptProgression({
    required List<ChordSpec> progression,
    required int oldTonicPc,
    required ScaleMode oldMode,
    required int newTonicPc,
    required ScaleMode newMode,
  }) {
    final int deltaSemitones = (newTonicPc - oldTonicPc + 12) % 12;

    // Pure transposition when the scale/mode is unchanged.
    if (oldMode == newMode) {
      return progression
          .map(
            (ChordSpec chord) => chord.copyWith(
              rootPc: (chord.normalizedRootPc + deltaSemitones) % 12,
            ),
          )
          .toList();
    }

    final List<int> oldIntervals = oldMode.semitoneIntervals;
    final List<int> newIntervals = newMode.semitoneIntervals;

    return progression.map((ChordSpec chord) {
      final int rel = (chord.normalizedRootPc - oldTonicPc + 12) % 12;
      final int deg = oldIntervals.indexOf(rel);

      if (deg >= 0) {
        final int oldRootOff = oldIntervals[deg];
        final int oldThird =
            (oldIntervals[(deg + 2) % 7] - oldRootOff + 12) % 12;
        final int oldFifth =
            (oldIntervals[(deg + 4) % 7] - oldRootOff + 12) % 12;
        final int oldSev =
            (oldIntervals[(deg + 6) % 7] - oldRootOff + 12) % 12;

        final TriadQuality oldDiatonicTriad =
            _diatonicTriadForIntervals(oldThird, oldFifth);
        final SeventhQuality oldDiatonicSeventh =
            _diatonicSeventhForIntervals(oldDiatonicTriad, oldSev);

        final bool isSus = chord.triad == TriadQuality.sus2 ||
            chord.triad == TriadQuality.sus4;
        final bool triadMatches = chord.triad == oldDiatonicTriad ||
            (isSus && oldDiatonicTriad != TriadQuality.diminished);
        final bool seventhMatches = chord.seventh == SeventhQuality.none ||
            chord.seventh == oldDiatonicSeventh;

        if (triadMatches && seventhMatches && chord.alterations.isEmpty) {
          final int newRootOff = newIntervals[deg];
          final int newRootPc = (newTonicPc + newRootOff) % 12;
          final int newThird =
              (newIntervals[(deg + 2) % 7] - newRootOff + 12) % 12;
          final int newFifth =
              (newIntervals[(deg + 4) % 7] - newRootOff + 12) % 12;
          final int newSev =
              (newIntervals[(deg + 6) % 7] - newRootOff + 12) % 12;

          final TriadQuality newDiatonicTriad =
              _diatonicTriadForIntervals(newThird, newFifth);
          final SeventhQuality newDiatonicSeventh =
              _diatonicSeventhForIntervals(newDiatonicTriad, newSev);

          final TriadQuality updatedTriad =
              (isSus && newDiatonicTriad != TriadQuality.diminished)
                  ? chord.triad
                  : newDiatonicTriad;
          final SeventhQuality updatedSeventh =
              chord.seventh == SeventhQuality.none
                  ? SeventhQuality.none
                  : newDiatonicSeventh;

          final Set<ChordExtension> updatedExtensions =
              updatedTriad == TriadQuality.diminished
                  ? chord.extensions
                      .where(
                        (ChordExtension e) =>
                            e != ChordExtension.ninth &&
                            e != ChordExtension.add9 &&
                            e != ChordExtension.thirteenth,
                      )
                      .toSet()
                  : chord.extensions;

          return chord.copyWith(
            rootPc: newRootPc,
            triad: updatedTriad,
            seventh: updatedSeventh,
            extensions: Set<ChordExtension>.unmodifiable(updatedExtensions),
          );
        }
      }

      // Secondary dominant targeting a scale degree of oldMode: keep it
      // targeting the corresponding degree in newMode.
      final bool isDomStructure = (chord.triad == TriadQuality.major ||
              chord.triad == TriadQuality.sus4) &&
          (chord.seventh == SeventhQuality.none ||
              chord.seventh == SeventhQuality.dominant7);
      if (isDomStructure) {
        final int targetRel = (rel + 5) % 12;
        final int targetDeg = oldIntervals.indexOf(targetRel);
        if (targetDeg > 0) {
          final int newTargetRootPc =
              (newTonicPc + newIntervals[targetDeg]) % 12;
          return chord.copyWith(
            rootPc: (newTargetRootPc + 7) % 12,
          );
        }
      }

      // Non-diatonic / borrowed / passing chords transpose relative to tonic.
      return chord.copyWith(
        rootPc: (chord.normalizedRootPc + deltaSemitones) % 12,
      );
    }).toList();
  }

  static TriadQuality _diatonicTriadForIntervals(int third, int fifth) {
    if (third == 4 && fifth == 7) {
      return TriadQuality.major;
    }
    if (third == 3 && fifth == 7) {
      return TriadQuality.minor;
    }
    if (third == 3 && fifth == 6) {
      return TriadQuality.diminished;
    }
    if (third == 4 && fifth == 8) {
      return TriadQuality.augmented;
    }
    return TriadQuality.major;
  }

  static SeventhQuality _diatonicSeventhForIntervals(
    TriadQuality triad,
    int seventhSemitones,
  ) {
    if (triad == TriadQuality.major) {
      return seventhSemitones == 11
          ? SeventhQuality.major7
          : SeventhQuality.dominant7;
    }
    if (triad == TriadQuality.minor) {
      return seventhSemitones == 11
          ? SeventhQuality.minorMajor7
          : SeventhQuality.minor7;
    }
    if (triad == TriadQuality.diminished) {
      return seventhSemitones == 9
          ? SeventhQuality.diminished7
          : SeventhQuality.halfDiminished7;
    }
    return SeventhQuality.dominant7;
  }

  void substituteWithBorrowedChord(BorrowedChordSuggestion suggestion) {
    if (_selectedChordIndex < 0 || _selectedChordIndex >= _progression.length) {
      return;
    }
    stopProgressionPlayback();
    final ChordSpec old = _progression[_selectedChordIndex];
    _progression[_selectedChordIndex] = suggestion.chord.copyWith(
      id: old.id,
      clearManualInversion: true,
      voicingVariantIndex: 0,
    );
    _recompute();
    notifyListeners();
    playSelectedChord();
  }

  void setModalFilter(ScaleMode? mode) {
    _modalFilterMode = mode;
    notifyListeners();
  }

  // --- Instrument Visualizer & Guitar Mask Controls ---

  void setVisualizerMode(VisualizerMode mode) {
    if (_visualizerMode == mode) {
      return;
    }
    _visualizerMode = mode;
    notifyListeners();
    playSelectedChord();
  }

  void toggleGuitarString(int stringIndex) {
    if (stringIndex < 0 || stringIndex >= _guitarStringMask.length) {
      return;
    }
    _guitarStringMask[stringIndex] = !_guitarStringMask[stringIndex];
    _recomputeGuitarVoicings();
    notifyListeners();
  }

  void applyGuitarStringMaskPreset(List<bool> mask) {
    if (mask.length != _guitarTuningMidi.length) {
      _guitarStringMask = List<bool>.generate(
        _guitarTuningMidi.length,
        (int i) => i < mask.length ? mask[i] : true,
      );
    } else {
      _guitarStringMask = List<bool>.from(mask);
    }
    _recomputeGuitarVoicings();
    notifyListeners();
  }

  void applyGuitarTuningPreset(List<int> tuningMidi) {
    _guitarTuningMidi = List<int>.from(tuningMidi);
    if (_guitarStringMask.length != _guitarTuningMidi.length) {
      _guitarStringMask =
          List<bool>.filled(_guitarTuningMidi.length, true);
    }
    _recomputeGuitarVoicings();
    notifyListeners();
  }

  void adjustGuitarStringTuning(int stringIndex, int deltaSemitones) {
    if (stringIndex < 0 || stringIndex >= _guitarTuningMidi.length) {
      return;
    }
    _guitarTuningMidi[stringIndex] = MidiPitch.clampMidi(
      _guitarTuningMidi[stringIndex] + deltaSemitones,
    );
    _recomputeGuitarVoicings();
    notifyListeners();
  }

  // --- Internal Recomputation ---

  void _recompute() {
    _detectedKey = HarmonicAnalyzer.detectKeyCenter(_progression);
    _analyses = HarmonicAnalyzer.analyzeProgression(
      progression: _progression,
      keyTonicPc: activeKeyTonicPc,
      keyMode: activeKeyMode,
    );
    _pianoVoicings = VoiceLeadingEngine.solveProgression(_progression);
    _recomputeGuitarVoicings();
    _recomputeSelectionDetails();
  }

  void _recomputeGuitarVoicings() {
    final List<int> activeInversions = _pianoVoicings
        .map((ChordVoicing v) => v.inversionIndex)
        .toList();
    _guitarVoicings = GuitarVoicingSolver.solveProgression(
      progression: _progression,
      openStringMidi: _guitarTuningMidi,
      stringMask: _guitarStringMask,
      targetInversions: activeInversions,
    );
  }

  void _recomputeSelectionDetails() {
    final ChordSpec? current = selectedChord;
    if (current == null) {
      _candidateInversionsForSelected = <ChordVoicing>[];
      _allRankedForSelected = <ChordVoicing>[];
      _modalSuggestionsForSelected = <BorrowedChordSuggestion>[];
      _improvInsight = ImprovisationScaleEngine.analyze(
        progression: _progression,
        analyses: _analyses,
        selectedChordIndex: _selectedChordIndex,
        keyTonicPc: activeKeyTonicPc,
        keyMode: activeKeyMode,
        preferFlat: preferFlats,
        isEs: _language == AppLanguage.es,
      );
      return;
    }

    final List<int>? prevMidi = previousPianoVoicing?.midiNotes;
    _candidateInversionsForSelected = VoiceLeadingEngine.bestVoicingPerInversion(
      current,
      previousMidi: prevMidi,
    );
    _allRankedForSelected = VoiceLeadingEngine.rankVoicingsForChord(
      current,
      previousMidi: prevMidi,
      forcedInversion: current.manualInversion,
    );

    _modalSuggestionsForSelected =
        ModalInterchangeExplorer.exploreBorrowedChords(
      keyTonicPc: activeKeyTonicPc,
      keyMode: activeKeyMode,
      selectedChord: current,
      previousMidi: prevMidi,
      preferFlat: preferFlats,
    );

    _improvInsight = ImprovisationScaleEngine.analyze(
      progression: _progression,
      analyses: _analyses,
      selectedChordIndex: _selectedChordIndex,
      keyTonicPc: activeKeyTonicPc,
      keyMode: activeKeyMode,
      preferFlat: preferFlats,
      isEs: _language == AppLanguage.es,
    );
  }

  List<ChordSpec> _buildPreset(String presetName) {
    switch (presetName) {
      case 'Pop Anthem + Minor iv':
        return <ChordSpec>[
          ChordSpec.major(0, id: 'pop_1'), // C (I)
          ChordSpec.major(7, id: 'pop_2'), // G (V)
          ChordSpec.minor(9, id: 'pop_3'), // Am (vi)
          ChordSpec.major(5, id: 'pop_4'), // F (IV)
          ChordSpec.minor(5, id: 'pop_5'), // Fm (iv borrowed from C Aeolian)
          ChordSpec.major(0, id: 'pop_6'), // C (I)
        ];
      case '50s / Soul Turnaround':
        return <ChordSpec>[
          ChordSpec.major(7, id: 'soul_1'), // G (I)
          ChordSpec.minor7(4, id: 'soul_2'), // Em7 (vi7)
          ChordSpec.minor7(9, id: 'soul_3'), // Am7 (ii7)
          ChordSpec.dominant7(2, id: 'soul_4'), // D7 (V7)
        ];
      case 'Andalusian Cadence':
        return <ChordSpec>[
          ChordSpec.minor(9, id: 'and_1'), // Am (i)
          ChordSpec.major(7, id: 'and_2'), // G (bVII)
          ChordSpec.major7(5, id: 'and_3'), // Fmaj7 (bVIΔ7)
          ChordSpec.dominant7(4, id: 'and_4'), // E7 (V7 Harmonic Minor)
        ];
      case 'Dream-Pop Nocturne':
        return <ChordSpec>[
          ChordSpec.major7(7, id: 'dpn_1'), // Gmaj7 (IVΔ7)
          ChordSpec.minor7(6, id: 'dpn_2'), // F#m7 (iii7)
          ChordSpec.minor7(4, id: 'dpn_3'), // Em7 (ii7)
          ChordSpec.major7(2, id: 'dpn_4'), // Dmaj7 (IΔ7)
        ];
      case 'Royal Road (J-Pop)':
        return <ChordSpec>[
          ChordSpec.major7(5, id: 'rr_1'), // Fmaj7 (IVΔ7)
          ChordSpec.dominant7(7, id: 'rr_2'), // G7 (V7)
          ChordSpec.minor7(4, id: 'rr_3'), // Em7 (iii7)
          ChordSpec.minor7(9, id: 'rr_4'), // Am7 (vi7)
          ChordSpec.minor7(2, id: 'rr_5'), // Dm7 (ii7)
          ChordSpec.dominant7(7, id: 'rr_6'), // G7 (V7)
          ChordSpec.major7(0, id: 'rr_7'), // Cmaj7 (IΔ7)
        ];
      case 'Marusa (Just the Two of Us)':
        return <ChordSpec>[
          ChordSpec.major7(5, id: 'mar_1'), // Fmaj7 (IVΔ7)
          ChordSpec.minor7(4, id: 'mar_2'), // Em7 (iii7)
          ChordSpec.minor7(9, id: 'mar_3'), // Am7 (vi7)
          ChordSpec.minor7(7, id: 'mar_4'), // Gm7 (v7)
          ChordSpec.dominant7(0, id: 'mar_5'), // C7 (I7 -> IV)
        ];
      case 'Bossa Nova Turnaround':
        return <ChordSpec>[
          ChordSpec.major7(5, id: 'bn_1'), // Fmaj7 (IΔ7)
          ChordSpec.dominant7(
            7,
            id: 'bn_2',
            extensions: const <ChordExtension>{ChordExtension.ninth},
          ), // G9 (V9/V / II9)
          ChordSpec.minor7(7, id: 'bn_3'), // Gm7 (ii7)
          ChordSpec.dominant7(
            0,
            id: 'bn_4',
            extensions: const <ChordExtension>{ChordExtension.thirteenth},
          ), // C13 (V13)
          ChordSpec.major7(
            5,
            id: 'bn_5',
            extensions: const <ChordExtension>{ChordExtension.ninth},
          ), // Fmaj9 (IΔ9)
        ];
      case 'Modal Interchange':
        return <ChordSpec>[
          ChordSpec.major7(0, id: 'mi_1'), // Cmaj7 (I)
          ChordSpec.major7(8, id: 'mi_2'), // Abmaj7 (bVI from Aeolian)
          ChordSpec.dominant7(10, id: 'mi_3'), // Bb7 (bVII7 from Mixolydian/Aeolian)
          ChordSpec.minor7(5, id: 'mi_4'), // Fm7 (iv7 from Aeolian)
          ChordSpec.dominant7(7, id: 'mi_5'), // G7 (V7)
          ChordSpec.major7(0, id: 'mi_6'), // Cmaj7 (I)
        ];
      case 'Diminished Passing':
        return <ChordSpec>[
          ChordSpec.major7(5, id: 'dp_1'), // Fmaj7 (I)
          ChordSpec.dim7(6, id: 'dp_2'), // F#dim7 (#i°7 / vii°7/ii)
          ChordSpec.minor7(7, id: 'dp_3'), // Gm7 (ii7)
          ChordSpec.dim7(8, id: 'dp_4'), // G#dim7 (#ii°7 / vii°7/iii)
          ChordSpec.minor7(9, id: 'dp_5'), // Am7 (iii7)
          ChordSpec.dominant7(2, id: 'dp_6'), // D7 (V7/V)
          ChordSpec.minor7(7, id: 'dp_7', extensions: const {ChordExtension.ninth}), // Gm9
          ChordSpec.dominant7(0, id: 'dp_8', extensions: const {ChordExtension.thirteenth}), // C13
        ];
      case 'Neo-Soul Extended':
        return <ChordSpec>[
          ChordSpec.minor7(0, id: 'ns_1', extensions: const {ChordExtension.ninth}), // Cm9
          ChordSpec.minor7(5, id: 'ns_2', extensions: const {ChordExtension.ninth}), // Fm9
          ChordSpec.dominant7(10, id: 'ns_3', extensions: const {ChordExtension.thirteenth}), // Bb13
          ChordSpec.major7(3, id: 'ns_4', extensions: const {ChordExtension.ninth}), // Ebmaj9
          ChordSpec.major7(8, id: 'ns_5'), // Abmaj7
          ChordSpec.halfDim7(2, id: 'ns_6'), // Dm7b5
          ChordSpec.dominant7(
            7,
            id: 'ns_7',
            alterations: const {ChordAlteration.flat9, ChordAlteration.flat13},
          ), // G7(b9,b13)
          ChordSpec.minor7(0, id: 'ns_8', extensions: const {ChordExtension.ninth}), // Cm9
        ];
      case 'ii-V-I + Sec Dom':
      default:
        return <ChordSpec>[
          ChordSpec.minor7(
            2,
            id: 'j_1',
            extensions: const <ChordExtension>{ChordExtension.ninth},
          ), // Dm9 (ii9)
          ChordSpec.dominant7(
            7,
            id: 'j_2',
            extensions: const <ChordExtension>{ChordExtension.thirteenth},
          ), // G13 (V13)
          ChordSpec.major7(
            0,
            id: 'j_3',
            extensions: const <ChordExtension>{ChordExtension.ninth},
          ), // Cmaj9 (IΔ7)
          ChordSpec.dominant7(
            9,
            id: 'j_4',
            alterations: const <ChordAlteration>{ChordAlteration.flat9},
          ), // A7(b9) (V7/ii -> loops back to Dm9)
        ];
    }
  }
}
