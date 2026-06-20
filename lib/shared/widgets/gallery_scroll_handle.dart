import 'dart:async';
import 'dart:ui';
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
  bool _showLabel = false;
  bool _wasThumbDrag = false;
  String? _lastLabel;
  final Set<int> _pointersInScrollbar = {};

  late final AnimationController _thumbAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  ScrollController get _controller => widget.scrollController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _thumbAnim.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant GalleryScrollHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      _controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    _thumbAnim.dispose();
    super.dispose();
  }

  bool get _isThumbDragging => _pointersInScrollbar.isNotEmpty;

  void _onScroll() {
    if (!_showLabel || !mounted) return;
    final newLabel = _resolveLabel(widget.sections);
    if (newLabel != _lastLabel) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  bool _isInScrollbarRegion(Offset position, BoxConstraints constraints) {
    final rightEdge = constraints.maxWidth;
    return position.dx >= rightEdge - 30;
  }

  void _onPointerDown(PointerDownEvent event, BoxConstraints constraints) {
    if (_isInScrollbarRegion(event.position, constraints)) {
      _pointersInScrollbar.add(event.pointer);
      _wasThumbDrag = true;
      _hideTimer?.cancel();
      _thumbAnim.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointersInScrollbar.remove(event.pointer) && !_isThumbDragging) {
      _thumbAnim.animateTo(0.0, curve: Curves.easeIn);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointersInScrollbar.remove(event.pointer) && !_isThumbDragging) {
      _thumbAnim.animateTo(0.0, curve: Curves.easeIn);
    }
  }

  Widget _buildLabel(double trackHeight, double thumbH) {
    final sections = widget.sections;
    if (sections.isEmpty || !_controller.hasClients) {
      return const SizedBox.shrink();
    }
    final label = _resolveLabel(sections);
    _lastLabel = label;
    if (label == null) return const SizedBox.shrink();
    final maxScroll = _controller.position.maxScrollExtent;
    if (maxScroll <= 0) return const SizedBox.shrink();
    final viewportHeight = _controller.position.viewportDimension;
    final contentHeight = viewportHeight + maxScroll;
    final thumbHeight =
        ((viewportHeight / contentHeight) * trackHeight).clamp(32.0, 140.0);
    final thumbRange = trackHeight - thumbHeight;
    final thumbTop =
        (_controller.offset / maxScroll * thumbRange).clamp(0.0, thumbRange);
    return Positioned(
      right: 20,
      top: (thumbTop + thumbH - 4).clamp(0.0, trackHeight),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String? _resolveLabel(List<MonthSection> sections) {
    if (!_controller.hasClients) return null;
    final offset = _controller.offset;
    String? best;
    for (final section in sections) {
      if (section.offset <= offset) {
        best = section.label;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final trackHeight =
        (MediaQuery.of(context).size.height - widget.bottomReservedHeight)
            .clamp(0.0, MediaQuery.of(context).size.height);

    final t = _thumbAnim.value;
    final currentThickness = lerpDouble(8.0, 14.0, t)!;
    final currentAlpha = lerpDouble(0.35, 1.0, t)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null &&
                _isThumbDragging) {
              _hideTimer?.cancel();
              if (!_showLabel && widget.sections.isNotEmpty) {
                setState(() => _showLabel = true);
              }
            } else if (notification is ScrollEndNotification) {
              if (_wasThumbDrag) {
                _wasThumbDrag = false;
                _startHideTimer();
              }
            }
            return false;
          },
          child: Listener(
            onPointerDown: (e) => _onPointerDown(e, constraints),
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Stack(
              children: [
                RawScrollbar(
                  controller: _controller,
                  thumbVisibility: true,
                  interactive: true,
                  thickness: currentThickness,
                  thumbColor: Colors.white.withValues(alpha: currentAlpha),
                  radius: const Radius.circular(7),
                  minThumbLength: 40,
                  fadeDuration: const Duration(milliseconds: 150),
                  timeToFade: const Duration(milliseconds: 400),
                  child: widget.child,
                ),
                if (_showLabel) _buildLabel(trackHeight, currentThickness),
              ],
            ),
          ),
        );
      },
    );
  }
}
