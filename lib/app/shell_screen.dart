import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/gallerio_nav_bar.dart';
import '../shared/widgets/navbar_scroll_observer.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/albums_screen.dart';
import '../features/gallery/screens/search_screen.dart';
import '../features/settings/screens/convert_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/gallery/providers/gallery_provider.dart';

final searchFocusTrigger = ValueNotifier<int>(0);
final resetAlbumDetail = ValueNotifier<int>(0);

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 1;
  int? _previousIndex;
  late final PageController _pageController;
  final _navbarObserver = NavbarScrollObserver();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    _screens = [
      AlbumsScreen(navbarObserver: _navbarObserver),
      GalleryScreen(navbarObserver: _navbarObserver),
      SearchScreen(navbarObserver: _navbarObserver),
      const ConvertScreen(),
      const SettingsScreen(),
    ];
    _navbarObserver.addListener(_onNavbarOffsetChanged);
  }

  @override
  void dispose() {
    _navbarObserver.removeListener(_onNavbarOffsetChanged);
    _navbarObserver.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _onNavbarOffsetChanged() {
    setState(() {});
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

    bool hadSelection = false;

    if (ref.read(galleryProvider).isSelectionMode) {
      ref.read(galleryProvider.notifier).exitSelectionMode();
      hadSelection = true;
    }

    if (ref.read(isAlbumDetailProvider)) {
      ref.read(isAlbumDetailProvider.notifier).state = false;
      resetAlbumDetail.value++;
      hadSelection = true;
    }

    if (hadSelection && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selection cleared'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      });
    }

    _navbarObserver.reset();

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
    final navbarOffset = _navbarObserver.offset;

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
                }
              },
              itemCount: _screens.length,
              itemBuilder: (context, index) => _screens[index],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(0, navbarOffset),
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
            ),
        ],
      ),
    );
  }
}
