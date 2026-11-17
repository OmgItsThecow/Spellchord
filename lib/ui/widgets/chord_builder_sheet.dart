// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/interval_profile.dart';
import '../../core/models/midi_pitch.dart';
import '../theme/dark_theme.dart';

/// Opens a dark-themed dialog to construct or modify a chord.
/// In Basic Mode, raw MIDI interval math, extensions, and alterations are hidden.
Future<ChordSpec?> showChordBuilderDialog({
  required BuildContext context,
  required AppStrings strings,
  required bool isBasicMode,
  ChordSpec? initialChord,
  bool preferFlat = false,
}) {
  return showDialog<ChordSpec>(
    context: context,
    builder: (BuildContext ctx) => _ChordBuilderDialog(
      strings: strings,
      isBasicMode: isBasicMode,
      initialChord: initialChord,
      preferFlat: preferFlat,
    ),
  );
}

class _ChordBuilderDialog extends StatefulWidget {
  const _ChordBuilderDialog({
    required this.strings,
    required this.isBasicMode,
    required this.initialChord,
    required this.preferFlat,
  });

  final AppStrings strings;
  final bool isBasicMode;
  final ChordSpec? initialChord;
  final bool preferFlat;

  @override
  State<_ChordBuilderDialog> createState() => _ChordBuilderDialogState();
}

class _ChordBuilderDialogState extends State<_ChordBuilderDialog> {
  late int _rootPc;
  late TriadQuality _triad;
  late SeventhQuality _seventh;
  late Set<ChordExtension> _extensions;
  late Set<ChordAlteration> _alterations;

  @override
  void initState() {
    super.initState();
    final ChordSpec? init = widget.initialChord;
    _rootPc = init?.normalizedRootPc ?? 0;
    _triad = init?.triad ?? TriadQuality.major;
    _seventh = init?.seventh ?? SeventhQuality.major7;
    _extensions = Set<ChordExtension>.from(init?.extensions ?? const {});
    _alterations = Set<ChordAlteration>.from(init?.alterations ?? const {});
  }

  ChordSpec get _previewChord => ChordSpec(
        id: widget.initialChord?.id ??
            'chord_${DateTime.now().microsecondsSinceEpoch}',
        rootPc: _rootPc,
        triad: _triad,
        seventh: _seventh,
        extensions: Set<ChordExtension>.unmodifiable(_extensions),
        alterations: Set<ChordAlteration>.unmodifiable(_alterations),
        manualInversion: widget.initialChord?.manualInversion,
        voicingVariantIndex: widget.initialChord?.voicingVariantIndex ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.strings;
    final bool isBasic = widget.isBasicMode;
    final ChordSpec preview = _previewChord;
    final List<int> intervals = preview.intervals;
    final List<int> pcs = preview.pitchClasses;

    final List<TriadQuality> triadOptions = isBasic
        ? const <TriadQuality>[
            TriadQuality.major,
            TriadQuality.minor,
            TriadQuality.diminished,
            TriadQuality.sus4,
          ]
        : TriadQuality.values;

    final List<SeventhQuality> seventhOptions = isBasic
        ? const <SeventhQuality>[
            SeventhQuality.none,
            SeventhQuality.major7,
            SeventhQuality.dominant7,
            SeventhQuality.minor7,
          ]
        : SeventhQuality.values;

    return AlertDialog(
      backgroundColor: AppDarkTheme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppDarkTheme.borderSubtle),
      ),
      title: Row(
        children: <Widget>[
          Text(
            widget.initialChord == null
                ? strings.addChordTitle
                : strings.editChordTitle,
            style: const TextStyle(
              color: AppDarkTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppDarkTheme.tonicColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppDarkTheme.tonicColor.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              preview.baseSymbol(preferFlat: widget.preferFlat),
              style: const TextStyle(
                color: AppDarkTheme.tonicColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isBasic) ...<Widget>[
                // Live MIDI math strip (Advanced Mode only)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDarkTheme.bgWorkspace,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDarkTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${strings.semitoneIntervalsPrefix}: $intervals',
                        style: const TextStyle(
                          color: AppDarkTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${strings.pitchClassesPrefix}: $pcs  (${pcs.map((int pc) => MidiPitch.pitchClassName(pc, preferFlat: widget.preferFlat)).join(" - ")})',
                        style: const TextStyle(
                          color: AppDarkTheme.rootNoteHighlight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              _SectionLabel(
                isBasic ? strings.rootBasicSection : strings.rootPcSection,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(12, (int pc) {
                  final bool selected = pc == _rootPc;
                  final String name = MidiPitch.pitchClassName(
                    pc,
                    preferFlat: widget.preferFlat,
                  );
                  return _SelectableChip(
                    label: isBasic ? name : '$name ($pc)',
                    selected: selected,
                    accent: AppDarkTheme.rootNoteHighlight,
                    onTap: () => setState(() => _rootPc = pc),
                  );
                }),
              ),
              const SizedBox(height: 14),

              _SectionLabel(strings.triadSection),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: triadOptions.map((TriadQuality t) {
                  return _SelectableChip(
                    label: strings.triadName(t),
                    selected: _triad == t,
                    accent: AppDarkTheme.tonicColor,
                    onTap: () => setState(() => _triad = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              _SectionLabel(strings.seventhSection),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: seventhOptions.map((SeventhQuality s) {
                  return _SelectableChip(
                    label: strings.seventhName(s),
                    selected: _seventh == s,
                    accent: AppDarkTheme.borrowedColor,
                    onTap: () => setState(() {
                      _seventh = s;
                      if (s == SeventhQuality.halfDiminished7 ||
                          s == SeventhQuality.diminished7) {
                        _triad = TriadQuality.diminished;
                      }
                    }),
                  );
                }).toList(),
              ),

              if (!isBasic) ...<Widget>[
                const SizedBox(height: 14),
                _SectionLabel(strings.extensionsSection),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ChordExtension.values.map((ChordExtension ext) {
                    final bool active = _extensions.contains(ext);
                    return _SelectableChip(
                      label: _extensionLabel(ext),
                      selected: active,
                      accent: AppDarkTheme.secondaryDomColor,
                      onTap: () => setState(() {
                        if (active) {
                          _extensions.remove(ext);
                        } else {
                          _extensions.add(ext);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _SectionLabel(strings.alterationsSection),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ChordAlteration.values.map((ChordAlteration alt) {
                    final bool active = _alterations.contains(alt);
                    return _SelectableChip(
                      label: _alterationLabel(alt),
                      selected: active,
                      accent: AppDarkTheme.dominantColor,
                      onTap: () => setState(() {
                        if (active) {
                          _alterations.remove(alt);
                        } else {
                          _alterations.add(alt);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
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
          onPressed: () => Navigator.of(context).pop(preview),
          child: Text(
            strings.applyChordLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  static String _extensionLabel(ChordExtension e) {
    switch (e) {
      case ChordExtension.add9:
        return 'add9';
      case ChordExtension.ninth:
        return '9th';
      case ChordExtension.eleventh:
        return '11th';
      case ChordExtension.thirteenth:
        return '13th';
    }
  }

  static String _alterationLabel(ChordAlteration a) {
    switch (a) {
      case ChordAlteration.flat5:
        return 'b5';
      case ChordAlteration.sharp5:
        return '#5';
      case ChordAlteration.flat9:
        return 'b9';
      case ChordAlteration.sharp9:
        return '#9';
      case ChordAlteration.sharp11:
        return '#11';
      case ChordAlteration.flat13:
        return 'b13';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppDarkTheme.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? accent.withValues(alpha: 0.18) : AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? accent : AppDarkTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : AppDarkTheme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
