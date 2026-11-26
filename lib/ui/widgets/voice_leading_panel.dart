// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/chord_voicing.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import 'explained_control.dart';

/// Displays inversion controls and voice-leading transitions, adapting between
/// a beginner-friendly Basic Mode and a full SATB MIDI Advanced Mode.
class VoiceLeadingPanel extends StatelessWidget {
  const VoiceLeadingPanel({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final ChordSpec? chord = controller.selectedChord;
    final ChordVoicing? voicing = controller.selectedPianoVoicing;
    final ChordVoicing? prevVoicing = controller.previousPianoVoicing;
    final int selectedIndex = controller.selectedChordIndex;
    final bool preferFlat = controller.preferFlats;
    final bool isBasic = controller.isBasicMode;
    final bool isPiano = controller.visualizerMode == VisualizerMode.piano;
    final Color primaryAccent = AppDarkTheme.accentFor(isPiano: isPiano);
    final AppStrings strings = controller.strings;

    if (chord == null || voicing == null) {
      return const SizedBox.shrink();
    }

    final List<ChordVoicing> candidates =
        controller.candidateInversionsForSelected;
    final bool isManual = chord.manualInversion != null;
    final String activeBassName =
        MidiPitch.pitchClassName(voicing.bassPc, preferFlat: preferFlat);

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
          // Header with inversion stepper
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.timeline_rounded,
                    size: 16,
                    color: primaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isBasic
                          ? strings.voiceLeadingBasicTitle
                          : strings.voiceLeadingTitle,
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
                  if (!isBasic) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppDarkTheme.bgWorkspace,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        voicing.spacingLabel,
                        style: const TextStyle(
                          color: AppDarkTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _MiniBtn(
                    controller: controller,
                    icon: Icons.chevron_left_rounded,
                    tooltip: strings.prevInversionTip,
                    onTap: () => controller.stepInversion(selectedIndex, -1),
                  ),
                  const SizedBox(width: 4),
                  _MiniBtn(
                    controller: controller,
                    icon: Icons.chevron_right_rounded,
                    tooltip: strings.nextInversionTip,
                    onTap: () => controller.stepInversion(selectedIndex, 1),
                  ),
                  if (!isBasic) ...<Widget>[
                    const SizedBox(width: 6),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.spacingTip,
                      child: _TextBtn(
                        label: strings.spacingLabel,
                        icon: Icons.layers_outlined,
                        accent: AppDarkTheme.textSecondary,
                        onTap: () =>
                            controller.cycleVoicingVariant(selectedIndex),
                      ),
                    ),
                  ],
                  if (isManual) ...<Widget>[
                    const SizedBox(width: 6),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.autoOptimalTip,
                      child: _TextBtn(
                        label: strings.autoOptimalLabel(isBasic: isBasic),
                        icon: Icons.auto_fix_high_rounded,
                        accent: primaryAccent,
                        onTap: () =>
                            controller.setManualInversion(selectedIndex, null),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              children: <Widget>[
                // Plain-language connection summary (shown in both Basic and Advanced modes)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDarkTheme.bgWorkspace,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppDarkTheme.borderSubtle),
                  ),
                  child: Text(
                    strings.basicConnectionSummary(
                      isFirst: prevVoicing == null,
                      commonTones: voicing.commonToneCount,
                      totalDistance: voicing.totalSemitoneDistance,
                      bassNote: activeBassName,
                    ),
                    style: const TextStyle(
                      color: AppDarkTheme.textPrimary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (isBasic)
                  // Easy 1-click inversion cards
                  ...List<Widget>.generate(candidates.length, (int i) {
                    final ChordVoicing cand = candidates[i];
                    final bool active =
                        cand.inversionIndex == voicing.inversionIndex;
                    final String bassName = MidiPitch.pitchClassName(
                      cand.bassPc,
                      preferFlat: preferFlat,
                    );
                    final String invName =
                        strings.inversionLabel(cand.inversionIndex);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == candidates.length - 1 ? 0 : 7,
                      ),
                      child: ExplainedControl(
                        controller: controller,
                        explanation: strings.inversionChipTip(invName, bassName),
                        child: InkWell(
                          onTap: () => controller.setManualInversion(
                            selectedIndex,
                            cand.inversionIndex,
                          ),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? primaryAccent
                                      .withValues(alpha: 0.14)
                                  : AppDarkTheme.bgWorkspace,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: active
                                    ? primaryAccent
                                    : AppDarkTheme.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        invName,
                                        style: TextStyle(
                                          color: active
                                              ? primaryAccent
                                              : AppDarkTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        strings.basicInversionMetrics(
                                          cand.commonToneCount,
                                          cand.totalSemitoneDistance,
                                          isFirst: prevVoicing == null,
                                        ),
                                        style: const TextStyle(
                                          color: AppDarkTheme.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppDarkTheme.rootNoteHighlight
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    strings.bassNoteBadge(bassName),
                                    style: const TextStyle(
                                      color: AppDarkTheme.rootNoteHighlight,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                else ...<Widget>[
                  // Advanced Mode: Candidate inversions selector strip
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: candidates.map((ChordVoicing cand) {
                        final bool active =
                            cand.inversionIndex == voicing.inversionIndex;
                        final int bassPc = cand.bassPc;
                        final String bassName = MidiPitch.pitchClassName(
                          bassPc,
                          preferFlat: preferFlat,
                        );
                        final String invShort =
                            strings.shortInversionLabel(cand.inversionIndex);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ExplainedControl(
                            controller: controller,
                            explanation:
                                strings.inversionChipTip(invShort, bassName),
                            child: InkWell(
                              onTap: () => controller.setManualInversion(
                                selectedIndex,
                                cand.inversionIndex,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? primaryAccent
                                          .withValues(alpha: 0.15)
                                      : AppDarkTheme.bgWorkspace,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: active
                                        ? primaryAccent
                                        : AppDarkTheme.borderSubtle,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '$invShort (/$bassName)',
                                      style: TextStyle(
                                        color: active
                                            ? primaryAccent
                                            : AppDarkTheme.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      prevVoicing == null
                                          ? 'Cost ${cand.voiceLeadingCost.toStringAsFixed(1)}'
                                          : 'Δ ${cand.totalSemitoneDistance} st · ${cand.commonToneCount} ${strings.isEs ? "igual" : "common"}',
                                      style: const TextStyle(
                                        color: AppDarkTheme.textSecondary,
                                        fontSize: 11.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Summary stats bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      _StatPill(
                        label: strings.totalTravelLabel,
                        value: prevVoicing == null
                            ? strings.initialChordLabel
                            : strings.semitonesCount(
                                voicing.totalSemitoneDistance,
                              ),
                        color: primaryAccent,
                      ),
                      _StatPill(
                        label: strings.commonTonesLabel,
                        value: '${voicing.commonToneCount}',
                        color: AppDarkTheme.commonToneHighlight,
                      ),
                      _StatPill(
                        label: strings.stepwiseLabel,
                        value: '${voicing.stepwiseVoiceCount}',
                        color: AppDarkTheme.borrowedColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Voice-by-voice transition rows
                  ...List<Widget>.generate(voicing.motions.length, (int idx) {
                    final int revIdx = voicing.motions.length - 1 - idx;
                    final VoiceMotion motion = voicing.motions[revIdx];
                    final bool isBass = motion.voiceIndex == 0;
                    final String voiceName =
                        motion.voiceName(voicing.motions.length);

                    final String fromStr = motion.fromMidi == null
                        ? '—'
                        : MidiPitch.midiLabel(
                            motion.fromMidi!,
                            preferFlat: preferFlat,
                            includeMidiNumber: false,
                          );
                    final String toStr = MidiPitch.midiLabel(
                      motion.toMidi,
                      preferFlat: preferFlat,
                      includeMidiNumber: false,
                    );

                    final Color badgeColor = motion.fromMidi == null
                        ? AppDarkTheme.textMuted
                        : motion.isCommonTone
                            ? AppDarkTheme.commonToneHighlight
                            : motion.isStepwise
                                ? primaryAccent
                                : AppDarkTheme.subdominantColor;

                    final String badgeText = motion.fromMidi == null
                        ? (strings.isEs ? 'Base' : 'Anchor')
                        : motion.isCommonTone
                            ? (strings.isEs ? '0 st · Común' : '0 st · Common')
                            : '${MidiPitch.formatDelta(motion.deltaSemitones)} · ${motion.isStepwise ? (strings.isEs ? "Grado" : "Step") : (strings.isEs ? "Salto" : "Leap")}';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (idx > 0)
                          const Divider(
                            height: 1,
                            color: AppDarkTheme.borderSubtle,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 62,
                                child: Text(
                                  voiceName,
                                  style: TextStyle(
                                    color: isBass
                                        ? AppDarkTheme.rootNoteHighlight
                                        : AppDarkTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$fromStr  →  $toStr',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppDarkTheme.textPrimary,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppDarkTheme.bgWorkspace,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppDarkTheme.borderSubtle),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppDarkTheme.textMuted,
                fontSize: 10.5,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.controller,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final ExplorerController controller;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExplainedControl(
      controller: controller,
      explanation: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppDarkTheme.bgWorkspace,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppDarkTheme.borderSubtle),
          ),
          child: Icon(icon, size: 17, color: AppDarkTheme.textPrimary),
        ),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
