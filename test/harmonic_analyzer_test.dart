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

      // Default preset is ii-V-I + Sec Dom in C Major:
      // Cmaj7, A7(b9), Dm9, Fm7, G13, Cmaj9
      expect(controller.activeKeyTonicPc, 0);
      expect(controller.activeKeyMode, ScaleMode.ionian);

      // Switch root from C (0) to D (2) in Ionian: all chords transpose +2 semitones
      controller.setLockedKey(2, ScaleMode.ionian);
      expect(controller.activeKeyTonicPc, 2);
      expect(
        controller.progression.map((ChordSpec c) => c.baseSymbol()).toList(),
        const <String>['Dmaj7', 'B7(b9)', 'Em9', 'Gm7', 'A13', 'Dmaj9'],
      );
      expect(
        controller.analyses.map((HarmonicAnalysisResult a) => a.romanNumeral).toList(),
        const <String>['IΔ7', 'V7/ii', 'ii9', 'iv7', 'V13', 'IΔ7'],
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

          // 1. Credits Screen -> tap "I don't care"
          final Finder creditsBtn = find.text("I don't care");
          await tester.ensureVisible(creditsBtn);
          await tester.tap(creditsBtn);
          await tester.pumpAndSettle();

          // 2. Language Selector Screen -> tap English
          final Finder englishBtn = find.text('Continue in English');
          await tester.ensureVisible(englishBtn);
          await tester.tap(englishBtn);
          await tester.pumpAndSettle();

          // 3. Basic Mode (Piano + Voice Leading, then Guitar + Modal Interchange)
          controller.setVisualizerMode(VisualizerMode.guitar);
          await tester.pumpAndSettle();
          if (viewport.width < 600) {
            expect(find.textContaining('Frets '), findsOneWidget);
          }

          final Finder modalTab = find.text('Modal Interchange');
          await tester.ensureVisible(modalTab);
          await tester.tap(modalTab);
          await tester.pumpAndSettle();

          // 4. Advanced Mode (Guitar + Modal Interchange, then Piano + Voice Leading)
          controller.setComplexityMode(ComplexityMode.advanced);
          controller.loadPresetProgression('Pop Anthem + Minor iv');
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

        final Finder secretLegend = find.text('Keep rocking the world');
        await tester.ensureVisible(secretLegend);
        await tester.tap(secretLegend);
        await tester.pumpAndSettle();

        final Finder englishBtn = find.text('Continue in English');
        await tester.ensureVisible(englishBtn);
        await tester.tap(englishBtn);
        await tester.pumpAndSettle();

        // Still hidden before saving a preset
        expect(controller.isSecretRockPrimed, isTrue);
        expect(controller.isSecretImprovRevealed, isFalse);
        expect(find.text('✦ Improv Oracle'), findsNothing);

        // Load Marusa preset and save as user preset to reveal secret oracle
        controller.loadPresetProgression('Marusa (Just the Two of Us)');
        await controller.saveUserPreset('My Marusa Loop', persist: false);
        await tester.pumpAndSettle();

        expect(controller.isSecretImprovRevealed, isTrue);
        expect(find.text('✦ Improv Oracle'), findsOneWidget);
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
