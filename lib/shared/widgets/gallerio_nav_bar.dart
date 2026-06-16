import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GallerioNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? previousIndex;

  const GallerioNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.previousIndex,
  });

  static const _icons = [
    Icons.photo_library_outlined,
    Icons.photo_library,
    Icons.search,
    Icons.swap_horiz,
    Icons.settings_outlined,
  ];

  static const _activeIcons = [
    Icons.photo_library,
    Icons.photo_library,
    Icons.search,
    Icons.swap_horiz,
    Icons.settings,
  ];

  static const _labels = ['Albums', 'Gallery', 'Search', 'Convert', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final prev = previousIndex ?? currentIndex;

    return Container(
      height: 72,
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(5, (index) {
            final isSelected = index == currentIndex;
            final isInvolved = index == prev || index == currentIndex;
            final delay = isInvolved
                ? (index < prev
                    ? (prev - index) * 40
                    : index > currentIndex
                        ? (index - currentIndex) * 40
                        : 0)
                : 0;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(index);
                },
                behavior: HitTestBehavior.opaque,
                child: _NavBarItem(
                  index: index,
                  isSelected: isSelected,
                  icon: isSelected ? _activeIcons[index] : _icons[index],
                  label: _labels[index],
                  activeColor: colorScheme.primary,
                  delay: delay,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final int index;
  final bool isSelected;
  final IconData icon;
  final String label;
  final Color activeColor;
  final int delay;

  const _NavBarItem({
    required this.index,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.delay,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    if (widget.isSelected) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.reset();
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    } else if (!widget.isSelected && oldWidget.isSelected) {
      // Don't reverse scale — keep at 1.0 to avoid icon disappearing
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            widget.icon,
            color: widget.isSelected ? widget.activeColor : Colors.white54,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            color: widget.isSelected ? widget.activeColor : Colors.white54,
            fontWeight:
                widget.isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(widget.label),
        ),
      ],
    );
  }
}
