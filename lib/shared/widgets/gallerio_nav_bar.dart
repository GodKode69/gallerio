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
    Icons.folder_outlined,
    Icons.photo_library_outlined,
    Icons.search,
    Icons.swap_horiz,
    Icons.settings_outlined,
  ];

  static const _activeIcons = [
    Icons.folder,
    Icons.photo_library,
    Icons.search,
    Icons.swap_horiz,
    Icons.settings,
  ];

  static const _labels = ['Albums', 'Gallery', 'Search', 'Convert', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(5, (index) {
                final isSelected = index == currentIndex;

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
                    ),
                  ),
                );
              }),
            ),
          ),
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

  const _NavBarItem({
    required this.index,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.activeColor,
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
      value: widget.isSelected ? 0.0 : 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.reset();
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.value = 1.0;
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
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 10,
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
