import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../models/tutorial_step.dart';

class CoachMark extends StatefulWidget {
  final TutorialStep step;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final Rect? targetRect;

  const CoachMark({
    super.key,
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    this.onPrevious,
    required this.onNext,
    this.targetRect,
  });

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

class _CoachMarkState extends State<CoachMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant CoachMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _pulseController.reset();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLast = widget.currentStep == widget.totalSteps - 1;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.step.highlightTarget && widget.targetRect != null)
          _buildHighlight(screenWidth, screenHeight),
        _buildOverlay(
          context, screenWidth, screenHeight, bottomPadding, topPadding, isLast,
        ),
      ],
    );
  }

  Widget _buildHighlight(double screenWidth, double screenHeight) {
    final rect = widget.targetRect!.inflate(6);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(screenWidth, screenHeight),
          painter: _HighlightPainter(
            targetRect: rect,
            opacity: _pulseAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    double screenWidth,
    double screenHeight,
    double bottomPadding,
    double topPadding,
    bool isLast,
  ) {
    final isTop = widget.step.position == TooltipPosition.top;

    return Positioned.fill(
      child: Align(
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: isTop ? topPadding + 8 : 0,
            bottom: isTop ? 0 : 6.0,
            left: 16,
            right: 16,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: isTop ? const Offset(0, -0.08) : const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey('card_${widget.currentStep}'),
              child: _buildCard(context, isLast, showTryIt: widget.step.showTryIt),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isLast, {bool showTryIt = false}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sheetBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.step.icon != null) ...[
                  Icon(widget.step.icon, color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.step.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showTryIt)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Try it',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.step.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onPrevious != null)
                  TextButton(
                    onPressed: widget.onPrevious,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(width: 12),
                const Spacer(),
                _buildStepIndicator(context),
                const Spacer(),
                FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.totalSteps, (index) {
        final isActive = index == widget.currentStep;
        return Container(
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : AppColors.textMuted,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final Rect targetRect;
  final double opacity;

  _HighlightPainter({required this.targetRect, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(12)),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
