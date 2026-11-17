// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../state/explorer_controller.dart';
import '../theme/dark_theme.dart';
import '../visualizers/visualizer_container.dart';
import '../widgets/explained_control.dart';
import '../widgets/key_center_bar.dart';
import '../widgets/modal_interchange_panel.dart';
import '../widgets/progression_timeline.dart';
import '../widgets/secret_improv_panel.dart';
import '../widgets/voice_leading_panel.dart';
import 'credits_intro_screen.dart';
import 'language_selector_screen.dart';

/// Main responsive workspace uniting Key Center controls, Progression Timeline,
/// Voice Leading & Modal Interchange inspectors, and Piano/Guitar visualizers.
class ExplorerWorkspace extends StatefulWidget {
  const ExplorerWorkspace({
    super.key,
    required this.controller,
  });

  final ExplorerController controller;

  @override
  State<ExplorerWorkspace> createState() => _ExplorerWorkspaceState();
}

class _ExplorerWorkspaceState extends State<ExplorerWorkspace> {
  int _narrowPanelTab = 0; // 0 = Voice Leading, 1 = Modal Interchange, 2 = Secret Improv
  bool _wasSecretRevealed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        if (widget.controller.isSecretImprovRevealed && !_wasSecretRevealed) {
          _wasSecretRevealed = true;
          _narrowPanelTab = 2;
        }
        if (!widget.controller.hasDismissedCredits) {
          return CreditsIntroScreen(controller: widget.controller);
        }
        if (!widget.controller.hasSelectedLanguage) {
          return LanguageSelectorScreen(controller: widget.controller);
        }

        return Scaffold(
          backgroundColor: AppDarkTheme.bgPrimary,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isWide = constraints.maxWidth >= 860;
                final bool useScrollableLayout =
                    !isWide || constraints.maxHeight < 820;

                if (useScrollableLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              KeyCenterBar(controller: widget.controller),
                              ProgressionTimeline(controller: widget.controller),
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  height: 470,
                                  child: VisualizerContainer(
                                    controller: widget.controller,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 360,
                                child: _buildTheorySplit(isWide),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _HelpStatusBar(
                        message: widget.controller.activeHelpMessage,
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    KeyCenterBar(controller: widget.controller),
                    ProgressionTimeline(controller: widget.controller),
                    Expanded(
                      flex: 5,
                      child: _buildTheorySplit(isWide),
                    ),
                    Expanded(
                      flex: 5,
                      child: VisualizerContainer(controller: widget.controller),
                    ),
                    _HelpStatusBar(
                      message: widget.controller.activeHelpMessage,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTheorySplit(bool isWide) {
    final bool showSecret = widget.controller.isSecretImprovRevealed;
    final int safeNarrowTab = (!showSecret && _narrowPanelTab > 1)
        ? 0
        : _narrowPanelTab;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 5,
              child: VoiceLeadingPanel(controller: widget.controller),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: ModalInterchangePanel(controller: widget.controller),
            ),
            if (showSecret) ...<Widget>[
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: SecretImprovPanel(controller: widget.controller),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ExplainedControl(
                  controller: widget.controller,
                  explanation: widget.controller.strings.voiceLeadingTabTip,
                  child: _TabPill(
                    label: widget.controller.strings.voiceLeadingTab,
                    selected: safeNarrowTab == 0,
                    accent: AppDarkTheme.tonicColor,
                    onTap: () => setState(() => _narrowPanelTab = 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExplainedControl(
                  controller: widget.controller,
                  explanation: widget.controller.strings.modalInterchangeTabTip,
                  child: _TabPill(
                    label: widget.controller.strings.modalInterchangeTab,
                    selected: safeNarrowTab == 1,
                    accent: AppDarkTheme.borrowedColor,
                    onTap: () => setState(() => _narrowPanelTab = 1),
                  ),
                ),
              ),
              if (showSecret) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: ExplainedControl(
                    controller: widget.controller,
                    explanation: widget.controller.strings.secretImprovTabTip,
                    child: _TabPill(
                      label: widget.controller.strings.secretImprovTab,
                      selected: safeNarrowTab == 2,
                      accent: AppDarkTheme.subdominantColor,
                      onTap: () => setState(() => _narrowPanelTab = 2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: safeNarrowTab == 0
                ? VoiceLeadingPanel(controller: widget.controller)
                : (safeNarrowTab == 1
                    ? ModalInterchangePanel(controller: widget.controller)
                    : SecretImprovPanel(controller: widget.controller)),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : AppDarkTheme.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : AppDarkTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _HelpStatusBar extends StatelessWidget {
  const _HelpStatusBar({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppDarkTheme.bgWorkspace,
        border: Border(
          top: BorderSide(color: AppDarkTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppDarkTheme.tonicColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppDarkTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
