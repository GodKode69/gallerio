import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';

enum NavbarDockState { center, dockedLeft, dockedRight }

class GallerioNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onMenuTap;
  final int? previousIndex;
  final NavbarDockState dockState;
  final double dockAnimValue;
  final ValueChanged<NavbarDockState>? onDock;

  const GallerioNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onMenuTap,
    this.previousIndex,
    this.dockState = NavbarDockState.center,
    this.dockAnimValue = 0.0,
    this.onDock,
  });

  @override
  State<GallerioNavBar> createState() => _GallerioNavBarState();
}

class _GallerioNavBarState extends State<GallerioNavBar>
    with SingleTickerProviderStateMixin {
  double _dragStartX = 0;
  bool _isDragging = false;
  bool _isMenuOpen = false;
  late final AnimationController _menuAnim;

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
  void initState() {
    super.initState();
    _menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _menuAnim.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _menuAnim.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final dx = event.position.dx - _dragStartX;
    if (dx.abs() > 10) _isDragging = true;
  }

  void _onPointerUp(PointerUpEvent event) {
    final dx = event.position.dx - _dragStartX;

    if (widget.dockState != NavbarDockState.center) {
      if (_isDragging && dx.abs() > 30) {
        _closeMenu();
        widget.onDock?.call(NavbarDockState.center);
      }
      return;
    }

    if (dx > 50) {
      widget.onDock?.call(NavbarDockState.dockedRight);
    } else if (dx < -50) {
      widget.onDock?.call(NavbarDockState.dockedLeft);
    }
  }

  void _toggleMenu() {
    _isMenuOpen = !_isMenuOpen;
    if (_isMenuOpen) {
      _menuAnim.forward();
    } else {
      _menuAnim.reverse();
    }
    setState(() {});
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    _isMenuOpen = false;
    _menuAnim.reverse();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showExpanded = widget.dockState == NavbarDockState.center ||
        widget.dockAnimValue < 0.7;
    if (showExpanded) {
      _isMenuOpen = false;
      return _buildExpanded();
    }
    return _buildCollapsed();
  }

  Widget _buildCollapsed() {
    final colorScheme = Theme.of(context).colorScheme;
    final index = widget.currentIndex;
    final otherIndices = [0, 1, 2, 3, 4].where((i) => i != index).toList();
    final t = _menuAnim.value;
    final menuHeight = t * otherIndices.length * 48;

    final alignment = widget.dockState == NavbarDockState.dockedLeft
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: alignment,
          child: Container(
            width: 56,
            height: 56 + menuHeight,
            decoration: BoxDecoration(
              color: AppColors.chipBackground.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isMenuOpen || _menuAnim.isAnimating)
                  for (int j = 0; j < otherIndices.length; j++)
                    _buildAnimatedMenuItem(
                      otherIndices[j],
                      j,
                      otherIndices.length,
                      t,
                      colorScheme,
                    ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMenu,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: Icon(
                        _activeIcons[index],
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMenuItem(
    int itemIndex,
    int position,
    int total,
    double animValue,
    ColorScheme colorScheme,
  ) {
    final staggerStart = position / total * 0.4;
    final staggerEnd = staggerStart + 0.6;
    final raw = ((animValue - staggerStart) / (staggerEnd - staggerStart))
        .clamp(0.0, 1.0);
    final curved = Curves.easeOutBack.transform(raw);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: raw > 0.3
          ? () {
              HapticFeedback.selectionClick();
              _closeMenu();
              if (itemIndex != widget.currentIndex) {
                if (widget.onMenuTap != null) {
                  widget.onMenuTap!(itemIndex);
                } else {
                  widget.onTap(itemIndex);
                }
              }
            }
          : null,
      child: Opacity(
        opacity: raw,
        child: Transform.translate(
          offset: Offset(0, (1.0 - curved) * -12),
          child: SizedBox(
            width: 56,
            height: 48,
            child: Center(
              child: Icon(
                _icons[itemIndex],
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.chipBackground.withValues(alpha: 0.95),
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
                  final isSelected = index == widget.currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onTap(index);
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
            color: widget.isSelected
                ? widget.activeColor
                : AppColors.textSecondary,
            size: 24,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 10,
            color: widget.isSelected
                ? widget.activeColor
                : AppColors.textSecondary,
            fontWeight:
                widget.isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(widget.label),
        ),
      ],
    );
  }
}
