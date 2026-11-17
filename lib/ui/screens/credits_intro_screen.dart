// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';

/// Opening startup credits window shown prior to the language selector.
class CreditsIntroScreen extends StatelessWidget {
  const CreditsIntroScreen({
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: AppDarkTheme.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDarkTheme.borderSubtle),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppDarkTheme.tonicColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              AppDarkTheme.tonicColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 28,
                        color: AppDarkTheme.tonicColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'SPELLCHORD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Harmonic & Modal Explorer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Created by SniffingWizard and OMGitstheCow in collab with the AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDarkTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
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
                      onPressed: () => controller.dismissCredits(),
                      child: const Text(
                        "I don't care",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          controller.dismissCredits(secretRockTap: true),
                      child: const Text(
                        'Keep rocking the world',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppDarkTheme.tonicColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
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
