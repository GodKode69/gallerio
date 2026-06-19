import 'package:flutter/material.dart';

const double kNavbarHeight = 68.0;

class NavbarScrollObserver extends ChangeNotifier {
  double _offset = 0.0;
  double get offset => _offset;

  double _previousScrollOffset = 0;
  bool _isTracking = false;
  bool _isDocked = false;
  bool get isDocked => _isDocked;

  bool get isHidden => _offset >= kNavbarHeight;

  void setDocked(bool value) {
    if (_isDocked == value) return;
    _isDocked = value;
    if (value) {
      _offset = 0;
    }
    notifyListeners();
  }

  void onScrollUpdate(double currentScrollOffset) {
    if (_isDocked) return;

    if (!_isTracking) {
      _previousScrollOffset = currentScrollOffset;
      _isTracking = true;
      return;
    }

    final delta = currentScrollOffset - _previousScrollOffset;
    _previousScrollOffset = currentScrollOffset;

    if (currentScrollOffset <= 0) {
      if (_offset > 0) {
        _offset = 0;
        notifyListeners();
      }
      return;
    }

    final newOffset = (_offset + delta).clamp(0.0, kNavbarHeight);
    if (newOffset != _offset) {
      _offset = newOffset;
      notifyListeners();
    }
  }

  void onScrollEnd() {
    if (_isDocked) return;
    _isTracking = false;

    if (_offset <= 0 || _offset >= kNavbarHeight) {
      return;
    }

    const snapThreshold = kNavbarHeight * 0.4;
    if (_offset > snapThreshold) {
      _offset = kNavbarHeight;
    } else {
      _offset = 0;
    }
    notifyListeners();
  }

  void reset() {
    if (_offset == 0 && !_isDocked) return;
    _offset = 0;
    _previousScrollOffset = 0;
    _isTracking = false;
    notifyListeners();
  }
}

class NavbarAwareScrollWrapper extends StatelessWidget {
  final ScrollController scrollController;
  final NavbarScrollObserver observer;
  final Widget child;

  const NavbarAwareScrollWrapper({
    super.key,
    required this.scrollController,
    required this.observer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.depth == 0) {
          observer.onScrollUpdate(notification.metrics.pixels);
        } else if (notification is ScrollEndNotification &&
            notification.depth == 0) {
          observer.onScrollEnd();
        }
        return false;
      },
      child: child,
    );
  }
}
