import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/gallerio_nav_bar.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/albums_screen.dart';
import '../features/gallery/screens/search_screen.dart';
import '../features/settings/screens/convert_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/gallery/providers/gallery_provider.dart';

final searchFocusTrigger = ValueNotifier<int>(0);
final resetAlbumDetail = ValueNotifier<int>(0);

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 1;
  int? _previousIndex;
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
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (ref.read(isAlbumDetailProvider)) {
      ref.read(isAlbumDetailProvider.notifier).state = false;
      resetAlbumDetail.value++;
      return true;
    }
    if (ref.read(galleryProvider).isSelectionMode) {
      ref.read(galleryProvider.notifier).exitSelectionMode();
      return true;
    }
    return false;
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPinching = ref.watch(isPinchingProvider);

    return Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: isPinching ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: (index) {
                if (index != _currentIndex) {
                  setState(() {
                    _previousIndex = _currentIndex;
                    _currentIndex = index;
                  });
                  context.go(_tabs[index]);
                }
              },
              itemCount: _screens.length,
              itemBuilder: (context, index) => _screens[index],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GallerioNavBar(
                currentIndex: _currentIndex,
                previousIndex: _previousIndex,
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
            ),
        ],
      ),
    );
  }
}
