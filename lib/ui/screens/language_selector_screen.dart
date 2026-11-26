// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// First startup screen letting the user choose their interface language
/// (English or Español) before showing the localized credits and setup screens.
class LanguageSelectorScreen extends StatelessWidget {
  const LanguageSelectorScreen({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDarkTheme.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
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
                        Image.asset(
                          'assets/icon/app_icon.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
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
                      'Select your language',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
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
                            onTap: () =>
                                controller.selectLanguage(AppLanguage.en),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _LanguageCard(
                            code: 'ES',
                            languageName: 'Español',
                            actionLabel: 'Continuar en Español',
                            accent: AppDarkTheme.pelicanPink,
                            onTap: () =>
                                controller.selectLanguage(AppLanguage.es),
                          ),
                        ),
                      ],
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
