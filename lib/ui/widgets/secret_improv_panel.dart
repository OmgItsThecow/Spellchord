// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/engine/improvisation_scale_engine.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/chord_spec.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// Secret panel unlocked only when the user taps "Keep rocking the world" at
/// startup and subsequently saves a custom preset. Displays 1–2 overarching
/// improvisation scales plus a chord-specific inflection and their aesthetic
/// experience narratives.
class SecretImprovPanel extends StatelessWidget {
  const SecretImprovPanel({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    final ImprovisationInsightResult? insight = controller.improvInsight;
    final ChordSpec? selected = controller.selectedChord;
    final AppStrings strings = controller.strings;
    final bool preferFlat = controller.preferFlats;

    if (insight == null) {
      return const SizedBox.shrink();
    }

    final String chordSymbol =
        selected?.symbol(preferFlat: preferFlat) ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDarkTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppDarkTheme.subdominantColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppDarkTheme.subdominantColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.secretImprovTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDarkTheme.subdominantColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.secretImprovSubtitle,
            style: const TextStyle(
              color: AppDarkTheme.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    strings.overarchingScalesHeader,
                    style: const TextStyle(
                      color: AppDarkTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...insight.progressionScales.map(
                    (ImprovisationScaleRecommendation rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScaleInsightCard(
                        recommendation: rec,
                        accent: AppDarkTheme.tonicColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.selectedChordScaleHeader(chordSymbol),
                    style: const TextStyle(
                      color: AppDarkTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ScaleInsightCard(
                    recommendation: insight.selectedChordScale,
                    accent: AppDarkTheme.borrowedColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleInsightCard extends StatelessWidget {
  const _ScaleInsightCard({
    required this.recommendation,
    required this.accent,
  });

  final ImprovisationScaleRecommendation recommendation;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppDarkTheme.bgWorkspace,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  recommendation.subtitle,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                recommendation.noteNamesSummary,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.title,
            style: const TextStyle(
              color: AppDarkTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.aestheticExperience,
            style: const TextStyle(
              color: AppDarkTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
