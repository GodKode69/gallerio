import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import '../shared/widgets/gallerio_nav_bar.dart';
import '../shared/widgets/navbar_scroll_observer.dart';
import '../shared/widgets/confirm_delete_dialog.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/albums_screen.dart';
import '../features/gallery/screens/search_screen.dart';
import '../features/tools/screens/tools_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/gallery/providers/gallery_provider.dart';
import '../features/onboarding/screens/onboarding_overlay.dart';
import '../core/database/database.dart';
import '../core/trash/trash_service.dart';
import '../shared/utils/vault_utils.dart';

final searchFocusTrigger = ValueNotifier<int>(0);
final resetAlbumDetail = ValueNotifier<int>(0);
final albumHasSelection = ValueNotifier<bool>(false);
final albumSelectAllTrigger = ValueNotifier<int>(0);
final albumShareTrigger = ValueNotifier<int>(0);
final albumHideTrigger = ValueNotifier<int>(0);
final albumDeleteTrigger = ValueNotifier<int>(0);
final albumExitSelectionTrigger = ValueNotifier<int>(0);

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
  late final AnimationController _selectionAnim;

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
    _selectionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
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
    _selectionAnim.dispose();
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
    if (albumHasSelection.value) {
      albumExitSelectionTrigger.value++;
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
      albumExitSelectionTrigger.value++;
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
    if (albumHasSelection.value) {
      albumExitSelectionTrigger.value++;
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

  Future<void> _shareGallerySelected() async {
    final assets = ref.read(galleryProvider.notifier).selectedAssets;
    final paths = <String>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) paths.add(file.path);
    }
    if (paths.isNotEmpty) {
      await Share.shareXFiles(
        paths.map((path) => XFile(path)).toList(),
        text: '${paths.length} items',
      );
    }
    ref.read(galleryProvider.notifier).exitSelectionMode();
  }

  Future<void> _deleteGallerySelected() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Items?',
    );
    if (confirmed == true) {
      final assets = ref.read(galleryProvider.notifier).selectedAssets;
      try {
        await TrashService().deleteMultipleWithTrash(assets);
      } catch (_) {}
      ref.read(galleryProvider.notifier).exitSelectionMode();
      ref.read(galleryProvider.notifier).refresh();
    }
  }

  Future<void> _hideGallerySelected() async {
    final assets = ref.read(galleryProvider.notifier).selectedAssets;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(appDir.path, 'vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }
      final db = GallerioDatabase();
      int count = 0;
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;
        final vaultName = generateVaultName();
        final ext = p.extension(file.path);
        final vaultPath = p.join(vaultDir.path, '$vaultName$ext');
        await file.copy(vaultPath);
        final name = asset.title ?? 'Photo';
        await db.insertVaultItem(VaultItem(
          id: 0,
          name: name,
          encryptedPath: vaultPath,
          originalName: name,
          mimeType: asset.type == AssetType.video ? 'video' : 'image',
          size: 0,
          dateAdded: DateTime.now(),
          dateModified: DateTime.now(),
          album: 'Imported',
          iv: '',
        ));
        count++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count items moved to vault')),
        );
      }
    } catch (_) {}
    ref.read(galleryProvider.notifier).exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final isPinching = ref.watch(isPinchingProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final gallerySelection = ref.watch(
      galleryProvider.select((s) => s.isSelectionMode),
    );
    final gallerySelectedCount = ref.watch(
      galleryProvider.select((s) => s.selectedCount),
    );
    final galleryAllSelected = ref.watch(
      galleryProvider.select((s) {
        return s.displayAssets.isNotEmpty &&
            s.selectedAssetIds.length == s.displayAssets.length;
      }),
    );
    final albumSelection = albumHasSelection.value;
    final isSelectionMode = gallerySelection || albumSelection;
    final selectedCount = gallerySelection ? gallerySelectedCount : 0;
    final allSelected = gallerySelection ? galleryAllSelected : false;

    if (isSelectionMode && _selectionAnim.value == 0) {
      _selectionAnim.forward();
    } else if (!isSelectionMode && _selectionAnim.value == 1) {
      _selectionAnim.reverse();
    }

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
              animation: Listenable.merge([
                _dockAnim,
                _navbarOffsetValue,
                _selectionAnim,
              ]),
              builder: (context, _) {
                final t = Curves.easeInOutCubic.transform(_dockAnim.value);
                final navbarOffset = _navbarOffsetValue.value;
                final selT = _selectionAnim.value;

                double navWidth;
                double navLeft;

                if (selT > 0.5) {
                  navWidth = screenWidth;
                  navLeft = 0;
                } else {
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
                }

                const overshoot = 100.0;
                final statusBar = MediaQuery.of(context).padding.top;
                final topY = -(screenHeight - 72 - statusBar - 4);
                final bottomOffscreen = screenHeight + overshoot;
                final topOffscreen = -(screenHeight + overshoot);

                double selectionOffset;
                if (selT <= 0.5) {
                  final rawPhase = selT * 2;
                  final phase = Curves.easeInCubic.transform(rawPhase);
                  selectionOffset = lerpDouble(0, bottomOffscreen, phase)!;
                } else {
                  final rawPhase = (selT - 0.5) * 2;
                  final phase = Curves.easeOutCubic.transform(rawPhase);
                  selectionOffset = lerpDouble(topOffscreen, topY, phase)!;
                }

                final effectiveOffset = selT > 0.5 ? 0.0 : navbarOffset;

                return Positioned(
                  left: navLeft,
                  bottom: 0,
                  width: navWidth,
                  child: Transform.translate(
                    offset: Offset(0, effectiveOffset + selectionOffset),
                    child: GallerioNavBar(
                      currentIndex: _currentIndex,
                      previousIndex: _previousIndex,
                      dockState: _dockState,
                      dockAnimValue: _dockAnim.value,
                      onDock: isSelectionMode ? null : _onDockChanged,
                      onTap: isSelectionMode
                          ? (_) {}
                          : (index) {
                              if (index == _currentIndex) {
                                if (index == 2) {
                                  searchFocusTrigger.value++;
                                }
                                return;
                              }
                              _switchTab(index);
                            },
                      onMenuTap: isSelectionMode ? null : _onMenuTap,
                      isSelectionMode: selT > 0.5,
                      selectedCount: selectedCount,
                      allSelected: allSelected,
                      onCloseSelection: () {
                        if (gallerySelection) {
                          ref.read(galleryProvider.notifier).exitSelectionMode();
                        }
                        if (albumSelection) {
                          albumExitSelectionTrigger.value++;
                        }
                      },
                      onToggleAll: () {
                        if (gallerySelection) {
                          if (allSelected) {
                            ref.read(galleryProvider.notifier).deselectAll();
                          } else {
                            ref.read(galleryProvider.notifier).selectAll();
                          }
                        } else if (albumSelection) {
                          albumSelectAllTrigger.value++;
                        }
                      },
                      onShare: () {
                        if (gallerySelection) {
                          _shareGallerySelected();
                        } else if (albumSelection) {
                          albumShareTrigger.value++;
                        }
                      },
                      onHide: () {
                        if (gallerySelection) {
                          _hideGallerySelected();
                        } else if (albumSelection) {
                          albumHideTrigger.value++;
                        }
                      },
                      onDelete: () {
                        if (gallerySelection) {
                          _deleteGallerySelected();
                        } else if (albumSelection) {
                          albumDeleteTrigger.value++;
                        }
                      },
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
