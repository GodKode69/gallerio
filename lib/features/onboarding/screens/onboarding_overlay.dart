import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/storage/local_prefs.dart';
import '../models/tutorial_step.dart';
import '../widgets/coach_mark.dart';

final tutorialTabNotifier = ValueNotifier<int>(1);

enum OnboardingPhase { welcome, prompt, tutorial, done }

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  OnboardingPhase _phase = OnboardingPhase.welcome;
  int _currentStep = 0;
  late final List<TutorialStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
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
            'Swipe left or right on the bottom bar to dock it to the side. Try it now \u2014 swipe the navbar to the left edge!',
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

  void _finishOnboarding() async {
    await LocalPrefs().completeOnboarding();
    widget.onComplete();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _switchToStepTab();
    } else {
      _finishOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _switchToStepTab();
    }
  }

  void _switchToStepTab() {
    final step = _steps[_currentStep];
    if (step.switchToTab != null) {
      tutorialTabNotifier.value = step.switchToTab!;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case OnboardingPhase.welcome:
        return _buildWelcomeOverlay();
      case OnboardingPhase.prompt:
        return _buildPromptOverlay();
      case OnboardingPhase.tutorial:
        return _buildTutorialOverlay();
      case OnboardingPhase.done:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.sheetBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Gallerio',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your personal gallery with a hidden vault, smart organization, and powerful tools to manage your photos.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => setState(() => _phase = OnboardingPhase.prompt),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.sheetBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Explore Gallerio',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gallerio has a lot of features. Would you like a quick tour?',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _finishOnboarding,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(
                              color: AppColors.textSecondary.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => setState(() => _phase = OnboardingPhase.tutorial),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Sure',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
    );
  }

  Widget _buildTutorialOverlay() {
    if (_steps.isEmpty) return const SizedBox.shrink();

    final step = _steps[_currentStep];

    return CoachMark(
      step: step,
      currentStep: _currentStep,
      totalSteps: _steps.length,
      onPrevious: _currentStep > 0 ? _previousStep : null,
      onNext: _nextStep,
    );
  }
}
