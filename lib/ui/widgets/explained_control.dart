// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../state/explorer_controller.dart';

/// Wraps an interactive control so desktop users see a tooltip and bottom help
/// explanation on pointer hover, while Android users get the tooltip and bottom
/// help explanation on long-press.
class ExplainedControl extends StatelessWidget {
  const ExplainedControl({
    super.key,
    required this.controller,
    required this.explanation,
    required this.child,
  });

  final ExplorerController controller;
  final String explanation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => controller.setHelpMessage(explanation),
      child: Tooltip(
        message: explanation,
        waitDuration: const Duration(milliseconds: 350),
        onTriggered: () => controller.setHelpMessage(explanation),
        child: child,
      ),
    );
  }
}
