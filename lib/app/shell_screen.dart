import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/gallerio_nav_bar.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/albums_screen.dart';
import '../features/gallery/screens/search_screen.dart';
import '../features/settings/screens/convert_screen.dart';
import '../features/settings/screens/settings_screen.dart';

final searchFocusTrigger = ValueNotifier<int>(0);

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 1;
  late final PageController _pageController;

  static const _tabs = ['/albums', '/gallery', '/search', '/convert', '/settings'];

  static const _screens = <Widget>[
    AlbumsScreen(),
    GalleryScreen(),
    SearchScreen(),
    ConvertScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t));
    if (idx >= 0 && idx != _currentIndex) {
      setState(() => _currentIndex = idx);
      _pageController.jumpToPage(idx);
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
    context.go(_tabs[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
            context.go(_tabs[index]);
          }
        },
        itemCount: _screens.length,
        itemBuilder: (context, index) => _screens[index],
      ),
      bottomNavigationBar: GallerioNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) {
            if (index == 2) {
              searchFocusTrigger.value++;
            }
            return;
          }
          _switchTab(index);
        },
      ),
    );
  }
}
