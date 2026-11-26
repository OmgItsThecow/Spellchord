import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/engine/guitar_voicing_solver.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import '../widgets/explained_control.dart';

/// Interactive dynamic fretboard matrix driven by a configurable array of open
/// string MIDI pitches and a per-string boolean filter mask.
class GuitarFretboardVisualizer extends StatefulWidget {
  const GuitarFretboardVisualizer({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<GuitarFretboardVisualizer> createState() =>
      _GuitarFretboardVisualizerState();
}

class _GuitarFretboardVisualizerState extends State<GuitarFretboardVisualizer> {
  int _fretWindowOffset = 0;
  bool _showMobileFineTune = false;
  GuitarVoicing? _lastVoicing;

  int _resolveStartFret(GuitarVoicing? voicing, int visibleFretCount) {
    if (visibleFretCount >= GuitarFretboardPainter.totalFrets) {
      return 1;
    }
    final List<int> fretted = <int>[];
    if (voicing != null) {
      for (final GuitarFretNote note in voicing.stringNotes) {
        if (note.isEnabled && note.fret != null && note.fret! > 0) {
          fretted.add(note.fret!);
        }
      }
    }
    int baseStart = 1;
    if (fretted.isNotEmpty) {
      final int minFret = fretted.reduce(math.min);
      final int maxFret = fretted.reduce(math.max);
      if (maxFret > visibleFretCount) {
        baseStart = math.min(
          minFret,
          math.max(1, maxFret - visibleFretCount + 1),
        );
      }
    }
    final int maxStart =
        GuitarFretboardPainter.totalFrets - visibleFretCount + 1;
    return (baseStart + _fretWindowOffset).clamp(1, maxStart);
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerController controller = widget.controller;
    final List<int> tuning = controller.guitarTuningMidi;
    final List<bool> mask = controller.guitarStringMask;
    final GuitarVoicing? voicing = controller.selectedGuitarVoicing;
    if (!identical(voicing, _lastVoicing)) {
      _fretWindowOffset = 0;
      _lastVoicing = voicing;
    }
    final ChordSpec? chord = controller.selectedChord;
    final bool preferFlat = controller.preferFlats;
    final bool isBasic = controller.isBasicMode;
    final AppStrings strings = controller.strings;

    final List<GuitarStringMaskPreset> visibleMaskPresets = isBasic
        ? const <GuitarStringMaskPreset>[
            GuitarStringMaskPreset.allSix,
            GuitarStringMaskPreset.topFour,
          ]
        : GuitarStringMaskPreset.presetsForSixStrings;

    final int prevIndex = controller.selectedChordIndex - 1;
    final Set<int> prevMidiSet = (prevIndex >= 0 &&
            prevIndex < controller.guitarVoicings.length)
        ? controller.guitarVoicings[prevIndex].activeMidiPitches.toSet()
        : const <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Tuning & String-Filtering Mask Controls (single scrollable strip)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isBasic) ...<Widget>[
                // Tuning presets (Advanced Mode)
                Text(
                  strings.guitarTuningLabel,
                  style: const TextStyle(
                    color: AppDarkTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                ExplainedControl(
                  controller: controller,
                  explanation: strings.guitarTuningTip,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 195),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppDarkTheme.bgWorkspace,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppDarkTheme.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text(
                            'Custom / Preset',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppDarkTheme.textPrimary,
                              fontSize: 11.5,
                            ),
                          ),
                          value: _matchingPresetName(tuning),
                          isDense: true,
                          dropdownColor: AppDarkTheme.cardElevated,
                          style: const TextStyle(
                            color: AppDarkTheme.textPrimary,
                            fontSize: 11.5,
                          ),
                          items: GuitarTuningPreset.all
                              .map(
                                (GuitarTuningPreset p) =>
                                    DropdownMenuItem<String>(
                                  value: p.name,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (String? presetName) {
                            if (presetName == null) {
                              return;
                            }
                            final GuitarTuningPreset preset =
                                GuitarTuningPreset.all.firstWhere(
                              (GuitarTuningPreset p) => p.name == presetName,
                            );
                            controller.applyGuitarTuningPreset(
                              preset.openStringMidi,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // String-mask quick presets
              Text(
                isBasic
                    ? strings.guitarMaskBasicLabel
                    : strings.guitarMaskLabel,
                style: const TextStyle(
                  color: AppDarkTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              ...visibleMaskPresets.map(
                (GuitarStringMaskPreset preset) {
                  final bool isSelected = _masksEqual(mask, preset.mask);
                  final String label = strings.maskPresetLabel(preset.label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ExplainedControl(
                      controller: controller,
                      explanation: strings.maskPresetTip(label),
                      child: InkWell(
                        onTap: () =>
                            controller.applyGuitarStringMaskPreset(preset.mask),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppDarkTheme.tonicColor
                                    .withValues(alpha: 0.16)
                                : AppDarkTheme.bgWorkspace,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppDarkTheme.tonicColor
                                  : AppDarkTheme.borderSubtle,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? AppDarkTheme.tonicColor
                                  : AppDarkTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Responsive Fretboard Workspace:
        // Wide (>=600): left string column + full 14-fret neck
        // Compact (<600 portrait): top string chips + auto-zoomed 5-fret full-width neck
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isCompact = constraints.maxWidth < 600;
              if (!isCompact) {
                return _buildWideFretboard(
                  controller: controller,
                  tuning: tuning,
                  mask: mask,
                  voicing: voicing,
                  chord: chord,
                  prevMidiSet: prevMidiSet,
                  preferFlat: preferFlat,
                  isBasic: isBasic,
                  strings: strings,
                );
              }
              return _buildCompactPortraitFretboard(
                controller: controller,
                tuning: tuning,
                mask: mask,
                voicing: voicing,
                chord: chord,
                prevMidiSet: prevMidiSet,
                preferFlat: preferFlat,
                isBasic: isBasic,
                strings: strings,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWideFretboard({
    required ExplorerController controller,
    required List<int> tuning,
    required List<bool> mask,
    required GuitarVoicing? voicing,
    required ChordSpec? chord,
    required Set<int> prevMidiSet,
    required bool preferFlat,
    required bool isBasic,
    required AppStrings strings,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Left column: per-string active/mute toggle (+ tuning steppers in Advanced Mode)
        SizedBox(
          width: isBasic ? 82 : 148,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Column(
              children: List<Widget>.generate(tuning.length, (int rev) {
                // Top row corresponds to highest string (index n-1)
                final int sIdx = tuning.length - 1 - rev;
                final bool enabled = sIdx < mask.length ? mask[sIdx] : true;
                final int openMidi = tuning[sIdx];
                final int stringNum = tuning.length - sIdx;
                final String openLabel = MidiPitch.midiLabel(
                  openMidi,
                  preferFlat: preferFlat,
                  includeMidiNumber: false,
                );

                return Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: isBasic ? 82 : 148,
                        child: Row(
                          children: <Widget>[
                            // Mute/Enable string boolean mask button
                            ExplainedControl(
                              controller: controller,
                              explanation: strings.stringToggleTip(
                                stringNum,
                                enabled,
                              ),
                              child: InkWell(
                                onTap: () =>
                                    controller.toggleGuitarString(sIdx),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  width: 30,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? AppDarkTheme.tonicColor
                                            .withValues(alpha: 0.16)
                                        : AppDarkTheme.bgWorkspace,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: enabled
                                          ? AppDarkTheme.tonicColor
                                              .withValues(alpha: 0.6)
                                          : AppDarkTheme.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    enabled ? '$stringNum' : 'X',
                                    style: TextStyle(
                                      color: enabled
                                          ? AppDarkTheme.tonicColor
                                          : AppDarkTheme.dominantColor,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isBasic) ...<Widget>[
                              const SizedBox(width: 4),
                              ExplainedControl(
                                controller: controller,
                                explanation: strings.tuneDownTip(
                                  stringNum,
                                  openMidi,
                                ),
                                child: _SmallTuneStepBtn(
                                  label: '-',
                                  onTap: () => controller
                                      .adjustGuitarStringTuning(sIdx, -1),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                openLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: enabled
                                      ? AppDarkTheme.textPrimary
                                      : AppDarkTheme.textMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isBasic)
                              ExplainedControl(
                                controller: controller,
                                explanation: strings.tuneUpTip(
                                  stringNum,
                                  openMidi,
                                ),
                                child: _SmallTuneStepBtn(
                                  label: '+',
                                  onTap: () => controller
                                      .adjustGuitarStringTuning(sIdx, 1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Right canvas: Full 14-fret Dynamic Fretboard Matrix
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: GuitarFretboardPainter(
                    openStringMidi: tuning,
                    stringMask: mask,
                    voicing: voicing,
                    chord: chord,
                    previousMidiSet: prevMidiSet,
                    preferFlat: preferFlat,
                    startFret: 1,
                    visibleFretCount: GuitarFretboardPainter.totalFrets,
                    showStringLabels: false,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPortraitFretboard({
    required ExplorerController controller,
    required List<int> tuning,
    required List<bool> mask,
    required GuitarVoicing? voicing,
    required ChordSpec? chord,
    required Set<int> prevMidiSet,
    required bool preferFlat,
    required bool isBasic,
    required AppStrings strings,
  }) {
    const int visibleFretCount = 5;
    final int startFret = _resolveStartFret(voicing, visibleFretCount);
    final int endFret = startFret + visibleFretCount - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Fret Window Navigator + Compact String Toggles + Fine Tune Toggle (1 row)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Fret Window Navigator (< Frets 1–5 >) first so it's always visible
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDarkTheme.bgWorkspace,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppDarkTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.fretLeftTip,
                      child: InkWell(
                        onTap: startFret > 1
                            ? () => setState(() => _fretWindowOffset--)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 16,
                            color: startFret > 1
                                ? AppDarkTheme.textPrimary
                                : AppDarkTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        strings.fretWindowLabel(startFret, endFret),
                        style: const TextStyle(
                          color: AppDarkTheme.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.fretRightTip,
                      child: InkWell(
                        onTap: endFret < GuitarFretboardPainter.totalFrets
                            ? () => setState(() => _fretWindowOffset++)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: endFret < GuitarFretboardPainter.totalFrets
                                ? AppDarkTheme.textPrimary
                                : AppDarkTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Per-string mute/enable pills (low string 6 -> high string 1)
              ...List<Widget>.generate(tuning.length, (int sIdx) {
                final bool enabled = sIdx < mask.length ? mask[sIdx] : true;
                final int openMidi = tuning[sIdx];
                final int stringNum = tuning.length - sIdx;
                final String pcName = MidiPitch.pitchClassName(
                  MidiPitch.pitchClass(openMidi),
                  preferFlat: preferFlat,
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ExplainedControl(
                    controller: controller,
                    explanation: strings.stringToggleTip(stringNum, enabled),
                    child: InkWell(
                      onTap: () => controller.toggleGuitarString(sIdx),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: enabled
                              ? AppDarkTheme.tonicColor.withValues(alpha: 0.16)
                              : AppDarkTheme.bgWorkspace,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: enabled
                                ? AppDarkTheme.tonicColor.withValues(alpha: 0.6)
                                : AppDarkTheme.borderSubtle,
                          ),
                        ),
                        child: Text(
                          enabled ? '$stringNum:$pcName' : '$stringNum:X',
                          style: TextStyle(
                            color: enabled
                                ? AppDarkTheme.tonicColor
                                : AppDarkTheme.dominantColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              if (!isBasic) ...<Widget>[
                const SizedBox(width: 2),
                ExplainedControl(
                  controller: controller,
                  explanation: strings.fineTuneToggleTip,
                  child: InkWell(
                    onTap: () => setState(
                      () => _showMobileFineTune = !_showMobileFineTune,
                    ),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _showMobileFineTune
                            ? AppDarkTheme.subdominantColor
                                .withValues(alpha: 0.16)
                            : AppDarkTheme.bgWorkspace,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _showMobileFineTune
                              ? AppDarkTheme.subdominantColor
                              : AppDarkTheme.borderSubtle,
                        ),
                      ),
                      child: Text(
                        strings.fineTuneToggleLabel,
                        style: TextStyle(
                          color: _showMobileFineTune
                              ? AppDarkTheme.subdominantColor
                              : AppDarkTheme.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Optional compact fine-tune drawer in Advanced Mode (1 scrollable row)
        if (!isBasic && _showMobileFineTune) ...<Widget>[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(tuning.length, (int sIdx) {
                final int openMidi = tuning[sIdx];
                final int stringNum = tuning.length - sIdx;
                final String openLabel = MidiPitch.midiLabel(
                  openMidi,
                  preferFlat: preferFlat,
                  includeMidiNumber: false,
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppDarkTheme.bgWorkspace,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppDarkTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ExplainedControl(
                          controller: controller,
                          explanation: strings.tuneDownTip(stringNum, openMidi),
                          child: _SmallTuneStepBtn(
                            label: '-',
                            onTap: () =>
                                controller.adjustGuitarStringTuning(sIdx, -1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '$stringNum:$openLabel',
                            style: const TextStyle(
                              color: AppDarkTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ExplainedControl(
                          controller: controller,
                          explanation: strings.tuneUpTip(stringNum, openMidi),
                          child: _SmallTuneStepBtn(
                            label: '+',
                            onTap: () =>
                                controller.adjustGuitarStringTuning(sIdx, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Full-Width Auto-Zoomed 5-Fret Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: GuitarFretboardPainter(
                    openStringMidi: tuning,
                    stringMask: mask,
                    voicing: voicing,
                    chord: chord,
                    previousMidiSet: prevMidiSet,
                    preferFlat: preferFlat,
                    startFret: startFret,
                    visibleFretCount: visibleFretCount,
                    showStringLabels: true,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String? _matchingPresetName(List<int> tuning) {
    for (final GuitarTuningPreset p in GuitarTuningPreset.all) {
      if (p.openStringMidi.length == tuning.length) {
        bool eq = true;
        for (int i = 0; i < tuning.length; i++) {
          if (p.openStringMidi[i] != tuning[i]) {
            eq = false;
            break;
          }
        }
        if (eq) {
          return p.name;
        }
      }
    }
    return null;
  }

  static bool _masksEqual(List<bool> a, List<bool> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

class _SmallTuneStepBtn extends StatelessWidget {
  const _SmallTuneStepBtn({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppDarkTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppDarkTheme.textSecondary,
            fontSize: 13.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering a configurable fret window (e.g. 14 frets on
/// wide/landscape viewports or an auto-zoomed 5-fret window on narrow portrait
/// phones) across configurable strings with active chord voicing circles,
/// ghost chord-tone map, and dimmed muted strings.
class GuitarFretboardPainter extends CustomPainter {
  GuitarFretboardPainter({
    required this.openStringMidi,
    required this.stringMask,
    required this.voicing,
    required this.chord,
    required this.previousMidiSet,
    required this.preferFlat,
    this.startFret = 1,
    this.visibleFretCount = totalFrets,
    this.showStringLabels = false,
  });

  final List<int> openStringMidi;
  final List<bool> stringMask;
  final GuitarVoicing? voicing;
  final ChordSpec? chord;
  final Set<int> previousMidiSet;
  final bool preferFlat;
  final int startFret;
  final int visibleFretCount;
  final bool showStringLabels;

  static const int totalFrets = 14;
  static const Set<int> _inlayFrets = <int>{3, 5, 7, 9, 12};

  @override
  void paint(Canvas canvas, Size size) {
    final int numStrings = openStringMidi.length;
    if (numStrings == 0) {
      return;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppDarkTheme.bgWorkspace,
    );

    const double topPad = 16.0;
    const double bottomPad = 24.0;
    final double labelColWidth = showStringLabels ? 26.0 : 0.0;
    const double openColWidth = 32.0;
    final double neckLeft = labelColWidth + openColWidth;
    final double openCenterX = labelColWidth + openColWidth / 2;
    const double rightPad = 10.0;

    final double boardWidth =
        math.max(0.0, size.width - neckLeft - rightPad);
    final double usableHeight =
        math.max(0.0, size.height - topPad - bottomPad);
    if (boardWidth < 40.0 || usableHeight < 30.0) {
      return;
    }

    final int safeStart = startFret.clamp(1, totalFrets);
    final int safeVisibleCount = math.max(1, visibleFretCount);
    final int endFret = math.min(totalFrets, safeStart + safeVisibleCount - 1);
    final int fretCols = math.max(1, endFret - safeStart + 1);
    final double fretWidth = boardWidth / fretCols;
    final double stringSpacing =
        numStrings == 1 ? 0.0 : usableHeight / (numStrings - 1);

    double stringY(int sIdx) {
      final int visualRow = numStrings - 1 - sIdx;
      return numStrings == 1
          ? topPad + usableHeight / 2
          : topPad + visualRow * stringSpacing;
    }

    // 1. Fretboard wood bed & fret wires
    final Rect neckRect = Rect.fromLTWH(
      neckLeft,
      topPad - 8,
      boardWidth,
      usableHeight + 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF1A1B22),
    );

    // Nut (or left boundary when panned past fret 1)
    canvas.drawLine(
      Offset(neckLeft, topPad - 8),
      Offset(neckLeft, topPad + usableHeight + 8),
      Paint()
        ..color = safeStart == 1
            ? AppDarkTheme.textSecondary
            : AppDarkTheme.borderSubtle
        ..strokeWidth = safeStart == 1 ? 3.4 : 1.6,
    );

    for (int i = 1; i <= fretCols; i++) {
      final int f = safeStart + i - 1;
      final double x = neckLeft + i * fretWidth;
      canvas.drawLine(
        Offset(x, topPad - 8),
        Offset(x, topPad + usableHeight + 8),
        Paint()
          ..color = AppDarkTheme.borderSubtle
          ..strokeWidth = 1.2,
      );

      final double centerX = x - fretWidth / 2;

      // Inlay markers
      if (_inlayFrets.contains(f)) {
        if (f == 12 && usableHeight > 50) {
          canvas.drawCircle(
            Offset(centerX, topPad + usableHeight * 0.30),
            4.0,
            Paint()..color = const Color(0xFF2B2C38),
          );
          canvas.drawCircle(
            Offset(centerX, topPad + usableHeight * 0.70),
            4.0,
            Paint()..color = const Color(0xFF2B2C38),
          );
        } else {
          canvas.drawCircle(
            Offset(centerX, topPad + usableHeight / 2),
            4.2,
            Paint()..color = const Color(0xFF2B2C38),
          );
        }
      }

      // Fret numbers along the bottom
      final String fretLabel = (i == 1 && safeStart > 1) ? '${f}fr' : '$f';
      _drawText(
        canvas,
        fretLabel,
        Offset(centerX, topPad + usableHeight + 15),
        const TextStyle(
          color: AppDarkTheme.textSecondary,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // 2. Strings + optional left string labels + ghost chord-tone map
    final Set<int> chordPcs = chord?.pitchClasses.toSet() ?? const <int>{};
    for (int s = 0; s < numStrings; s++) {
      final bool enabled = s < stringMask.length ? stringMask[s] : true;
      final double y = stringY(s);
      final double thickness = 1.0 + (numStrings - 1 - s) * 0.25;

      if (showStringLabels) {
        final String openPc = MidiPitch.pitchClassName(
          MidiPitch.pitchClass(openStringMidi[s]),
          preferFlat: preferFlat,
        );
        _drawText(
          canvas,
          openPc,
          Offset(labelColWidth / 2, y),
          TextStyle(
            color: enabled
                ? AppDarkTheme.textSecondary
                : AppDarkTheme.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        );
      }

      if (enabled) {
        canvas.drawLine(
          Offset(neckLeft, y),
          Offset(neckLeft + boardWidth, y),
          Paint()
            ..color = const Color(0xFF565869)
            ..strokeWidth = thickness,
        );

        // Ghost dots for all chord pitch classes along enabled strings in window
        for (int f = safeStart; f <= endFret; f++) {
          final int midi = openStringMidi[s] + f;
          if (chordPcs.contains(MidiPitch.pitchClass(midi))) {
            final double cx = neckLeft + (f - safeStart + 0.5) * fretWidth;
            canvas.drawCircle(
              Offset(cx, y),
              4.2,
              Paint()..color = const Color(0xFF2A313D),
            );
          }
        }
      } else {
        // Visually dimmed dashed line for muted/filtered strings
        _drawDashedLine(
          canvas,
          Offset(neckLeft, y),
          Offset(neckLeft + boardWidth, y),
          Paint()
            ..color = const Color(0xFF2B2B34)
            ..strokeWidth = 1.0,
        );
        _drawText(
          canvas,
          'X',
          Offset(openCenterX, y),
          TextStyle(
            color: AppDarkTheme.dominantColor.withValues(alpha: 0.65),
            fontSize: 13.0,
            fontWeight: FontWeight.w800,
          ),
        );
      }
    }

    // 3. Draw active GuitarVoicing notes
    if (voicing == null) {
      return;
    }
    final int? bassMidi = voicing!.bassMidi;

    for (final GuitarFretNote note in voicing!.stringNotes) {
      if (!note.isEnabled) {
        continue;
      }
      final double y = stringY(note.stringIndex);

      if (note.fret == null) {
        // String enabled by mask, unused in this specific grip
        _drawText(
          canvas,
          '×',
          Offset(openCenterX, y),
          const TextStyle(
            color: AppDarkTheme.textMuted,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        );
        continue;
      }

      final int f = note.fret!;
      if (f > totalFrets) {
        continue;
      }
      if (f > 0 && (f < safeStart || f > endFret)) {
        continue;
      }

      final int midi = note.soundedMidi!;
      final bool isBassOrRoot = note.isBass || note.isRoot || midi == bassMidi;
      final bool isCommon = previousMidiSet.contains(midi);

      final Color fillColor = isBassOrRoot
          ? AppDarkTheme.rootNoteHighlight
          : AppDarkTheme.upperNoteHighlight;

      final double cx = f == 0
          ? openCenterX
          : neckLeft + (f - safeStart + 0.5) * fretWidth;
      final double maxForSpacing =
          stringSpacing == 0 ? 15.0 : stringSpacing * 0.40;
      final double radius = math.max(
        8.0,
        math.min(15.0, math.min(maxForSpacing, fretWidth * 0.45)),
      );

      if (isCommon) {
        canvas.drawCircle(
          Offset(cx, y),
          radius + 3.0,
          Paint()
            ..color = AppDarkTheme.commonToneHighlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      canvas.drawCircle(
        Offset(cx, y),
        radius,
        Paint()..color = fillColor,
      );

      final String noteName = MidiPitch.pitchClassName(
        MidiPitch.pitchClass(midi),
        preferFlat: preferFlat,
      );
      _drawText(
        canvas,
        noteName,
        Offset(cx, y),
        const TextStyle(
          color: Color(0xFF0E1014),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dash = 5.0;
    const double gap = 4.0;
    double x = p1.dx;
    while (x < p2.dx) {
      final double end = (x + dash).clamp(p1.dx, p2.dx);
      canvas.drawLine(Offset(x, p1.dy), Offset(end, p2.dy), paint);
      x += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GuitarFretboardPainter oldDelegate) {
    return oldDelegate.voicing != voicing ||
        oldDelegate.chord != chord ||
        oldDelegate.openStringMidi != openStringMidi ||
        oldDelegate.stringMask != stringMask ||
        oldDelegate.preferFlat != preferFlat ||
        oldDelegate.startFret != startFret ||
        oldDelegate.visibleFretCount != visibleFretCount ||
        oldDelegate.showStringLabels != showStringLabels;
  }
}
