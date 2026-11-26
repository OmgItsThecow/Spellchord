// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/engine/guitar_voicing_solver.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/chord_voicing.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import '../widgets/explained_control.dart';
import 'guitar_fretboard_painter.dart';
import 'piano_roll_painter.dart';

/// Lower-workspace container featuring a mode switcher between Piano Mode and
/// Guitar Mode plus active MIDI voicing metadata and role color legend.
class VisualizerContainer extends StatelessWidget {
  const VisualizerContainer({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final ChordSpec? chord = controller.selectedChord;
    final ChordVoicing? pianoVoicing = controller.selectedPianoVoicing;
    final GuitarVoicing? guitarVoicing = controller.selectedGuitarVoicing;
    final bool preferFlat = controller.preferFlats;
    final bool isPiano = controller.visualizerMode == VisualizerMode.piano;
    final AppStrings strings = controller.strings;

    final List<int> activeMidi = isPiano
        ? (pianoVoicing?.midiNotes ?? const <int>[])
        : (guitarVoicing?.activeMidiPitches ?? const <int>[]);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDarkTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDarkTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header: Mode Switcher + Active Voicing Info + Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              // Segmented mode switcher
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppDarkTheme.bgWorkspace,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppDarkTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExplainedControl(
                        controller: controller,
                        explanation: strings.pianoModeTip,
                        child: _ModeTab(
                          icon: Icons.piano_rounded,
                          label: strings.pianoModeLabel,
                          selected: isPiano,
                          accent: AppDarkTheme.pelicanPink,
                          onTap: () =>
                              controller.setVisualizerMode(VisualizerMode.piano),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ExplainedControl(
                        controller: controller,
                        explanation: strings.guitarModeTip,
                        child: _ModeTab(
                          icon: Icons.grid_on_rounded,
                          label: strings.guitarModeLabel,
                          selected: !isPiano,
                          accent: AppDarkTheme.tonicColor,
                          onTap: () => controller
                              .setVisualizerMode(VisualizerMode.guitar),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Active chord & note readout
              if (chord != null && activeMidi.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      chord.symbol(
                        preferFlat: preferFlat,
                        activeInversion: isPiano
                            ? pianoVoicing?.inversionIndex
                            : guitarVoicing?.inversionIndex,
                      ),
                      style: const TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      activeMidi
                          .map(
                            (int m) => MidiPitch.midiLabel(
                              m,
                              preferFlat: preferFlat,
                              includeMidiNumber: false,
                            ),
                          )
                          .join(' · '),
                      style: const TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

              // Color legend
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  _LegendDot(
                    color: AppDarkTheme.rootNoteHighlight,
                    label: strings.bassRootLegend,
                  ),
                  _LegendDot(
                    color: AppDarkTheme.accentFor(isPiano: isPiano),
                    label: strings.upperTonesLegend,
                  ),
                  _LegendDot(
                    color: AppDarkTheme.commonToneHighlight,
                    label: strings.commonToneLegend,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Visualizer Canvas
          Expanded(
            child: isPiano
                ? PianoKeyboardVisualizer(controller: controller)
                : GuitarFretboardVisualizer(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.55) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: selected ? accent : AppDarkTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : AppDarkTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppDarkTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
