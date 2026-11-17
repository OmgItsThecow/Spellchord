// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/engine/modal_interchange.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/midi_pitch.dart';
import '../../core/models/scale_mode.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import 'explained_control.dart';

/// Displays borrowed chord substitutions derived from parallel modes.
/// In Basic Mode, displays the top 3 smooth borrowed options without filter clutter.
class ModalInterchangePanel extends StatelessWidget {
  const ModalInterchangePanel({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final ChordSpec? selected = controller.selectedChord;
    final ScaleMode activeKeyMode = controller.activeKeyMode;
    final bool preferFlat = controller.preferFlats;
    final bool isBasic = controller.isBasicMode;
    final AppStrings strings = controller.strings;

    final String keyName = MidiPitch.pitchClassName(
      controller.activeKeyTonicPc,
      preferFlat: preferFlat,
    );

    final List<ScaleMode> filterModes = ScaleModeX.parallelModes
        .where((ScaleMode m) => m != activeKeyMode)
        .toList();

    final List<BorrowedChordSuggestion> allSuggestions =
        controller.modalSuggestionsForSelected;
    final List<BorrowedChordSuggestion> displayedSuggestions = isBasic
        ? allSuggestions.take(3).toList()
        : allSuggestions;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDarkTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDarkTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.swap_horiz_rounded,
                size: 17,
                color: AppDarkTheme.borrowedColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBasic
                      ? strings.modalInterchangeBasicTitle
                      : strings.modalInterchangeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDarkTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (selected != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  'vs $keyName ${isBasic ? strings.basicScaleLabel(activeKeyMode) : activeKeyMode.shortLabel}',
                  style: const TextStyle(
                    color: AppDarkTheme.borrowedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          if (isBasic)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                strings.basicModalGuide,
                style: const TextStyle(
                  color: AppDarkTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                strings.advancedModalGuide,
                style: const TextStyle(
                  color: AppDarkTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            // Parallel mode filter chips (Advanced Mode only)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.allModesTip,
                    child: _ModeFilterChip(
                      label: strings.allParallelModesLabel,
                      selected: controller.modalFilterMode == null,
                      onTap: () => controller.setModalFilter(null),
                    ),
                  ),
                  ...filterModes.map(
                    (ScaleMode m) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ExplainedControl(
                        controller: controller,
                        explanation: strings.modeFilterTip(m),
                        child: _ModeFilterChip(
                          label: m.shortLabel,
                          selected: controller.modalFilterMode == m,
                          onTap: () => controller.setModalFilter(m),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Borrowed chord substitution list
          Expanded(
            child: displayedSuggestions.isEmpty
                ? Center(
                    child: Text(
                      strings.noBorrowedMatches,
                      style: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: displayedSuggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final BorrowedChordSuggestion item =
                          displayedSuggestions[index];
                      final String symbol =
                          item.chord.baseSymbol(preferFlat: preferFlat);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppDarkTheme.bgWorkspace,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppDarkTheme.borderSubtle),
                        ),
                        child: Row(
                          children: <Widget>[
                            // Roman numeral & chord symbol
                            Container(
                              width: 76,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppDarkTheme.borrowedColor
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.romanNumeral,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppDarkTheme.borrowedColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    symbol,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppDarkTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Source modes & metrics
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if (isBasic)
                                    Text(
                                      strings.borrowedFromLabel(item.sourceMode),
                                      style: const TextStyle(
                                        color: AppDarkTheme.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: item.allSourceModes
                                          .map(
                                            (ScaleMode mode) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppDarkTheme.cardSurface,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color:
                                                      AppDarkTheme.borderSubtle,
                                                ),
                                              ),
                                              child: Text(
                                                mode.shortLabel,
                                                style: const TextStyle(
                                                  color: AppDarkTheme
                                                      .textSecondary,
                                                  fontSize: 11.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isBasic
                                        ? strings.basicInversionMetrics(
                                            item.commonTonesWithCurrent,
                                            item.voiceLeadingDistance.round(),
                                            isFirst: false,
                                          )
                                        : '${strings.vlTravelSummary(item.voiceLeadingDistance.round(), item.commonTonesWithCurrent)} · ${item.sourceMode.characteristicNoteDescription}',
                                    style: const TextStyle(
                                      color: AppDarkTheme.textMuted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Substitute button
                            ExplainedControl(
                              controller: controller,
                              explanation: strings.substituteTip(
                                symbol,
                                item.romanNumeral,
                                item.sourceMode,
                              ),
                              child: InkWell(
                                onTap: () =>
                                    controller.substituteWithBorrowedChord(item),
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppDarkTheme.borrowedColor
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: AppDarkTheme.borrowedColor
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    isBasic
                                        ? strings.trySwapLabel
                                        : strings.substituteLabel,
                                    style: const TextStyle(
                                      color: AppDarkTheme.borrowedColor,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModeFilterChip extends StatelessWidget {
  const _ModeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppDarkTheme.borrowedColor.withValues(alpha: 0.18)
              : AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? AppDarkTheme.borrowedColor
                : AppDarkTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppDarkTheme.borrowedColor
                : AppDarkTheme.textSecondary,
            fontSize: 12.0,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
