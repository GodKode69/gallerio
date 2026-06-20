import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/gallerio_nav_bar.dart';
import '../shared/widgets/navbar_scroll_observer.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/albums_screen.dart';
import '../features/gallery/screens/search_screen.dart';
import '../features/tools/screens/tools_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/gallery/providers/gallery_provider.dart';
import '../features/onboarding/screens/onboarding_overlay.dart';

final searchFocusTrigger = ValueNotifier<int>(0);
final resetAlbumDetail = ValueNotifier<int>(0);
final albumHasSelection = ValueNotifier<bool>(false);

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  int? _previousIndex;
  late final PageController _pageController;
  final _navbarObserver = NavbarScrollObserver();
  NavbarDockState _dockState = NavbarDockState.center;
  late final AnimationController _dockAnim;
  final _navbarOffsetValue = ValueNotifier<double>(0);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    _dockAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _dockAnim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _dockState = NavbarDockState.center;
        });
        _navbarObserver.setDocked(false);
      }
    });
    _screens = [
      AlbumsScreen(navbarObserver: _navbarObserver),
      GalleryScreen(navbarObserver: _navbarObserver),
      SearchScreen(navbarObserver: _navbarObserver),
      const ToolsScreen(),
      const SettingsScreen(),
    ];
    _navbarObserver.addListener(_onNavbarOffsetChanged);
    tutorialTabNotifier.addListener(_onTutorialTabRequest);
  }

  @override
  void dispose() {
    _navbarObserver.removeListener(_onNavbarOffsetChanged);
    tutorialTabNotifier.removeListener(_onTutorialTabRequest);
    _navbarObserver.dispose();
    _navbarOffsetValue.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _dockAnim.dispose();
    super.dispose();
  }

  void _onNavbarOffsetChanged() {
    _navbarOffsetValue.value = _navbarObserver.offset;
  }

  void _onTutorialTabRequest() {
    final tab = tutorialTabNotifier.value;
    if (tab != _currentIndex) {
      FocusManager.instance.primaryFocus?.unfocus();
      _switchTab(tab);
    }
  }

  void _onDockChanged(NavbarDockState newState) {
    if (newState == NavbarDockState.center) {
      _dockAnim.reverse();
    } else {
      _navbarObserver.setDocked(true);
      setState(() {
        _dockState = newState;
      });
      _dockAnim.forward();
    }
  }

  void _resetDock() {
    _navbarObserver.setDocked(false);
    setState(() {
      _dockState = NavbarDockState.center;
    });
    _dockAnim.value = 0;
  }

  void _onMenuTap(int index) {
    if (index == _currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (ref.read(galleryProvider).isSelectionMode) {
      ref.read(galleryProvider.notifier).exitSelectionMode();
    }
    if (ref.read(isAlbumDetailProvider)) {
      ref.read(isAlbumDetailProvider.notifier).state = false;
      resetAlbumDetail.value++;
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
  Future<bool> didPopRoute() async {
    if (ref.read(galleryProvider).isSelectionMode) {
      ref.read(galleryProvider.notifier).exitSelectionMode();
      return true;
    }
    if (albumHasSelection.value) {
      albumHasSelection.value = false;
      return true;
    }
    if (ref.read(isAlbumDetailProvider)) {
      ref.read(isAlbumDetailProvider.notifier).state = false;
      resetAlbumDetail.value++;
      return true;
    }
    return false;
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (ref.read(galleryProvider).isSelectionMode) {
      ref.read(galleryProvider.notifier).exitSelectionMode();
    }

    if (ref.read(isAlbumDetailProvider)) {
      ref.read(isAlbumDetailProvider.notifier).state = false;
      resetAlbumDetail.value++;
    }

    _navbarObserver.reset();
    if (_dockState != NavbarDockState.center) {
      _resetDock();
    }

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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
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
            AnimatedBuilder(
              animation: Listenable.merge([_dockAnim, _navbarOffsetValue]),
              builder: (context, _) {
                final t = Curves.easeInOutCubic.transform(_dockAnim.value);
                final navbarOffset = _navbarOffsetValue.value;

                double navWidth;
                double navLeft;

                switch (_dockState) {
                  case NavbarDockState.dockedLeft:
                    navLeft = lerpDouble(0, 16, t)!;
                    navWidth = lerpDouble(screenWidth, 72, t)!;
                    break;
                  case NavbarDockState.dockedRight:
                    navLeft = lerpDouble(0, screenWidth - 72, t)!;
                    navWidth = lerpDouble(screenWidth, 72, t)!;
                    break;
                  case NavbarDockState.center:
                    navWidth = screenWidth;
                    navLeft = 0;
                    break;
                }

                return Positioned(
                  left: navLeft,
                  bottom: 0,
                  width: navWidth,
                  child: Transform.translate(
                    offset: Offset(0, navbarOffset),
                    child: GallerioNavBar(
                      currentIndex: _currentIndex,
                      previousIndex: _previousIndex,
                      dockState: _dockState,
                      dockAnimValue: _dockAnim.value,
                      onDock: _onDockChanged,
                      onTap: (index) {
                        if (index == _currentIndex) {
                          if (index == 2) {
                            searchFocusTrigger.value++;
                          }
                          return;
                        }
                        _switchTab(index);
                      },
                      onMenuTap: _onMenuTap,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
