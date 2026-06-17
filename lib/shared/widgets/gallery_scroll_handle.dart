import 'dart:async';
import 'package:flutter/material.dart';

class MonthSection {
  final double offset;
  final String label;
  const MonthSection({required this.offset, required this.label});
}

class GalleryScrollHandle extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final List<MonthSection> sections;
  final double bottomReservedHeight;

  const GalleryScrollHandle({
    super.key,
    required this.scrollController,
    required this.child,
    this.sections = const [],
    this.bottomReservedHeight = 80.0,
  });

  @override
  State<GalleryScrollHandle> createState() => _GalleryScrollHandleState();
}

class _GalleryScrollHandleState extends State<GalleryScrollHandle>
    with SingleTickerProviderStateMixin {
  Timer? _hideTimer;
  late AnimationController _expandController;
  late Animation<double> _widthAnimation;
  late Animation<double> _opacityAnimation;

  bool _isVisible = false;
  bool _isDragging = false;
  bool _scrollingAttached = false;
  double _thumbTop = 0;
  double _thumbHeight = 0;
  double _trackHeight = 0;
  double _grabOffset = 0;
  String? _currentMonthLabel;

  static const double _thumbWidthIdle = 8.0;
  static const double _thumbWidthPressed = 14.0;
  static const double _hitAreaExtra = 16.0;
  static const double _thumbMinHeight = 32.0;
  static const double _thumbMaxHeight = 140.0;
  static const Duration _hideDelay = Duration(milliseconds: 600);
  static const Duration _expandDuration = Duration(milliseconds: 150);

  ScrollController get _controller => widget.scrollController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: _expandDuration,
    );
    _widthAnimation = Tween<double>(
      begin: _thumbWidthIdle,
      end: _thumbWidthPressed,
    ).animate(CurvedAnimation(parent: _expandController, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _expandController, curve: Curves.easeOut));
    _controller.addListener(_onScroll);
    _attachScrollingListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAttachDeferred());
  }

  @override
  void didUpdateWidget(covariant GalleryScrollHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      _detachScrollingListener(oldWidget.scrollController);
      _scrollingAttached = false;
      _controller.addListener(_onScroll);
      _attachScrollingListener();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _detachScrollingListener(_controller);
    _hideTimer?.cancel();
    _expandController.dispose();
    super.dispose();
  }

  void _attachScrollingListener() {
    if (_scrollingAttached) return;
    try {
      _controller.position.isScrollingNotifier.addListener(_onScrollingChanged);
      _scrollingAttached = true;
    } catch (_) {}
  }

  void _tryAttachDeferred() {
    if (!mounted || _scrollingAttached) return;
    _attachScrollingListener();
  }

  void _detachScrollingListener(ScrollController c) {
    try {
      c.position.isScrollingNotifier.removeListener(_onScrollingChanged);
    } catch (_) {}
    _scrollingAttached = false;
  }

  void _onScrollingChanged() {
    if (_isDragging) return;
    final isScrolling = _controller.position.isScrollingNotifier.value;
    if (isScrolling) {
      _hideTimer?.cancel();
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
    } else {
      _startHideTimer();
    }
  }

  void _recomputeThumb() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0 || _trackHeight <= 0) {
      _thumbHeight = 0;
      return;
    }
    final contentHeight = position.viewportDimension + maxScroll;
    _thumbHeight = ((position.viewportDimension / contentHeight) * _trackHeight)
        .clamp(_thumbMinHeight, _thumbMaxHeight);
    final thumbRange = _trackHeight - _thumbHeight;
    _thumbTop = (_controller.offset / maxScroll * thumbRange)
        .clamp(0.0, thumbRange);

    if (!_isVisible && _thumbHeight > 0) {
      _isVisible = true;
    }
  }

  void _onScroll() {
    if (!_scrollingAttached) {
      _attachScrollingListener();
    }
    if (_isDragging) return;
    _recomputeThumb();
    _updateMonthLabel();
    setState(() {});
  }

  void _updateMonthLabel() {
    final sections = widget.sections;
    if (sections.isEmpty || !_controller.hasClients) return;
    final offset = _controller.offset;
    String? best;
    for (final section in sections) {
      if (section.offset <= offset) {
        best = section.label;
      }
    }
    _currentMonthLabel = best;
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && !_isDragging) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _onThumbDown(DragStartDetails details) {
    if (!_controller.hasClients || _thumbHeight <= 0) return;
    _hideTimer?.cancel();
    _grabOffset = details.localPosition.dy - _hitAreaExtra;
    _isDragging = true;
    _expandController.forward();
    setState(() {});
  }

  void _onThumbMove(DragUpdateDetails details) {
    if (!_isDragging || !_controller.hasClients) return;

    final maxScroll = _controller.position.maxScrollExtent;
    if (maxScroll <= 0 || _trackHeight <= _thumbHeight) return;

    final thumbRange = _trackHeight - _thumbHeight;
    final rawTop = details.localPosition.dy - _grabOffset;
    _thumbTop = rawTop.clamp(0.0, thumbRange);

    final progress = thumbRange > 0 ? _thumbTop / thumbRange : 0.0;
    final newOffset = (progress * maxScroll).clamp(0.0, maxScroll);

    _controller.jumpTo(newOffset);
    _updateMonthLabel();
    setState(() {});
  }

  void _onThumbUp(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    _expandController.reverse();
    _recomputeThumb();
    _startHideTimer();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final oldTrackHeight = _trackHeight;
        _trackHeight = (constraints.maxHeight - widget.bottomReservedHeight)
            .clamp(0.0, constraints.maxHeight);
        if (oldTrackHeight != _trackHeight && !_isDragging) {
          _recomputeThumb();
        }

        if (!_scrollingAttached && _controller.hasClients) {
          _attachScrollingListener();
        }

        if (!_controller.hasClients || _trackHeight <= 0) {
          return widget.child;
        }

        final maxScroll = _controller.position.maxScrollExtent;
        if (maxScroll <= 0) return widget.child;

        final hitAreaHeight = _thumbHeight + _hitAreaExtra * 2;

        return Stack(
          children: [
            widget.child,
            if (_isVisible && _thumbHeight > 0)
              Positioned(
                right: 0,
                top: (_thumbTop - _hitAreaExtra).clamp(
                    0.0, (_trackHeight - hitAreaHeight).clamp(0.0, _trackHeight)),
                child: GestureDetector(
                  onVerticalDragStart: _onThumbDown,
                  onVerticalDragUpdate: _onThumbMove,
                  onVerticalDragEnd: _onThumbUp,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: _thumbWidthPressed + _hitAreaExtra * 2,
                    height: hitAreaHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedBuilder(
                        animation: _expandController,
                        builder: (context, _) {
                          final width = _widthAnimation.value;
                          final opacity = _opacityAnimation.value;
                          return Container(
                            width: width,
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(width / 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            if (_isVisible && _isDragging && _currentMonthLabel != null)
              Positioned(
                right: 20,
                top: (_thumbTop - 28).clamp(0.0, _trackHeight),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentMonthLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
