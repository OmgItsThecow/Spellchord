// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/models/midi_pitch.dart';
import '../../core/models/scale_mode.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import 'explained_control.dart';
import 'save_preset_dialog.dart';

/// Top control bar displaying tonal center detection/locking, preset selector,
/// Basic/Advanced complexity toggle, language toggle, and global voice-leading reset.
class KeyCenterBar extends StatelessWidget {
  const KeyCenterBar({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final bool preferFlat = controller.preferFlats;
    final int activeTonic = controller.activeKeyTonicPc;
    final ScaleMode activeMode = controller.activeKeyMode;
    final bool isLocked = controller.isKeyLocked;
    final bool isBasic = controller.isBasicMode;
    final AppStrings strings = controller.strings;

    final ScaleMode dropdownMode = isBasic
        ? (activeMode.isMinorFamily ? ScaleMode.aeolian : ScaleMode.ionian)
        : activeMode;

    final List<ScaleMode> availableModes = isBasic
        ? const <ScaleMode>[ScaleMode.ionian, ScaleMode.aeolian]
        : ScaleMode.values;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppDarkTheme.bgWorkspace,
        border: Border(
          bottom: BorderSide(color: AppDarkTheme.borderSubtle),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: <Widget>[
          // Brand & subtitle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppDarkTheme.tonicColor.withValues(alpha: 0.4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      strings.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      isBasic ? strings.appSubtitleBasic : strings.appSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Controls cluster: Mode Toggle, Language Toggle, Key Center, Presets, Optimal
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              // Basic vs Advanced Mode segmented toggle
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: AppDarkTheme.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDarkTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.switchToBasicTip,
                      child: _ModeSwitchPill(
                        label: strings.basicModeLabel,
                        selected: isBasic,
                        accent: AppDarkTheme.tonicColor,
                        onTap: () =>
                            controller.setComplexityMode(ComplexityMode.basic),
                      ),
                    ),
                    const SizedBox(width: 3),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.switchToAdvancedTip,
                      child: _ModeSwitchPill(
                        label: strings.advancedModeLabel,
                        selected: !isBasic,
                        accent: AppDarkTheme.borrowedColor,
                        onTap: () => controller
                            .setComplexityMode(ComplexityMode.advanced),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Language Switcher (EN / ES)
              ExplainedControl(
                controller: controller,
                explanation: strings.toggleLanguageTip,
                child: InkWell(
                  onTap: controller.toggleLanguage,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: AppDarkTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDarkTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.translate_rounded,
                          size: 14,
                          color: AppDarkTheme.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          controller.language == AppLanguage.en ? 'EN' : 'ES',
                          style: const TextStyle(
                            color: AppDarkTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Audio mute/unmute toggle
              ExplainedControl(
                controller: controller,
                explanation: strings.soundToggleTip(controller.soundEnabled),
                child: InkWell(
                  onTap: controller.toggleSound,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: controller.soundEnabled
                          ? AppDarkTheme.tonicColor.withValues(alpha: 0.14)
                          : AppDarkTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.soundEnabled
                            ? AppDarkTheme.tonicColor.withValues(alpha: 0.45)
                            : AppDarkTheme.borderSubtle,
                      ),
                    ),
                    child: Icon(
                      controller.soundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 15,
                      color: controller.soundEnabled
                          ? AppDarkTheme.tonicColor
                          : AppDarkTheme.textMuted,
                    ),
                  ),
                ),
              ),

              // Key center detection & locking controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDarkTheme.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLocked
                        ? AppDarkTheme.subdominantColor.withValues(alpha: 0.55)
                        : AppDarkTheme.borderSubtle,
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      isBasic
                          ? strings.keyBasicLabel
                          : (isLocked ? strings.keyLocked : strings.keyAuto),
                      style: TextStyle(
                        color: isLocked
                            ? AppDarkTheme.subdominantColor
                            : AppDarkTheme.tonicColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.keyRootTip,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: activeTonic,
                          isDense: true,
                          dropdownColor: AppDarkTheme.cardElevated,
                          style: const TextStyle(
                            color: AppDarkTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          items: List<DropdownMenuItem<int>>.generate(
                            12,
                            (int pc) => DropdownMenuItem<int>(
                              value: pc,
                              child: Text(
                                MidiPitch.pitchClassName(
                                  pc,
                                  preferFlat: preferFlat,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (int? val) {
                            if (val != null) {
                              controller.setLockedKey(val, dropdownMode);
                            }
                          },
                        ),
                      ),
                    ),
                    ExplainedControl(
                      controller: controller,
                      explanation: strings.keyScaleTip,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 185),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ScaleMode>(
                            value: dropdownMode,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: AppDarkTheme.cardElevated,
                            style: const TextStyle(
                              color: AppDarkTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            items: availableModes
                                .map(
                                  (ScaleMode mode) =>
                                      DropdownMenuItem<ScaleMode>(
                                    value: mode,
                                    child: Text(
                                      isBasic
                                          ? strings.basicScaleLabel(mode)
                                          : mode.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (ScaleMode? mode) {
                              if (mode != null) {
                                controller.setLockedKey(activeTonic, mode);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    if (!isBasic)
                      ExplainedControl(
                        controller: controller,
                        explanation: strings.keyLockTip(isLocked),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: controller.toggleKeyLock,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 16,
                              color: isLocked
                                  ? AppDarkTheme.subdominantColor
                                  : AppDarkTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Progression preset switcher
              ExplainedControl(
                controller: controller,
                explanation: strings.presetTip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDarkTheme.cardSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDarkTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        strings.presetLabel,
                        style: const TextStyle(
                          color: AppDarkTheme.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                strings.loadProgressionHint,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppDarkTheme.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                              isDense: true,
                              dropdownColor: AppDarkTheme.cardElevated,
                              style: const TextStyle(
                                color: AppDarkTheme.textPrimary,
                                fontSize: 12.5,
                              ),
                              items: controller.allPresetNames
                                  .map(
                                    (String name) => DropdownMenuItem<String>(
                                      value: name,
                                      child: Text(
                                        controller.isUserPreset(name)
                                            ? '★ $name'
                                            : strings.presetDisplayName(name),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              value: (controller.activePresetName != null &&
                                      controller.allPresetNames.contains(
                                          controller.activePresetName))
                                  ? controller.activePresetName
                                  : null,
                              onChanged: (String? name) {
                                if (name != null) {
                                  controller.loadPresetProgression(name);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save / manage custom user presets button
              ExplainedControl(
                controller: controller,
                explanation: strings.savePresetTip,
                child: InkWell(
                  onTap: () => showSavePresetDialog(
                    context: context,
                    controller: controller,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppDarkTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppDarkTheme.subdominantColor
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.bookmark_add_outlined,
                          size: 14,
                          color: AppDarkTheme.subdominantColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          strings.savePresetLabel,
                          style: const TextStyle(
                            color: AppDarkTheme.subdominantColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Global total movement + reset button (Advanced Mode)
              if (!isBasic)
                ExplainedControl(
                  controller: controller,
                  explanation: strings.optimalVlTip(isBasic: isBasic),
                  child: InkWell(
                    onTap: controller.resetAllInversionsToOptimal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppDarkTheme.tonicColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              AppDarkTheme.tonicColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 14,
                            color: AppDarkTheme.tonicColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            strings.optimalVlLabel(
                              controller.totalProgressionSemitoneCost,
                              isBasic: isBasic,
                            ),
                            style: const TextStyle(
                              color: AppDarkTheme.tonicColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
    );
  }
}

class _ModeSwitchPill extends StatelessWidget {
  const _ModeSwitchPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                selected ? accent.withValues(alpha: 0.55) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : AppDarkTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
