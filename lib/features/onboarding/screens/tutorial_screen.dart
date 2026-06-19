import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/shell_screen.dart';
import '../../../core/storage/local_prefs.dart';
import '../models/tutorial_step.dart';
import '../widgets/coach_mark.dart';
import 'onboarding_overlay.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  int _currentStep = 0;
  late final List<TutorialStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
    WidgetsBinding.instance.addPostFrameCallback((_) => _switchToStepTab());
  }

  List<TutorialStep> _buildSteps() {
    return [
      const TutorialStep(
        title: 'Your Gallery',
        description:
            'This is your main gallery. All your photos are organized here by date. Scroll through to browse your memories.',
        icon: Icons.photo_library_outlined,
        position: TooltipPosition.bottom,
        isInteractive: true,
      ),
      const TutorialStep(
        title: 'Navigation Bar',
        description:
            'Swipe left or right on the bottom bar to dock it to the side. Try it now — swipe the navbar to the left edge!',
        icon: Icons.touch_app_outlined,
        position: TooltipPosition.top,
        isInteractive: true,
        showTryIt: true,
        highlightTarget: true,
        switchToTab: 1,
      ),
      const TutorialStep(
        title: 'Albums',
        description:
            'Browse your photos organized into albums. Camera, screenshots, WhatsApp, and more are automatically grouped.',
        icon: Icons.folder_outlined,
        position: TooltipPosition.bottom,
        isInteractive: true,
        switchToTab: 0,
      ),
      const TutorialStep(
        title: 'Search',
        description:
            'Search for photos by name, filter by type, or access your hidden vault from here.',
        icon: Icons.search,
        position: TooltipPosition.bottom,
        isInteractive: true,
        showTryIt: true,
        switchToTab: 2,
      ),
      const TutorialStep(
        title: 'Selection Mode',
        description:
            'Long-press any photo to enter selection mode. Drag across photos to select multiple. Try it!',
        icon: Icons.check_circle_outline,
        position: TooltipPosition.bottom,
        isInteractive: true,
        showTryIt: true,
        switchToTab: 1,
      ),
      const TutorialStep(
        title: 'Gallery Zoom',
        description:
            'Pinch the gallery to zoom in and out. This changes the number of items per row, from 3 to 6. Try pinching!',
        icon: Icons.zoom_in_outlined,
        position: TooltipPosition.bottom,
        isInteractive: true,
        showTryIt: true,
        switchToTab: 1,
      ),
      const TutorialStep(
        title: 'Vault',
        description:
            'Hide sensitive photos in a secure vault. Access it from search by entering your vault code, which you can set from Settings.',
        icon: Icons.lock_outline,
        position: TooltipPosition.bottom,
        isInteractive: true,
        switchToTab: 2,
      ),
      const TutorialStep(
        title: 'Trash',
        description:
            'Deleted photos go to Trash and stay for 30 days before being permanently removed. You can restore them anytime from Settings.',
        icon: Icons.delete_outline,
        position: TooltipPosition.bottom,
        isInteractive: true,
        switchToTab: 4,
      ),
      const TutorialStep(
        title: 'PIN Protection',
        description:
            'Set a PIN to lock your gallery. You can also enable fingerprint or face unlock in Settings for quick access.',
        icon: Icons.security_outlined,
        position: TooltipPosition.bottom,
        isInteractive: true,
        switchToTab: 4,
      ),
    ];
  }

  void _switchToStepTab() {
    final step = _steps[_currentStep];
    if (step.switchToTab != null) {
      tutorialTabNotifier.value = step.switchToTab!;
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _switchToStepTab());
    } else {
      _finishTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      WidgetsBinding.instance.addPostFrameCallback((_) => _switchToStepTab());
    }
  }

  void _finishTutorial() async {
    await LocalPrefs().completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();

    final step = _steps[_currentStep];

    return Scaffold(
      body: Stack(
        children: [
          const ShellScreen(),
          CoachMark(
            key: ValueKey(_currentStep),
            step: step,
            currentStep: _currentStep,
            totalSteps: _steps.length,
            onPrevious: _currentStep > 0 ? _previousStep : null,
            onNext: _nextStep,
          ),
        ],
      ),
    );
  }
}
