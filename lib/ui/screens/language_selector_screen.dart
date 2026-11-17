// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// Pre-application startup screen letting the user choose their interface
/// language (English or Español) and starting experience level (Basic or Advanced).
class LanguageSelectorScreen extends StatefulWidget {
  const LanguageSelectorScreen({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
  ComplexityMode _selectedMode = ComplexityMode.basic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDarkTheme.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                padding: const EdgeInsets.all(20),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                AppDarkTheme.tonicColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppDarkTheme.tonicColor
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 24,
                            color: AppDarkTheme.tonicColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'SPELLCHORD',
                                style: TextStyle(
                                  color: AppDarkTheme.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'Harmonic & Modal Explorer',
                                style: TextStyle(
                                  color: AppDarkTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    const Text(
                      'Select your language & experience level',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Elige tu idioma y nivel de experiencia antes de comenzar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Starting complexity mode pills
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
                            child: _ModeChoiceTile(
                              title: 'Basic / Básico',
                              subtitle: 'Guided · No raw MIDI numbers',
                              selected: _selectedMode == ComplexityMode.basic,
                              accent: AppDarkTheme.tonicColor,
                              onTap: () => setState(
                                () => _selectedMode = ComplexityMode.basic,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _ModeChoiceTile(
                              title: 'Advanced / Avanzado',
                              subtitle: 'Full MIDI & 7-mode engine',
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
                    const SizedBox(height: 22),

                    // Language selection cards
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _LanguageCard(
                            code: 'EN',
                            languageName: 'English',
                            actionLabel: 'Continue in English',
                            accent: AppDarkTheme.tonicColor,
                            onTap: () => widget.controller.selectLanguage(
                              AppLanguage.en,
                              initialMode: _selectedMode,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _LanguageCard(
                            code: 'ES',
                            languageName: 'Español',
                            actionLabel: 'Continuar en Español',
                            accent: AppDarkTheme.subdominantColor,
                            onTap: () => widget.controller.selectLanguage(
                              AppLanguage.es,
                              initialMode: _selectedMode,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'You can switch between Basic/Advanced and EN/ES anytime in the top bar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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

class _ModeChoiceTile extends StatelessWidget {
  const _ModeChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? accent : AppDarkTheme.textPrimary,
                fontSize: 13,
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

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.code,
    required this.languageName,
    required this.actionLabel,
    required this.accent,
    required this.onTap,
  });

  final String code;
  final String languageName;
  final String actionLabel;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: AppDarkTheme.bgWorkspace,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              languageName,
              style: const TextStyle(
                color: AppDarkTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              actionLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
