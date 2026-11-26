import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/audio/windows_midi_drag.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/chord_voicing.dart';
import '../../core/models/harmonic_function.dart';
import '../../core/models/interval_profile.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import 'chord_builder_sheet.dart';
import 'explained_control.dart';

/// Horizontal interactive timeline of chords adapting between Basic Mode
/// (note names & plain-language roles) and Advanced Mode (Roman numerals & voicings).
class ProgressionTimeline extends StatefulWidget {
  const ProgressionTimeline({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<ProgressionTimeline> createState() => _ProgressionTimelineState();
}

class _ProgressionTimelineState extends State<ProgressionTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final double delta = event.scrollDelta.dx != 0
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      if (delta == 0) {
        return;
      }
      final ScrollPosition pos = _scrollController.position;
      if (pos.maxScrollExtent <= 0) {
        return;
      }
      final double target =
          (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
      if (target != pos.pixels) {
        _scrollController.jumpTo(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerController controller = widget.controller;
    final List<ChordSpec> progression = controller.progression;
    final List<HarmonicAnalysisResult> analyses = controller.analyses;
    final List<ChordVoicing> voicings = controller.pianoVoicings;
    final bool preferFlat = controller.preferFlats;
    final bool isBasic = controller.isBasicMode;
    final AppStrings strings = controller.strings;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppDarkTheme.bgPrimary,
        border: Border(
          bottom: BorderSide(color: AppDarkTheme.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      strings.progressionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    strings.chordsCount(progression.length),
                    style: const TextStyle(
                      color: AppDarkTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.playChordTip,
                    child: _ActionPill(
                      icon: Icons.volume_up_rounded,
                      label: strings.playChordLabel,
                      accent: AppDarkTheme.commonToneHighlight,
                      onTap: () => controller.playSelectedChord(force: true),
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation:
                        strings.playProgressionTip(controller.isPlayingProgression),
                    child: _ActionPill(
                      icon: controller.isPlayingProgression
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      label: controller.isPlayingProgression
                          ? strings.stopPlaybackLabel
                          : strings.playAllLabel,
                      accent: controller.isPlayingProgression
                          ? AppDarkTheme.subdominantColor
                          : AppDarkTheme.borrowedColor,
                      onTap: controller.togglePlayProgression,
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.editSelectedTip,
                    child: _ActionPill(
                      icon: Icons.edit_outlined,
                      label: strings.editSelectedLabel,
                      accent: AppDarkTheme.textSecondary,
                      onTap: () async {
                        final ChordSpec? current = controller.selectedChord;
                        if (current == null) {
                          return;
                        }
                        final ChordSpec? edited = await showChordBuilderDialog(
                          context: context,
                          strings: strings,
                          isBasicMode: isBasic,
                          initialChord: current,
                          preferFlat: preferFlat,
                        );
                        if (edited != null) {
                          controller.updateChordAt(
                            controller.selectedChordIndex,
                            edited,
                          );
                        }
                      },
                    ),
                  ),
                  ExplainedControl(
                    controller: controller,
                    explanation: strings.addChordTip,
                    child: _ActionPill(
                      icon: Icons.add_rounded,
                      label: strings.addChordLabel,
                      accent: AppDarkTheme.accentFor(
                        isPiano:
                            controller.visualizerMode == VisualizerMode.piano,
                      ),
                      onTap: () async {
                        final ChordSpec? created = await showChordBuilderDialog(
                          context: context,
                          strings: strings,
                          isBasicMode: isBasic,
                          preferFlat: preferFlat,
                        );
                        if (created != null) {
                          controller.addChord(created);
                        }
                      },
                    ),
                  ),
                  if (WindowsMidiDrag.isSupported)
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.dragProgressionMidiTip,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: GestureDetector(
                          onPanStart: (_) {
                            final String preset =
                                controller.activePresetName ?? 'Progression';
                            WindowsMidiDrag.startDrag(
                              chordMidiNotes: controller.allActiveVoicingNotes(),
                              suggestedName: 'Spellchord_$preset',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppDarkTheme.accentFor(
                                isPiano: controller.visualizerMode ==
                                    VisualizerMode.piano,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: AppDarkTheme.accentFor(
                                  isPiano: controller.visualizerMode ==
                                      VisualizerMode.piano,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 14,
                                  color: AppDarkTheme.accentFor(
                                    isPiano: controller.visualizerMode ==
                                        VisualizerMode.piano,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  strings.dragProgressionMidiLabel,
                                  style: TextStyle(
                                    color: AppDarkTheme.accentFor(
                                      isPiano: controller.visualizerMode ==
                                          VisualizerMode.piano,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isCompact = constraints.maxWidth < 600;
              return SizedBox(
                height: (isBasic ? 124 : (isCompact ? 158 : 154)) + 12,
                child: Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: const <PointerDeviceKind>{
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: progression.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ChordSpec chord = progression[index];
                          final HarmonicAnalysisResult analysis =
                              analyses[index];
                          final ChordVoicing voicing = voicings[index];
                          final bool isSelected =
                              index == controller.selectedChordIndex;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (index > 0)
                                isBasic
                                    ? const SizedBox(width: 8)
                                    : _TransitionConnector(
                                        strings: strings,
                                        totalDistance:
                                            voicing.totalSemitoneDistance,
                                        commonTones: voicing.commonToneCount,
                                        isCompact: isCompact,
                                      ),
                              _ChordCard(
                                controller: controller,
                                strings: strings,
                                isBasicMode: isBasic,
                                isCompact: isCompact,
                                index: index,
                                totalCount: progression.length,
                                chord: chord,
                                analysis: analysis,
                                voicing: voicing,
                                isSelected: isSelected,
                                preferFlat: preferFlat,
                                onSelect: () => controller.selectChord(index),
                                onEdit: () async {
                                  final ChordSpec? edited =
                                      await showChordBuilderDialog(
                                    context: context,
                                    strings: strings,
                                    isBasicMode: isBasic,
                                    initialChord: chord,
                                    preferFlat: preferFlat,
                                  );
                                  if (edited != null) {
                                    controller.updateChordAt(index, edited);
                                  }
                                },
                                onDuplicate: () =>
                                    controller.duplicateChordAt(index),
                                onNextInversion: () =>
                                    controller.stepInversion(index, 1),
                                onFlipQuality:
                                    (chord.triad == TriadQuality.major ||
                                            chord.triad == TriadQuality.minor)
                                        ? () => controller
                                            .toggleChordQualityAt(index)
                                        : null,
                                onInsertSecDom: () => controller
                                    .insertSecondaryDominantBefore(index),
                                onDelete: progression.length > 1
                                    ? () => controller.removeChordAt(index)
                                    : null,
                                onMoveLeft: index > 0
                                    ? () => controller.reorderChord(
                                          index,
                                          index - 1,
                                        )
                                    : null,
                                onMoveRight: index < progression.length - 1
                                    ? () => controller.reorderChord(
                                          index,
                                          index + 1,
                                        )
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChordCard extends StatelessWidget {
  const _ChordCard({
    required this.controller,
    required this.strings,
    required this.isBasicMode,
    required this.isCompact,
    required this.index,
    required this.totalCount,
    required this.chord,
    required this.analysis,
    required this.voicing,
    required this.isSelected,
    required this.preferFlat,
    required this.onSelect,
    required this.onEdit,
    required this.onDuplicate,
    required this.onNextInversion,
    required this.onFlipQuality,
    required this.onInsertSecDom,
    required this.onDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  final ExplorerController controller;
  final AppStrings strings;
  final bool isBasicMode;
  final bool isCompact;
  final int index;
  final int totalCount;
  final ChordSpec chord;
  final HarmonicAnalysisResult analysis;
  final ChordVoicing voicing;
  final bool isSelected;
  final bool preferFlat;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onNextInversion;
  final VoidCallback? onFlipQuality;
  final VoidCallback onInsertSecDom;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset pos,
  ) async {
    onSelect();
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final int domRootPc = (chord.normalizedRootPc + 7) % 12;
    final String domSymbol =
        '${MidiPitch.pitchClassName(domRootPc, preferFlat: preferFlat)}7';

    final String? action = await showMenu<String>(
      context: context,
      color: AppDarkTheme.cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppDarkTheme.borderSubtle),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        _ctxItem(
          'duplicate',
          Icons.content_copy_rounded,
          strings.ctxDuplicateChord,
        ),
        _ctxItem('edit', Icons.edit_rounded, strings.ctxEditChord),
        _ctxItem('play', Icons.play_arrow_rounded, strings.ctxPlayChord),
        _ctxItem('invert', Icons.swap_vert_rounded, strings.ctxNextInversion),
        const PopupMenuDivider(height: 8),
        if (onFlipQuality != null)
          _ctxItem(
            'flip',
            Icons.contrast_rounded,
            chord.triad == TriadQuality.major
                ? strings.ctxFlipToMinor
                : strings.ctxFlipToMajor,
          ),
        _ctxItem(
          'secdom',
          Icons.auto_awesome_rounded,
          strings.ctxInsertSecDom(domSymbol),
        ),
        if (onMoveLeft != null || onMoveRight != null)
          const PopupMenuDivider(height: 8),
        if (onMoveLeft != null)
          _ctxItem('left', Icons.chevron_left_rounded, strings.ctxMoveLeft),
        if (onMoveRight != null)
          _ctxItem('right', Icons.chevron_right_rounded, strings.ctxMoveRight),
        if (onDelete != null) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(height: 8),
          _ctxItem(
            'delete',
            Icons.delete_outline_rounded,
            strings.ctxDeleteChord,
            color: AppDarkTheme.dominantColor,
          ),
        ],
      ],
    );

    switch (action) {
      case 'duplicate':
        onDuplicate();
        break;
      case 'edit':
        onEdit();
        break;
      case 'play':
        controller.playSelectedChord(force: true);
        break;
      case 'invert':
        onNextInversion();
        break;
      case 'flip':
        onFlipQuality?.call();
        break;
      case 'secdom':
        onInsertSecDom();
        break;
      case 'left':
        onMoveLeft?.call();
        break;
      case 'right':
        onMoveRight?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }

  PopupMenuItem<String> _ctxItem(
    String value,
    IconData icon,
    String label, {
    Color color = AppDarkTheme.textPrimary,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPiano = controller.visualizerMode == VisualizerMode.piano;
    final Color accent =
        AppDarkTheme.colorForCategory(analysis.category, isPiano: isPiano);
    final Color upperNoteColor = AppDarkTheme.accentFor(isPiano: isPiano);
    final bool isManualInv = chord.manualInversion != null;
    final String displaySymbol = chord.symbol(
      preferFlat: preferFlat,
      activeInversion: voicing.inversionIndex,
    );

    final String roleLabel = isBasicMode
        ? strings.basicCategoryLabel(analysis.category)
        : '${analysis.functionLabel} · ${strings.basicCategoryLabel(analysis.category)}';

    return ExplainedControl(
      controller: controller,
      explanation: strings.chordCardTip(displaySymbol, analysis.romanNumeral),
      child: GestureDetector(
        onTap: onSelect,
        onDoubleTap: onEdit,
        onSecondaryTapDown: (TapDownDetails details) =>
            _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: isCompact ? 132 : 196,
          padding: EdgeInsets.all(isCompact ? 8 : 10),
          decoration: BoxDecoration(
            color:
                isSelected ? AppDarkTheme.cardElevated : AppDarkTheme.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : AppDarkTheme.borderSubtle,
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Roman numeral, function badge, and Android/touch menu button
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 5 : 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      analysis.romanNumeral,
                      style: TextStyle(
                        color: accent,
                        fontSize: isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 4 : 6),
                  Expanded(
                    child: Text(
                      roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: isCompact ? 10.5 : 11.5,
                      ),
                    ),
                  ),
                  if (WindowsMidiDrag.isSupported)
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.dragChordMidiTip,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: GestureDetector(
                          onPanStart: (_) {
                            final List<int> notes =
                                controller.activeVoicingNotesAt(index);
                            if (notes.isNotEmpty) {
                              WindowsMidiDrag.startDrag(
                                chordMidiNotes: <List<int>>[notes],
                                suggestedName: 'Spellchord_$displaySymbol',
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: isCompact ? 14 : 15,
                              color: AppDarkTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isSelected)
                    Builder(
                      builder: (BuildContext btnCtx) => _TinyIconButton(
                        controller: controller,
                        icon: Icons.more_vert_rounded,
                        tooltip: strings.ctxMoreOptionsTip,
                        compact: isCompact,
                        onTap: () {
                          final RenderBox box =
                              btnCtx.findRenderObject()! as RenderBox;
                          final Offset anchor = box.localToGlobal(
                            Offset(0, box.size.height),
                          );
                          _showContextMenu(btnCtx, anchor);
                        },
                      ),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 5 : 8),

              // Chord symbol & quick controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      displaySymbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: isCompact ? 16 : 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (isSelected) ...<Widget>[
                    if (onMoveLeft != null)
                      _TinyIconButton(
                        controller: controller,
                        icon: Icons.chevron_left_rounded,
                        onTap: onMoveLeft!,
                        tooltip: strings.moveLeftTip,
                        compact: isCompact,
                      ),
                    if (onMoveRight != null)
                      _TinyIconButton(
                        controller: controller,
                        icon: Icons.chevron_right_rounded,
                        onTap: onMoveRight!,
                        tooltip: strings.moveRightTip,
                        compact: isCompact,
                      ),
                    if (onDelete != null)
                      _TinyIconButton(
                        controller: controller,
                        icon: Icons.close_rounded,
                        onTap: onDelete!,
                        tooltip: strings.removeChordTip,
                        compact: isCompact,
                      ),
                  ],
                ],
              ),
              const Spacer(),

              // Inversion badge (Advanced Mode)
              if (!isBasicMode) ...<Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isManualInv
                              ? AppDarkTheme.subdominantColor
                                  .withValues(alpha: 0.15)
                              : AppDarkTheme.bgWorkspace,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isManualInv
                                ? AppDarkTheme.subdominantColor
                                    .withValues(alpha: 0.5)
                                : AppDarkTheme.borderSubtle,
                          ),
                        ),
                        child: Text(
                          '${strings.shortInversionLabel(voicing.inversionIndex)} · ${isManualInv ? strings.manualTag : strings.autoTag}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isManualInv
                                ? AppDarkTheme.subdominantColor
                                : AppDarkTheme.textSecondary,
                            fontSize: isCompact ? 10.0 : 11.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 4 : 6),
              ],

              // Note names (Basic: pitch class, Advanced: note + octave, never raw MIDI)
              Wrap(
                spacing: isCompact ? 3 : 4,
                runSpacing: isCompact ? 2 : 3,
                children: <Widget>[
                  for (int i = 0; i < voicing.midiNotes.length; i++)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 4 : 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: (i == 0
                                ? AppDarkTheme.rootNoteHighlight
                                : upperNoteColor)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBasicMode
                            ? MidiPitch.pitchClassName(
                                MidiPitch.pitchClass(voicing.midiNotes[i]),
                                preferFlat: preferFlat,
                              )
                            : MidiPitch.midiLabel(
                                voicing.midiNotes[i],
                                preferFlat: preferFlat,
                                includeMidiNumber: false,
                              ),
                        style: TextStyle(
                          color: i == 0
                              ? AppDarkTheme.rootNoteHighlight
                              : upperNoteColor,
                          fontSize: isCompact
                              ? (isBasicMode ? 10.5 : 10.0)
                              : (isBasicMode ? 11.5 : 10.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransitionConnector extends StatelessWidget {
  const _TransitionConnector({
    required this.strings,
    required this.totalDistance,
    required this.commonTones,
    required this.isCompact,
  });

  final AppStrings strings;
  final int totalDistance;
  final int commonTones;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final Color distColor = totalDistance <= 4
        ? AppDarkTheme.commonToneHighlight
        : (totalDistance <= 8
            ? AppDarkTheme.tonicColor
            : AppDarkTheme.subdominantColor);

    return Container(
      width: isCompact ? 38 : 64,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$totalDistance st',
              style: TextStyle(
                color: distColor,
                fontSize: isCompact ? 11.0 : 12.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 1.5,
            color: AppDarkTheme.borderSubtle,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              strings.keepCountLabel(commonTones),
              style: TextStyle(
                color: AppDarkTheme.textMuted,
                fontSize: isCompact ? 10.0 : 11.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppDarkTheme.cardSurface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppDarkTheme.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.controller,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.compact = false,
  });

  final ExplorerController controller;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ExplainedControl(
      controller: controller,
      explanation: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(compact ? 1 : 2),
          child: Icon(
            icon,
            size: compact ? 14 : 16,
            color: AppDarkTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
