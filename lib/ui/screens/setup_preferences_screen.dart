// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// Third startup onboarding screen letting the user pick their starting
/// experience level (Basic/Advanced) and instrument mode (Piano/Guitar)
/// in their chosen language.
class SetupPreferencesScreen extends StatefulWidget {
  const SetupPreferencesScreen({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<SetupPreferencesScreen> createState() => _SetupPreferencesScreenState();
}

class _SetupPreferencesScreenState extends State<SetupPreferencesScreen> {
  ComplexityMode _selectedMode = ComplexityMode.basic;
  VisualizerMode _selectedInstrument = VisualizerMode.piano;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.controller.strings;

    return Scaffold(
      backgroundColor: AppDarkTheme.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppDarkTheme.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDarkTheme.borderSubtle),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // App icon & title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppDarkTheme.tonicColor
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.appTitle,
                                style: const TextStyle(
                                  color: AppDarkTheme.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                strings.appSubtitle,
                                style: const TextStyle(
                                  color: AppDarkTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    Text(
                      strings.setupTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.setupSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Experience level section
                    Text(
                      strings.setupLevelHeading.toUpperCase(),
                      style: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppDarkTheme.bgWorkspace,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppDarkTheme.borderSubtle),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _SetupChoiceTile(
                              title: strings.basicModeLabel,
                              subtitle: strings.setupBasicSubtitle,
                              selected: _selectedMode == ComplexityMode.basic,
                              accent: AppDarkTheme.tonicColor,
                              onTap: () => setState(
                                () => _selectedMode = ComplexityMode.basic,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _SetupChoiceTile(
                              title: strings.advancedModeLabel,
                              subtitle: strings.setupAdvancedSubtitle,
                              selected:
                                  _selectedMode == ComplexityMode.advanced,
                              accent: AppDarkTheme.borrowedColor,
                              onTap: () => setState(
                                () => _selectedMode = ComplexityMode.advanced,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Instrument mode section
                    Text(
                      strings.setupInstrumentHeading.toUpperCase(),
                      style: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppDarkTheme.bgWorkspace,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppDarkTheme.borderSubtle),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _SetupChoiceTile(
                              title: strings.setupPianoTitle,
                              subtitle: strings.setupPianoSubtitle,
                              icon: Icons.piano_rounded,
                              selected:
                                  _selectedInstrument == VisualizerMode.piano,
                              accent: AppDarkTheme.tonicColor,
                              onTap: () => setState(
                                () =>
                                    _selectedInstrument = VisualizerMode.piano,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _SetupChoiceTile(
                              title: strings.setupGuitarTitle,
                              subtitle: strings.setupGuitarSubtitle,
                              icon: Icons.queue_music_rounded,
                              selected:
                                  _selectedInstrument == VisualizerMode.guitar,
                              accent: AppDarkTheme.subdominantColor,
                              onTap: () => setState(
                                () =>
                                    _selectedInstrument = VisualizerMode.guitar,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDarkTheme.tonicColor,
                        foregroundColor: AppDarkTheme.bgPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => widget.controller.completeInitialSetup(
                        complexityMode: _selectedMode,
                        visualizerMode: _selectedInstrument,
                      ),
                      child: Text(
                        strings.setupContinueButton,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      strings.setupFooterHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppDarkTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupChoiceTile extends StatelessWidget {
  const _SetupChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
          ),
        ),
        child: Column(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? accent : AppDarkTheme.textSecondary,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? accent : AppDarkTheme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppDarkTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
