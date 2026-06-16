import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GallerioNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GallerioNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
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

    return Container(
      height: 60,
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        top: false,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: Icon(
                        isSelected ? _activeIcons[index] : _icons[index],
                        key: ValueKey('$index-$isSelected'),
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.white54,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.white54,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      child: Text(_labels[index]),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
