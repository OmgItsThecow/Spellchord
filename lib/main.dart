import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'state/explorer_controller.dart';
import 'ui/screens/explorer_workspace.dart';
import 'ui/theme/dark_theme.dart';

void main() {
  runApp(const HarmonicExplorerApp());
}

/// Enables mouse-drag and trackpad scrolling on desktop platforms (Windows/Linux)
/// in addition to touch and stylus input.
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  const _DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Root Flutter application enforcing strict dark-mode-only rendering across
/// Windows, Linux, and Android.
class HarmonicExplorerApp extends StatefulWidget {
  const HarmonicExplorerApp({super.key});

  @override
  State<HarmonicExplorerApp> createState() => _HarmonicExplorerAppState();
}

class _HarmonicExplorerAppState extends State<HarmonicExplorerApp> {
  late final ExplorerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExplorerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spellchord — Harmonic & Modal Explorer',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _DesktopScrollBehavior(),
      themeMode: ThemeMode.dark,
      theme: AppDarkTheme.themeData,
      darkTheme: AppDarkTheme.themeData,
      home: ExplorerWorkspace(controller: _controller),
    );
  }
}
