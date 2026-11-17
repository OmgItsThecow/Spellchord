import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../core/models/chord_voicing.dart';
import '../../core/models/midi_pitch.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import '../widgets/explained_control.dart';

/// Scalable, interactive 2-octave piano keyboard rendering exact MIDI pitches
/// of the active chord voicing, distinguishing Bass/Root from upper tones
/// and highlighting common tones from the preceding chord.
class PianoKeyboardVisualizer extends StatefulWidget {
  const PianoKeyboardVisualizer({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<PianoKeyboardVisualizer> createState() =>
      _PianoKeyboardVisualizerState();
}

class _PianoKeyboardVisualizerState extends State<PianoKeyboardVisualizer> {
  int _octaveOffset = 0;

  int _resolveKeyCount(double maxWidth, ChordVoicing? voicing) {
    if (maxWidth >= 520) {
      return 25;
    }
    if (voicing != null && voicing.midiNotes.length >= 2) {
      final int span = voicing.midiNotes.last - voicing.midiNotes.first;
      return math.max(15, math.min(25, span + 4));
    }
    return 15;
  }

  int _resolveStartMidi(ChordVoicing? voicing, int keyCount) {
    final int spanSteps = keyCount - 1;
    int base = 48 + (_octaveOffset * 12); // Default C3 (48)
    if (voicing != null && voicing.midiNotes.isNotEmpty) {
      final int minNote = voicing.midiNotes.first;
      final int maxNote = voicing.midiNotes.last;
      while (minNote < base && base >= 24) {
        base -= 12;
      }
      while (maxNote > base + spanSteps && base <= 84) {
        base += 12;
      }
      // Fine shift to F-anchor or centered white-key anchor if needed to fit voicing.
      if (minNote < base || maxNote > base + spanSteps) {
        final int candidateF = base - 7;
        if (candidateF >= 24 &&
            minNote >= candidateF &&
            maxNote <= candidateF + spanSteps) {
          base = candidateF;
        } else {
          int shifted = minNote - math.max(1, (spanSteps - (maxNote - minNote)) ~/ 2);
          shifted = shifted.clamp(24, math.max(24, 127 - spanSteps));
          while (shifted > 24 && MidiPitch.isBlackKey(shifted)) {
            shifted--;
          }
          base = shifted;
        }
      }
    }
    return base.clamp(24, math.max(24, 127 - spanSteps));
  }

  void _handleKeyTap(
    Offset localPosition,
    Size size,
    int startMidi,
    int keyCount,
  ) {
    final ChordSpec? chord = widget.controller.selectedChord;
    if (chord == null) {
      return;
    }

    final List<int> whiteKeys = <int>[];
    final List<int> blackKeys = <int>[];
    for (int i = 0; i < keyCount; i++) {
      final int midi = startMidi + i;
      if (MidiPitch.isBlackKey(midi)) {
        blackKeys.add(midi);
      } else {
        whiteKeys.add(midi);
      }
    }
    if (whiteKeys.isEmpty) {
      return;
    }

    const double headerHeight = 26.0;
    if (localPosition.dy < headerHeight) {
      return;
    }
    const double keyTop = headerHeight;
    final double keyHeight = size.height - keyTop;
    final double whiteWidth = size.width / whiteKeys.length;
    final double blackWidth = whiteWidth * 0.62;
    final double blackHeight = keyHeight * 0.58;

    int? tappedMidi;

    // Hit-test black keys first because they overlay white keys.
    if (localPosition.dy <= keyTop + blackHeight) {
      for (final int midi in blackKeys) {
        final int precedingWhiteIdx = whiteKeys.indexWhere((int w) => w == midi - 1);
        if (precedingWhiteIdx >= 0) {
          final double centerX = (precedingWhiteIdx + 1) * whiteWidth;
          final Rect blackRect = Rect.fromLTWH(
            centerX - blackWidth / 2,
            keyTop,
            blackWidth,
            blackHeight,
          );
          if (blackRect.contains(localPosition)) {
            tappedMidi = midi;
            break;
          }
        }
      }
    }

    if (tappedMidi == null) {
      final int wIdx =
          (localPosition.dx / whiteWidth).floor().clamp(0, whiteKeys.length - 1);
      tappedMidi = whiteKeys[wIdx];
    }

    // If the tapped MIDI note belongs to the chord, jump directly to the
    // inversion placing that pitch class in the bass!
    final int tappedPc = MidiPitch.pitchClass(tappedMidi);
    final int invIdx = chord.pitchClasses.indexOf(tappedPc);
    if (invIdx >= 0) {
      widget.controller.setManualInversion(
        widget.controller.selectedChordIndex,
        invIdx,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChordSpec? chord = widget.controller.selectedChord;
    final ChordVoicing? voicing = widget.controller.selectedPianoVoicing;
    final ChordVoicing? prevVoicing = widget.controller.previousPianoVoicing;
    final bool preferFlat = widget.controller.preferFlats;
    final bool isBasic = widget.controller.isBasicMode;
    final AppStrings strings = widget.controller.strings;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints outerConstraints) {
        final int keyCount = _resolveKeyCount(
          outerConstraints.maxWidth,
          voicing,
        );
        final int startMidi = _resolveStartMidi(voicing, keyCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Keyboard range & interaction hint bar
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '${strings.pianoRangeLabel}: ${MidiPitch.midiLabel(startMidi, preferFlat: preferFlat, includeMidiNumber: !isBasic)} – ${MidiPitch.midiLabel(startMidi + keyCount - 1, preferFlat: preferFlat, includeMidiNumber: !isBasic)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppDarkTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ExplainedControl(
                      controller: widget.controller,
                      explanation: strings.octaveDownTip,
                      child: InkWell(
                        onTap: () => setState(() => _octaveOffset--),
                        borderRadius: BorderRadius.circular(5),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: AppDarkTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    ExplainedControl(
                      controller: widget.controller,
                      explanation: strings.octaveUpTip,
                      child: InkWell(
                        onTap: () => setState(() => _octaveOffset++),
                        borderRadius: BorderRadius.circular(5),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppDarkTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  strings.pianoTapHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDarkTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scalable CustomPainter keyboard
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size canvasSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onTapDown: (TapDownDetails details) => _handleKeyTap(
                      details.localPosition,
                      canvasSize,
                      startMidi,
                      keyCount,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomPaint(
                        size: canvasSize,
                        painter: PianoKeyboardPainter(
                          startMidi: startMidi,
                          keyCount: keyCount,
                          activeVoicing: voicing,
                          previousVoicing: prevVoicing,
                          chord: chord,
                          preferFlat: preferFlat,
                          isBasicMode: isBasic,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// CustomPainter rendering a crisp dark-mode 2-octave keyboard with exact MIDI
/// highlights, root/bass differentiation, common-tone rings, and motion vectors.
class PianoKeyboardPainter extends CustomPainter {
  PianoKeyboardPainter({
    required this.startMidi,
    required this.keyCount,
    required this.activeVoicing,
    required this.previousVoicing,
    required this.chord,
    required this.preferFlat,
    this.isBasicMode = false,
  });

  final int startMidi;
  final int keyCount;
  final ChordVoicing? activeVoicing;
  final ChordVoicing? previousVoicing;
  final ChordSpec? chord;
  final bool preferFlat;
  final bool isBasicMode;

  @override
  void paint(Canvas canvas, Size size) {
    final List<int> whiteKeys = <int>[];
    final List<int> blackKeys = <int>[];
    for (int i = 0; i < keyCount; i++) {
      final int midi = startMidi + i;
      if (MidiPitch.isBlackKey(midi)) {
        blackKeys.add(midi);
      } else {
        whiteKeys.add(midi);
      }
    }

    if (whiteKeys.isEmpty) {
      return;
    }

    const double headerHeight = 26.0;
    const double keyTop = headerHeight;
    final double keyHeight = math.max(0.0, size.height - keyTop);
    if (keyHeight < 12.0 || size.width < 40.0) {
      return;
    }
    final double whiteWidth = size.width / whiteKeys.length;
    final double blackWidth = whiteWidth * 0.62;
    final double blackHeight = keyHeight * 0.58;

    // Background strip for voice-leading vector arcs
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, headerHeight),
      Paint()..color = AppDarkTheme.bgWorkspace,
    );

    final Set<int> activeSet =
        activeVoicing?.midiNotes.toSet() ?? const <int>{};
    final Set<int> prevSet =
        previousVoicing?.midiNotes.toSet() ?? const <int>{};
    final int? bassMidi = activeVoicing?.bassMidi;
    final int? rootPc = chord?.normalizedRootPc;

    final Map<int, double> keyCenterX = <int, double>{};

    // 1. Draw white keys
    for (int i = 0; i < whiteKeys.length; i++) {
      final int midi = whiteKeys[i];
      final double x = i * whiteWidth;
      keyCenterX[midi] = x + whiteWidth / 2;

      final bool isActive = activeSet.contains(midi);
      final bool isBass = midi == bassMidi;
      final bool isRoot = rootPc != null && MidiPitch.pitchClass(midi) == rootPc;
      final bool isBassOrRoot = isActive && (isBass || isRoot);
      final bool isCommon = isActive && prevSet.contains(midi);

      final RRect keyRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x + 1, keyTop, whiteWidth - 2, keyHeight - 1),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      );

      final Color fillColor;
      if (isBassOrRoot) {
        fillColor = AppDarkTheme.rootNoteHighlight.withValues(alpha: 0.90);
      } else if (isActive) {
        fillColor = AppDarkTheme.upperNoteHighlight.withValues(alpha: 0.85);
      } else {
        fillColor = const Color(0xFF23232C);
      }

      canvas.drawRRect(keyRect, Paint()..color = fillColor);
      canvas.drawRRect(
        keyRect,
        Paint()
          ..color = AppDarkTheme.bgPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Subtle C-octave guide label on inactive C keys
      if (!isActive && MidiPitch.pitchClass(midi) == 0) {
        _drawCenteredText(
          canvas,
          MidiPitch.midiLabel(midi, preferFlat: preferFlat, includeMidiNumber: false),
          Offset(x + whiteWidth / 2, keyTop + keyHeight - 16),
          const TextStyle(
            color: AppDarkTheme.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      if (isActive) {
        _drawActiveKeyLabels(
          canvas: canvas,
          midi: midi,
          centerX: x + whiteWidth / 2,
          bottomY: keyTop + keyHeight - 14,
          isBass: isBass,
          isRoot: isRoot,
          isCommon: isCommon,
          compact: whiteWidth < 36,
        );
      }
    }

    // 2. Draw black keys
    for (final int midi in blackKeys) {
      final int prevWhiteIdx = whiteKeys.indexWhere((int w) => w == midi - 1);
      if (prevWhiteIdx < 0) {
        continue;
      }
      final double centerX = (prevWhiteIdx + 1) * whiteWidth;
      keyCenterX[midi] = centerX;

      final bool isActive = activeSet.contains(midi);
      final bool isBass = midi == bassMidi;
      final bool isRoot = rootPc != null && MidiPitch.pitchClass(midi) == rootPc;
      final bool isBassOrRoot = isActive && (isBass || isRoot);
      final bool isCommon = isActive && prevSet.contains(midi);

      final RRect blackRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX - blackWidth / 2,
          keyTop,
          blackWidth,
          blackHeight,
        ),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );

      final Color fillColor;
      if (isBassOrRoot) {
        fillColor = AppDarkTheme.rootNoteHighlight;
      } else if (isActive) {
        fillColor = AppDarkTheme.upperNoteHighlight;
      } else {
        fillColor = const Color(0xFF0E0E13);
      }

      canvas.drawRRect(blackRect, Paint()..color = fillColor);
      canvas.drawRRect(
        blackRect,
        Paint()
          ..color = isActive ? AppDarkTheme.bgPrimary : const Color(0xFF2D2D38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      if (isActive) {
        _drawActiveKeyLabels(
          canvas: canvas,
          midi: midi,
          centerX: centerX,
          bottomY: keyTop + blackHeight - 13,
          isBass: isBass,
          isRoot: isRoot,
          isCommon: isCommon,
          compact: true,
        );
      }
    }

    // 3. Draw voice-leading motion vectors in the top strip
    if (activeVoicing != null && previousVoicing != null) {
      for (final VoiceMotion m in activeVoicing!.motions) {
        if (m.fromMidi == null) {
          continue;
        }
        final double? fromX = keyCenterX[m.fromMidi!];
        final double? toX = keyCenterX[m.toMidi];
        if (fromX == null || toX == null) {
          continue;
        }

        final Color lineColor = m.isCommonTone
            ? AppDarkTheme.commonToneHighlight
            : m.isStepwise
                ? AppDarkTheme.tonicColor
                : AppDarkTheme.subdominantColor;

        if (m.isCommonTone) {
          canvas.drawCircle(
            Offset(toX, headerHeight / 2),
            4.5,
            Paint()..color = lineColor,
          );
        } else {
          final Path arc = Path()
            ..moveTo(fromX, headerHeight - 4)
            ..quadraticBezierTo(
              (fromX + toX) / 2,
              4,
              toX,
              headerHeight - 4,
            );
          canvas.drawPath(
            arc,
            Paint()
              ..color = lineColor.withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
          canvas.drawCircle(
            Offset(toX, headerHeight - 4),
            3.0,
            Paint()..color = lineColor,
          );
        }
      }
    }
  }

  void _drawActiveKeyLabels({
    required Canvas canvas,
    required int midi,
    required double centerX,
    required double bottomY,
    required bool isBass,
    required bool isRoot,
    required bool isCommon,
    required bool compact,
  }) {
    final String noteName = MidiPitch.midiLabel(
      midi,
      preferFlat: preferFlat,
      includeMidiNumber: false,
    );

    if (isCommon) {
      canvas.drawCircle(
        Offset(centerX, bottomY - (compact ? 24 : 34)),
        4.5,
        Paint()..color = AppDarkTheme.commonToneHighlight,
      );
      canvas.drawCircle(
        Offset(centerX, bottomY - (compact ? 24 : 34)),
        4.5,
        Paint()
          ..color = AppDarkTheme.bgPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    if (isBass || isRoot) {
      final String tag = isBass && isRoot
          ? 'R/B'
          : isBass
              ? 'BASS'
              : 'ROOT';
      _drawCenteredText(
        canvas,
        tag,
        Offset(centerX, bottomY - (compact ? 14 : 20)),
        const TextStyle(
          color: Color(0xFF14110B),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    _drawCenteredText(
      canvas,
      (compact || isBasicMode) ? noteName : '$noteName\n$midi',
      Offset(centerX, bottomY - (compact ? 2 : 4)),
      const TextStyle(
        color: Color(0xFF0D1114),
        fontSize: 11.0,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }

  void _drawCenteredText(
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
  bool shouldRepaint(covariant PianoKeyboardPainter oldDelegate) {
    return oldDelegate.startMidi != startMidi ||
        oldDelegate.keyCount != keyCount ||
        oldDelegate.activeVoicing != activeVoicing ||
        oldDelegate.previousVoicing != previousVoicing ||
        oldDelegate.chord != chord ||
        oldDelegate.preferFlat != preferFlat ||
        oldDelegate.isBasicMode != isBasicMode;
  }
}
