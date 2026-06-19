import 'package:flutter/material.dart';

enum TooltipPosition { top, bottom }

class TutorialStep {
  final String title;
  final String description;
  final IconData? icon;
  final GlobalKey? targetKey;
  final TooltipPosition position;
  final int? switchToTab;
  final bool isInteractive;
  final bool showTryIt;
  final bool highlightTarget;

  const TutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
    this.position = TooltipPosition.bottom,
    this.switchToTab,
    this.isInteractive = false,
    this.showTryIt = false,
    this.highlightTarget = false,
  });
}
