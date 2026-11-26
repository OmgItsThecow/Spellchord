// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/engine/modal_interchange.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/chord_voicing.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import 'explained_control.dart';

/// Compact, beginner-friendly quick-tools panel shown in Basic Mode in place of
/// the dual technical Voice Leading + Modal Interchange panels.
class BasicHelperPanel extends StatelessWidget {
  const BasicHelperPanel({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final ChordSpec? chord = controller.selectedChord;
    final ChordVoicing? voicing = controller.selectedPianoVoicing;
    final int selectedIndex = controller.selectedChordIndex;
    final bool preferFlat = controller.preferFlats;
    final AppStrings strings = controller.strings;

    if (chord == null || voicing == null) {
      return const SizedBox.shrink();
    }

    final bool isPiano = controller.visualizerMode == VisualizerMode.piano;
    final Color primaryAccent = AppDarkTheme.accentFor(isPiano: isPiano);
    final String bassName =
        MidiPitch.pitchClassName(voicing.bassPc, preferFlat: preferFlat);
    final List<BorrowedChordSuggestion> suggestions =
        controller.modalSuggestionsForSelected.take(4).toList(growable: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppDarkTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDarkTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Top row: Voicing / Inversion stepper + Auto-smooth
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: primaryAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    strings.basicHelperTitle,
                    style: const TextStyle(
                      color: AppDarkTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppDarkTheme.bgWorkspace,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppDarkTheme.borderSubtle),
                    ),
                    child: Text(
                      '${strings.basicInversionLabel}: ${strings.inversionLabel(voicing.inversionIndex)} · ${strings.bassNoteBadge(bassName)}',
                      style: const TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.prevInversionTip,
                    child: _StepIconButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => controller.stepInversion(selectedIndex, -1),
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.nextInversionTip,
                    child: _StepIconButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => controller.stepInversion(selectedIndex, 1),
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.optimalVlTip(isBasic: true),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: controller.resetAllInversionsToOptimal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primaryAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: primaryAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.auto_fix_high_rounded,
                              size: 13,
                              color: primaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.optimalVlLabel(
                                controller.totalProgressionSemitoneCost,
                                isBasic: true,
                              ),
                              style: TextStyle(
                                color: primaryAccent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppDarkTheme.borderSubtle),
          const SizedBox(height: 10),

          // Quick friendly chord swap suggestions
          if (suggestions.isEmpty)
            Text(
              strings.basicQuickSwapsEmpty,
              style: const TextStyle(
                color: AppDarkTheme.textMuted,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  strings.basicQuickSwapsLabel,
                  style: const TextStyle(
                    color: AppDarkTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...suggestions.map((BorrowedChordSuggestion s) {
                  final String symbol = s.chord.baseSymbol(
                    preferFlat: preferFlat,
                  );
                  final String mood = strings.borrowedFromLabel(s.sourceMode);
                  return ExplainedControl(
                    controller: controller,
                    explanation: strings.substituteTip(
                      symbol,
                      s.romanNumeral,
                      s.sourceMode,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.substituteWithBorrowedChord(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppDarkTheme.bgWorkspace,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppDarkTheme.borrowedColor
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              symbol,
                              style: const TextStyle(
                                color: AppDarkTheme.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mood,
                              style: const TextStyle(
                                color: AppDarkTheme.borrowedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepIconButton extends StatelessWidget {
  const _StepIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppDarkTheme.borderSubtle),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppDarkTheme.textPrimary,
        ),
      ),
    );
  }
}
