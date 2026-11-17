// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// Opens a dark-themed dialog to save the active progression as a named user
/// preset, or load / delete previously saved user presets.
Future<void> showSavePresetDialog({
  required BuildContext context,
  required ExplorerController controller,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => _SavePresetDialog(controller: controller),
  );
}

class _SavePresetDialog extends StatefulWidget {
  const _SavePresetDialog({required this.controller});

  final ExplorerController controller;

  @override
  State<_SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<_SavePresetDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    await widget.controller.saveUserPreset(name);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerController controller = widget.controller;
    final AppStrings strings = controller.strings;
    final bool preferFlat = controller.preferFlats;

    final String preview = controller.progression
        .map((ChordSpec c) => c.symbol(preferFlat: preferFlat))
        .join(' → ');

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final List<String> userPresets = controller.userPresetNames;

        return AlertDialog(
          backgroundColor: AppDarkTheme.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppDarkTheme.borderSubtle),
          ),
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.bookmark_add_outlined,
                size: 18,
                color: AppDarkTheme.tonicColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.savePresetDialogTitle,
                  style: const TextStyle(
                    color: AppDarkTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    strings.currentProgressionPreviewLabel,
                    style: const TextStyle(
                      color: AppDarkTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDarkTheme.bgWorkspace,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDarkTheme.borderSubtle),
                    ),
                    child: Text(
                      preview,
                      style: const TextStyle(
                        color: AppDarkTheme.tonicColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                      color: AppDarkTheme.textPrimary,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: strings.presetNameHint,
                      hintStyle: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: AppDarkTheme.bgWorkspace,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppDarkTheme.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppDarkTheme.tonicColor),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    strings.savedUserPresetsSectionLabel,
                    style: const TextStyle(
                      color: AppDarkTheme.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (userPresets.isEmpty)
                    Text(
                      strings.noSavedPresetsHint,
                      style: const TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else
                    Column(
                      children: userPresets.map((String name) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppDarkTheme.bgWorkspace,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppDarkTheme.borderSubtle),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: AppDarkTheme.subdominantColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppDarkTheme.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  controller.loadPresetProgression(name);
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppDarkTheme.tonicColor
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    strings.loadLabel,
                                    style: const TextStyle(
                                      color: AppDarkTheme.tonicColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: strings.deletePresetTip(name),
                                child: InkWell(
                                  onTap: () =>
                                      controller.deleteUserPreset(name),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: AppDarkTheme.dominantColor
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                strings.cancelLabel,
                style: const TextStyle(color: AppDarkTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDarkTheme.tonicColor,
                foregroundColor: AppDarkTheme.bgPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed:
                  _nameController.text.trim().isEmpty ? null : _submit,
              child: Text(
                strings.savePresetBtnLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}
