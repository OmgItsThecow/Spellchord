// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic_explorer/core/engine/harmonic_analyzer.dart';
import 'package:harmonic_explorer/core/localization/app_strings.dart';
import 'package:harmonic_explorer/core/models/chord_spec.dart';
import 'package:harmonic_explorer/core/models/harmonic_function.dart';
import 'package:harmonic_explorer/core/models/interval_profile.dart';
import 'package:harmonic_explorer/core/models/scale_mode.dart';
import 'package:harmonic_explorer/state/explorer_controller.dart';
import 'package:harmonic_explorer/ui/screens/explorer_workspace.dart';
import 'package:harmonic_explorer/ui/theme/dark_theme.dart';

void main() {
  group('HarmonicAnalyzer', () {
    test('detects C Major tonal center for ii-V-I cadence', () {
      final List<ChordSpec> progression = <ChordSpec>[
        ChordSpec.minor7(2, id: '1'), // Dm7
        ChordSpec.dominant7(7, id: '2'), // G7
        ChordSpec.major7(0, id: '3'), // Cmaj7
      ];

      final KeySignatureResult key =
          HarmonicAnalyzer.detectKeyCenter(progression);
      expect(key.tonicPc, 0);
      expect(key.mode, ScaleMode.ionian);
    });

    test('detects A Minor tonal center with harmonic minor V7', () {
      final List<ChordSpec> progression = <ChordSpec>[
        ChordSpec.minor7(9, id: '1'), // Am7
        ChordSpec.halfDim7(11, id: '2'), // Bm7b5
        ChordSpec.dominant7(4, id: '3'), // E7
        ChordSpec.minor(9, id: '4'), // Am
      ];

      final KeySignatureResult key =
          HarmonicAnalyzer.detectKeyCenter(progression);
      expect(key.tonicPc, 9);
      expect(key.mode, ScaleMode.aeolian);
    });

    test('identifies diatonic, secondary dominant, diminished passing, and borrowed chords', () {
      final List<ChordSpec> progression = <ChordSpec>[
        ChordSpec.major7(0, id: '1'), // Cmaj7 -> IΔ7 (Tonic)
        ChordSpec.dominant7(
          9,
          id: '2',
          alterations: const <ChordAlteration>{ChordAlteration.flat9},
        ), // A7(b9) -> V7/ii (Secondary Dominant)
        ChordSpec.minor7(2, id: '3'), // Dm7 -> ii7 (Predominant)
        ChordSpec.dim7(6, id: '4'), // F#dim7 -> vii°7/V (Diminished Passing)
        ChordSpec.minor7(5, id: '5'), // Fm7 -> iv7 (Borrowed from Aeolian)
        ChordSpec.dominant7(7, id: '6'), // G7 -> V7 (Dominant)
      ];

      final List<HarmonicAnalysisResult> results =
          HarmonicAnalyzer.analyzeProgression(
        progression: progression,
        keyTonicPc: 0,
        keyMode: ScaleMode.ionian,
      );

      expect(results[0].category, HarmonicCategory.tonic);
      expect(results[0].romanNumeral, 'IΔ7');

      expect(results[1].category, HarmonicCategory.secondaryDominant);
      expect(results[1].romanNumeral, 'V7/ii');

      expect(results[2].category, HarmonicCategory.subdominant);
      expect(results[2].romanNumeral, 'ii7');

      expect(results[3].category, HarmonicCategory.diminishedPassing);
      expect(results[3].romanNumeral, 'vii°7/V');

      expect(results[4].category, HarmonicCategory.borrowed);
      expect(results[4].romanNumeral, 'iv7');
      expect(results[4].borrowedFromMode, ScaleMode.aeolian);

      expect(results[5].category, HarmonicCategory.dominant);
      expect(results[5].romanNumeral, 'V7');
    });

    test('detects Parent Major for all 12 Marusa transpositions and 4-chord Royal Road', () {
      for (int tonic = 0; tonic < 12; tonic++) {
        for (final bool useDominantIii in const <bool>[false, true]) {
          final List<ChordSpec> marusa = <ChordSpec>[
            ChordSpec.major7((tonic + 5) % 12, id: 'm1'),
            useDominantIii
                ? ChordSpec.dominant7((tonic + 4) % 12, id: 'm2')
                : ChordSpec.minor7((tonic + 4) % 12, id: 'm2'),
            ChordSpec.minor7((tonic + 9) % 12, id: 'm3'),
            ChordSpec.minor7((tonic + 7) % 12, id: 'm4'),
            ChordSpec.dominant7(tonic, id: 'm5'),
          ];
          final KeySignatureResult key = HarmonicAnalyzer.detectKeyCenter(marusa);
          expect(key.tonicPc, tonic);
          expect(key.mode, ScaleMode.ionian);

          final List<HarmonicAnalysisResult> analysis =
              HarmonicAnalyzer.analyzeProgression(
            progression: marusa,
            keyTonicPc: key.tonicPc,
            keyMode: key.mode,
          );
          expect(analysis.first.romanNumeral, 'IVΔ7');
        }
      }

      final List<ChordSpec> royalRoad4 = <ChordSpec>[
        ChordSpec.major7(5, id: 'r1'),
        ChordSpec.dominant7(7, id: 'r2'),
        ChordSpec.minor7(4, id: 'r3'),
        ChordSpec.minor7(9, id: 'r4'),
      ];
      final KeySignatureResult rrKey =
          HarmonicAnalyzer.detectKeyCenter(royalRoad4);
      expect(rrKey.tonicPc, 0);
      expect(rrKey.mode, ScaleMode.ionian);
      expect(
        HarmonicAnalyzer.analyzeProgression(
          progression: royalRoad4,
          keyTonicPc: rrKey.tonicPc,
          keyMode: rrKey.mode,
        ).map((HarmonicAnalysisResult r) => r.romanNumeral).toList(),
        const <String>['IVΔ7', 'V7', 'iii7', 'vi7'],
      );
    });

    test('preserves natural minor detection for Aeolian loops', () {
      final List<ChordSpec> amLoop1 = <ChordSpec>[
        ChordSpec.minor(9, id: 'a1'), // Am
        ChordSpec.major(7, id: 'a2'), // G
        ChordSpec.major(5, id: 'a3'), // F
        ChordSpec.major(7, id: 'a4'), // G
      ];
      final KeySignatureResult k1 = HarmonicAnalyzer.detectKeyCenter(amLoop1);
      expect(k1.tonicPc, 9);
      expect(k1.mode, ScaleMode.aeolian);

      final List<ChordSpec> amLoop2 = <ChordSpec>[
        ChordSpec.minor(9, id: 'b1'), // Am
        ChordSpec.major(5, id: 'b2'), // F
        ChordSpec.major(0, id: 'b3'), // C
        ChordSpec.major(7, id: 'b4'), // G
      ];
      final KeySignatureResult k2 = HarmonicAnalyzer.detectKeyCenter(amLoop2);
      expect(k2.tonicPc, 9);
      expect(k2.mode, ScaleMode.aeolian);
    });

    test('detects expected key centers and first-chord Roman numerals for all 10 presets', () {
      final ExplorerController controller = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(controller.dispose);

      const Map<String, ({int tonic, ScaleMode mode, String firstRoman})>
          expectedByPreset =
          <String, ({int tonic, ScaleMode mode, String firstRoman})>{
        'Pop Anthem + Minor iv': (
          tonic: 0,
          mode: ScaleMode.ionian,
          firstRoman: 'I',
        ),
        '50s / Soul Turnaround': (
          tonic: 7,
          mode: ScaleMode.ionian,
          firstRoman: 'I',
        ),
        'Andalusian Cadence': (
          tonic: 9,
          mode: ScaleMode.aeolian,
          firstRoman: 'i',
        ),
        'Royal Road (J-Pop)': (
          tonic: 0,
          mode: ScaleMode.ionian,
          firstRoman: 'IVΔ7',
        ),
        'Marusa (Just the Two of Us)': (
          tonic: 0,
          mode: ScaleMode.ionian,
          firstRoman: 'IVΔ7',
        ),
        'Dream Pop': (
          tonic: 2,
          mode: ScaleMode.ionian,
          firstRoman: 'IVΔ7',
        ),
        'Bossa Nova Turnaround': (
          tonic: 5,
          mode: ScaleMode.ionian,
          firstRoman: 'IΔ7',
        ),
        'ii-V-I + Sec Dom': (
          tonic: 0,
          mode: ScaleMode.ionian,
          firstRoman: 'ii9',
        ),
        'Modal Interchange': (
          tonic: 0,
          mode: ScaleMode.ionian,
          firstRoman: 'IΔ7',
        ),
        'Diminished Passing': (
          tonic: 5,
          mode: ScaleMode.ionian,
          firstRoman: 'IΔ7',
        ),
        'Neo-Soul Extended': (
          tonic: 0,
          mode: ScaleMode.aeolian,
          firstRoman: 'i9',
        ),
      };

      expect(expectedByPreset.keys, containsAll(ExplorerController.presetNames));
      for (final String presetName in ExplorerController.presetNames) {
        controller.loadPresetProgression(presetName);
        final expected = expectedByPreset[presetName]!;
        expect(controller.activeKeyTonicPc, expected.tonic, reason: presetName);
        expect(controller.activeKeyMode, expected.mode, reason: presetName);
        expect(
          controller.analyses.first.romanNumeral,
          expected.firstRoman,
          reason: presetName,
        );
      }
    });
  });

  group('Custom User Presets', () {
    test('ChordSpec JSON serialization round-trips extensions, alterations, and inversions', () {
      final ChordSpec original = ChordSpec.dominant7(
        7,
        id: 'custom_g',
        extensions: const <ChordExtension>{ChordExtension.thirteenth},
        alterations: const <ChordAlteration>{ChordAlteration.flat9},
      ).copyWith(manualInversion: 2, voicingVariantIndex: 1);

      final Map<String, dynamic> json = original.toJson();
      final ChordSpec restored = ChordSpec.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.rootPc, original.rootPc);
      expect(restored.triad, original.triad);
      expect(restored.seventh, original.seventh);
      expect(restored.extensions, original.extensions);
      expect(restored.alterations, original.alterations);
      expect(restored.manualInversion, 2);
      expect(restored.voicingVariantIndex, 1);
    });

    test('ExplorerController saves, loads, and deletes custom user presets', () async {
      final ExplorerController controller = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      controller.addChord(ChordSpec.minor7(5, id: 'extra_fm7'));
      final int savedLength = controller.progression.length;

      await controller.saveUserPreset('My Custom Jam', persist: false);
      expect(controller.userPresetNames, contains('My Custom Jam'));
      expect(controller.isUserPreset('My Custom Jam'), isTrue);

      controller.loadPresetProgression('Andalusian Cadence');
      expect(controller.progression.length, 4);

      controller.loadPresetProgression('My Custom Jam');
      expect(controller.progression.length, savedLength);
      expect(controller.progression.last.id, 'extra_fm7');

      await controller.deleteUserPreset('My Custom Jam', persist: false);
      expect(controller.userPresetNames, isNot(contains('My Custom Jam')));
    });

    test('switching tonality transposes chords and adapts diatonic scale modes', () {
      final ExplorerController controller = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(controller.dispose);

      // Default preset is Dream-Pop Nocturne in D Major:
      // Gmaj7 (IVΔ7), F#m7 (iii7), Em7 (ii7), Dmaj7 (IΔ7)
      expect(controller.activePresetName, 'Dream Pop');
      expect(controller.activeKeyTonicPc, 2);
      expect(controller.activeKeyMode, ScaleMode.ionian);
      expect(
        controller.analyses.map((HarmonicAnalysisResult a) => a.romanNumeral).toList(),
        const <String>['IVΔ7', 'iii7', 'ii7', 'IΔ7'],
      );

      // Load ii-V-I + Sec Dom in C Major:
      // Dm9 (ii9), G13 (V13), Cmaj9 (IΔ7), A7(b9) (V7/ii)
      controller.loadPresetProgression('ii-V-I + Sec Dom');
      expect(controller.activeKeyTonicPc, 0);
      expect(controller.activeKeyMode, ScaleMode.ionian);
      expect(
        controller.analyses.map((HarmonicAnalysisResult a) => a.romanNumeral).toList(),
        const <String>['ii9', 'V13', 'IΔ7', 'V7/ii'],
      );

      // Switch root from C (0) to D (2) in Ionian: all chords transpose +2 semitones
      controller.setLockedKey(2, ScaleMode.ionian);
      expect(controller.activeKeyTonicPc, 2);
      expect(
        controller.progression.map((ChordSpec c) => c.baseSymbol()).toList(),
        const <String>['Em9', 'A13', 'Dmaj9', 'B7(b9)'],
      );
      expect(
        controller.analyses.map((HarmonicAnalysisResult a) => a.romanNumeral).toList(),
        const <String>['ii9', 'V13', 'IΔ7', 'V7/ii'],
      );

      // Load Pop Anthem + Minor iv in C Major (C, G, Am, F, Fm, C) and switch mode to C Aeolian
      controller.loadPresetProgression('Pop Anthem + Minor iv');
      controller.setLockedKey(0, ScaleMode.aeolian);
      expect(
        controller.progression
            .map((ChordSpec c) => c.baseSymbol(preferFlat: true))
            .toList(),
        const <String>['Cm', 'Gm', 'Ab', 'Fm', 'Fm', 'Cm'],
      );
    });

    test('undo and redo restore progression and key edits cleanly', () {
      final ExplorerController controller = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(controller.dispose);

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      final int initialLen = controller.progression.length;
      controller.addChord(ChordSpec.major7(0, id: 'undo_c'));
      expect(controller.progression.length, initialLen + 1);
      expect(controller.canUndo, isTrue);

      controller.removeChordAt(0);
      expect(controller.progression.length, initialLen);

      expect(controller.undo(), isTrue);
      expect(controller.progression.length, initialLen + 1);
      expect(controller.canRedo, isTrue);

      expect(controller.undo(), isTrue);
      expect(controller.progression.length, initialLen);
      expect(controller.activePresetName, 'Dream Pop');

      expect(controller.redo(), isTrue);
      expect(controller.progression.length, initialLen + 1);
      expect(controller.progression.last.id, 'undo_c');

      // Duplicate chord at index 0 and verify unique ID + undo support
      final ChordSpec originalFirst = controller.progression.first;
      controller.duplicateChordAt(0);
      expect(controller.progression.length, initialLen + 2);
      expect(controller.progression[1].rootPc, originalFirst.rootPc);
      expect(controller.progression[1].id, isNot(originalFirst.id));
      expect(controller.undo(), isTrue);
      expect(controller.progression.length, initialLen + 1);

      // Flip Gmaj7 (index 0) -> Gm7 -> Gmaj7
      expect(controller.progression[0].triad, TriadQuality.major);
      controller.toggleChordQualityAt(0);
      expect(controller.progression[0].triad, TriadQuality.minor);
      expect(controller.progression[0].seventh, SeventhQuality.minor7);
      controller.toggleChordQualityAt(0);
      expect(controller.progression[0].triad, TriadQuality.major);
      expect(controller.progression[0].seventh, SeventhQuality.major7);

      // Insert Secondary Dominant (D7) before Gmaj7 at index 0
      controller.insertSecondaryDominantBefore(0);
      expect(controller.progression[0].rootPc, (7 + 7) % 12); // D7
      expect(controller.progression[0].seventh, SeventhQuality.dominant7);
      expect(controller.undo(), isTrue);
      expect(controller.progression[0].rootPc, 7); // Back to Gmaj7
    });
  });

  group('Android Layout Overflow Regression', () {
    for (final Size viewport in const <Size>[
      Size(360, 640),
      Size(390, 844),
      Size(640, 360),
    ]) {
      testWidgets(
        'renders all screens and modes without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (WidgetTester tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final ExplorerController controller = ExplorerController(
            loadPersistedPresets: false,
            enableAudio: false,
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: AppDarkTheme.themeData,
              theme: AppDarkTheme.themeData,
              home: ExplorerWorkspace(controller: controller),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Language Selector Screen -> tap English
          final Finder englishBtn = find.text('Continue in English');
          await tester.ensureVisible(englishBtn);
          await tester.tap(englishBtn);
          await tester.pumpAndSettle();

          // 2. Credits Screen -> tap "I don't care"
          final Finder creditsBtn = find.text("I don't care");
          await tester.ensureVisible(creditsBtn);
          await tester.tap(creditsBtn);
          await tester.pumpAndSettle();

          // 3. Setup Preferences Screen -> tap "Start Exploring" (Basic + Piano)
          final Finder startBtn = find.text('Start Exploring');
          await tester.ensureVisible(startBtn);
          await tester.tap(startBtn);
          await tester.pumpAndSettle();

          // 4. Basic Mode (Compact Basic Helper + Guitar)
          expect(find.text('CHORD QUICK TOOLS'), findsOneWidget);
          expect(find.textContaining('MIDI ['), findsNothing);
          controller.setVisualizerMode(VisualizerMode.guitar);
          await tester.pumpAndSettle();
          if (viewport.width < 600) {
            expect(find.textContaining('Frets '), findsOneWidget);
          }

          // 5. Advanced Mode (Guitar + Modal Interchange, then Piano + Voice Leading)
          controller.setComplexityMode(ComplexityMode.advanced);
          controller.loadPresetProgression('Pop Anthem + Minor iv');
          await tester.pumpAndSettle();
          expect(find.textContaining('MIDI ['), findsNothing);

          final Finder modalTab = find.text('Modal Interchange');
          await tester.ensureVisible(modalTab);
          await tester.tap(modalTab);
          await tester.pumpAndSettle();

          final Finder fineTuneBtn = find.text('Fine Tune ±1');
          if (fineTuneBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(fineTuneBtn);
            await tester.tap(fineTuneBtn);
            await tester.pumpAndSettle();
          }

          controller.setVisualizerMode(VisualizerMode.piano);
          await tester.pumpAndSettle();
          final Finder vlTab = find.text('Voice Leading');
          await tester.ensureVisible(vlTab);
          await tester.tap(vlTab);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Spanish onboarding localizes credits and setup preferences cleanly at 360x640',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ExplorerController controller = ExplorerController(
          loadPersistedPresets: false,
          enableAudio: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: AppDarkTheme.themeData,
            theme: AppDarkTheme.themeData,
            home: ExplorerWorkspace(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Choose Spanish
        final Finder spanishBtn = find.text('Continuar en Español');
        await tester.ensureVisible(spanishBtn);
        await tester.tap(spanishBtn);
        await tester.pumpAndSettle();

        // 2. Verify Spanish credits screen and tap secret "Sigue rockeando el mundo"
        expect(find.text('No me importa'), findsOneWidget);
        final Finder secretEs = find.text('Sigue rockeando el mundo');
        expect(secretEs, findsOneWidget);
        await tester.ensureVisible(secretEs);
        await tester.tap(secretEs);
        await tester.pumpAndSettle();

        // 3. Verify Spanish setup screen, select Avanzado + Guitarra, and tap Comenzar
        final Finder advancedEs = find.text('Avanzado');
        await tester.ensureVisible(advancedEs);
        await tester.tap(advancedEs);
        await tester.pumpAndSettle();

        final Finder guitarEs = find.text('Guitarra');
        await tester.ensureVisible(guitarEs);
        await tester.tap(guitarEs);
        await tester.pumpAndSettle();

        final Finder startEs = find.text('Comenzar');
        await tester.ensureVisible(startEs);
        await tester.tap(startEs);
        await tester.pumpAndSettle();

        expect(controller.language, AppLanguage.es);
        expect(controller.isSecretRockPrimed, isTrue);
        expect(controller.complexityMode, ComplexityMode.advanced);
        expect(controller.visualizerMode, VisualizerMode.guitar);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'secret Keep rocking the world flow stays hidden until preset save and renders cleanly at 360x640',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ExplorerController controller = ExplorerController(
          loadPersistedPresets: false,
          enableAudio: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: AppDarkTheme.themeData,
            theme: AppDarkTheme.themeData,
            home: ExplorerWorkspace(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Language -> English
        final Finder englishBtn = find.text('Continue in English');
        await tester.ensureVisible(englishBtn);
        await tester.tap(englishBtn);
        await tester.pumpAndSettle();

        // 2. Credits -> secret tap
        final Finder secretLegend = find.text('Keep rocking the world');
        await tester.ensureVisible(secretLegend);
        await tester.tap(secretLegend);
        await tester.pumpAndSettle();

        // 3. Setup -> Start Exploring
        final Finder startBtn = find.text('Start Exploring');
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        // Still hidden before saving a preset
        expect(controller.isSecretRockPrimed, isTrue);
        expect(controller.isSecretImprovRevealed, isFalse);
        expect(
          find.text('SECRET ORACLE · IMPROVISATION SCALES & AESTHETIC VIBE'),
          findsNothing,
        );

        // Load Marusa preset and save as user preset to reveal secret oracle
        controller.loadPresetProgression('Marusa (Just the Two of Us)');
        await controller.saveUserPreset('My Marusa Loop', persist: false);
        await tester.pumpAndSettle();

        expect(controller.isSecretImprovRevealed, isTrue);
        expect(
          find.text('SECRET ORACLE · IMPROVISATION SCALES & AESTHETIC VIBE'),
          findsOneWidget,
        );
        expect(find.textContaining('gliding smoothly above the city streets'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Marusa Preset & Secret Improv Oracle', () {
    test('loads Marusa progression and reveals improv scales only when secret-primed and saved', () async {
      final ExplorerController normalCtrl = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(normalCtrl.dispose);

      normalCtrl.loadPresetProgression('Marusa (Just the Two of Us)');
      expect(normalCtrl.progression.length, 5);
      expect(normalCtrl.activeKeyTonicPc, 0);
      expect(normalCtrl.activeKeyMode, ScaleMode.ionian);
      expect(
        normalCtrl.analyses.map((HarmonicAnalysisResult a) => a.romanNumeral).toList(),
        const <String>['IVΔ7', 'iii7', 'vi7', 'v7', 'V7/IV'],
      );
      expect(
        normalCtrl.progression.map((ChordSpec c) => c.symbol()).toList(),
        const <String>['Fmaj7', 'Em7', 'Am7', 'Gm7', 'C7'],
      );

      normalCtrl.dismissCredits();
      await normalCtrl.saveUserPreset('Normal Save', persist: false);
      expect(normalCtrl.isSecretImprovRevealed, isFalse);

      final ExplorerController secretCtrl = ExplorerController(
        loadPersistedPresets: false,
        enableAudio: false,
      );
      addTearDown(secretCtrl.dispose);

      secretCtrl.loadPresetProgression('Marusa (Just the Two of Us)');
      secretCtrl.dismissCredits(secretRockTap: true);
      expect(secretCtrl.isSecretRockPrimed, isTrue);
      expect(secretCtrl.isSecretImprovRevealed, isFalse);

      await secretCtrl.saveUserPreset('Secret Marusa', persist: false);
      expect(secretCtrl.isSecretImprovRevealed, isTrue);
      expect(secretCtrl.improvInsight, isNotNull);
      expect(secretCtrl.improvInsight!.progressionScales.length, 2);
      expect(
        secretCtrl.improvInsight!.progressionScales[0].title,
        contains('Major Pentatonic with the 9th'),
      );
      expect(
        secretCtrl.improvInsight!.progressionScales[1].title,
        contains('Mixolydian'),
      );
      expect(
        secretCtrl.improvInsight!.progressionScales[1].aestheticExperience,
        contains('sudden drop in temperature'),
      );
      expect(
        secretCtrl.improvInsight!.selectedChordScale.isChordSpecific,
        isTrue,
      );
    });
  });
}
