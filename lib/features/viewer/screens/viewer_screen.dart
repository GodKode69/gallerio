import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme.dart';
import '../../wallpaper/screens/wallpaper_preview_screen.dart';
import '../../../shared/widgets/bottom_sheet_drag_handle.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/top_message.dart';
import '../../../core/database/database.dart';
import '../../../core/trash/trash_service.dart';
import '../../../shared/utils/vault_utils.dart';
import '../../gallery/providers/gallery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vault/providers/vault_provider.dart';
import 'image_edit_screen.dart';
import 'album_picker_screen.dart';

class ViewerScreen extends StatefulWidget {
  final String? assetId;
  final String? filePath;
  final String title;
  final bool isVaultItem;
  final int? vaultItemId;
  final List<String>? assetIds;
  final int initialIndex;

  const ViewerScreen({
    super.key,
    this.assetId,
    this.filePath,
    required this.title,
    this.isVaultItem = false,
    this.vaultItemId,
    this.assetIds,
    this.initialIndex = 0,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _assetIds;
  bool _showControls = true;
  String _currentTitle = '';
  AssetEntity? _currentAsset;

  late AnimationController _fadeController;

  bool _isFavorite = false;

  final ValueNotifier<double> _imageScaleNotifier = ValueNotifier(1.0);
  double _baseScale = 1.0;
  final ValueNotifier<Offset> _imageOffsetNotifier = ValueNotifier(Offset.zero);
  final Map<int, Offset> _pointers = {};
  bool _isScaling = false;
  double _initialPinchDistance = 0;
  Offset? _pointerDownPosition;
  bool _isPanning = false;

  late AnimationController _zoomController;
  Animation<double>? _zoomAnimation;

  static const _zoomLevels = [1.0, 2.0, 3.5];
  static const _panSlop = 18.0;
  int _zoomIndex = 0;
  int _tapCount = 0;
  Timer? _tapTimer;

  bool get _hasSliding => _assetIds.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentTitle = widget.title;
    _assetIds = List<String>.from(widget.assetIds ?? []);
    _pageController = PageController(initialPage: widget.initialIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _zoomController.addListener(_onZoomTick);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadCurrentAsset();
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _zoomController.removeListener(_onZoomTick);
    _zoomController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _imageScaleNotifier.dispose();
    _imageOffsetNotifier.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onZoomTick() {
    if (_zoomAnimation != null && mounted) {
      _imageScaleNotifier.value = _zoomAnimation!.value;
      _imageOffsetNotifier.value = _clampOffset(_imageOffsetNotifier.value);
    }
  }

  Future<void> _loadCurrentAsset() async {
    if (widget.isVaultItem) {
      _fadeController.forward();
      return;
    }

    if (widget.assetIds != null && _currentIndex < _assetIds.length) {
      final asset = await AssetEntity.fromId(_assetIds[_currentIndex]);
      if (asset != null && mounted) {
        final favoriteIds = ProviderScope.containerOf(context)
            .read(galleryProvider.select((s) => s.favoriteIds));
        setState(() {
          _currentAsset = asset;
          _isFavorite = favoriteIds.contains(asset.id);
        });
      }
    } else if (widget.assetId != null) {
      final asset = await AssetEntity.fromId(widget.assetId!);
      if (asset != null && mounted) {
        final favoriteIds = ProviderScope.containerOf(context)
            .read(galleryProvider.select((s) => s.favoriteIds));
        setState(() {
          _currentAsset = asset;
          _isFavorite = favoriteIds.contains(asset.id);
        });
      }
    }

    if (mounted) _fadeController.forward();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _handleTapDown(TapDownDetails details) {
    _pointerDownPosition = details.localPosition;
    _isPanning = false;
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 150), _resolveTap);
  }

  void _resolveTap() {
    if (_isScaling || _isPanning) return;
    final count = _tapCount;
    _tapCount = 0;
    if (count == 1) {
      _toggleControls();
    } else if (count == 2) {
      _doubleTapZoom();
    } else if (count >= 3) {
      _tripleTapZoom();
    }
  }

  void _doubleTapZoom() {
    if (_zoomIndex < _zoomLevels.length - 1) {
      _zoomIndex++;
    } else {
      _zoomIndex = 0;
    }
    _animateToZoom(_zoomLevels[_zoomIndex]);
  }

  void _tripleTapZoom() {
    if (_zoomIndex > 0) {
      _zoomIndex--;
      _animateToZoom(_zoomLevels[_zoomIndex]);
    }
  }

  void _animateToZoom(double target) {
    _zoomController.stop();
    _zoomAnimation = Tween<double>(begin: _imageScaleNotifier.value, end: target).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    _zoomController.forward(from: 0.0);
  }

  void _resetZoom() {
    if (_imageScaleNotifier.value == 1.0 && _imageOffsetNotifier.value == Offset.zero) return;
    _zoomController.stop();
    final startScale = _imageScaleNotifier.value;
    final startOffset = _imageOffsetNotifier.value;
    _zoomAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    void resetListener() {
      if (mounted) {
        final t = _zoomAnimation!.value;
        _imageScaleNotifier.value = startScale + (1.0 - startScale) * t;
        _imageOffsetNotifier.value = startOffset * (1.0 - t);
      }
    }
    _zoomController.removeListener(_onZoomTick);
    _zoomController.addListener(resetListener);
    _zoomController.forward(from: 0.0).then((_) {
      _zoomController.removeListener(resetListener);
      _zoomController.addListener(_onZoomTick);
      _imageScaleNotifier.value = 1.0;
      _imageOffsetNotifier.value = Offset.zero;
      _zoomIndex = 0;
      setState(() {});
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _zoomController.stop();
      _isScaling = true;
      _tapTimer?.cancel();
      _tapCount = 0;
      _baseScale = _imageScaleNotifier.value;
      final pts = _pointers.values.toList();
      _initialPinchDistance = (pts[0] - pts[1]).distance;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_isScaling && _pointers.length >= 2 && _initialPinchDistance > 0) {
      final pts = _pointers.values.toList();
      final currentDist = (pts[0] - pts[1]).distance;
      final newScale = (_baseScale * currentDist / _initialPinchDistance).clamp(1.0, 4.0);
      _imageScaleNotifier.value = newScale;
      _imageOffsetNotifier.value = _clampOffset(_imageOffsetNotifier.value);
    } else if (_pointers.length == 1 && _imageScaleNotifier.value > 1.01) {
      if (_pointerDownPosition != null) {
        final dist = (event.localPosition - _pointerDownPosition!).distance;
        if (dist > _panSlop && !_isPanning) {
          _isPanning = true;
          _tapTimer?.cancel();
        }
      }
      _imageOffsetNotifier.value = _clampOffset(_imageOffsetNotifier.value + event.delta);
    }
  }

  Offset _clampOffset(Offset offset) {
    final viewSize = MediaQuery.of(context).size;
    final maxDx = (viewSize.width * (_imageScaleNotifier.value - 1)) / 2;
    final maxDy = (viewSize.height * (_imageScaleNotifier.value - 1)) / 2;
    return Offset(
      offset.dx.clamp(-maxDx, maxDx),
      offset.dy.clamp(-maxDy, maxDy),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _isScaling = false;
    }
    if (_pointers.isEmpty) {
      _isPanning = false;
      _pointerDownPosition = null;
      if (_imageScaleNotifier.value <= 1.01) {
        _imageScaleNotifier.value = 1.0;
        _imageOffsetNotifier.value = Offset.zero;
        _zoomIndex = 0;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: _handleTapDown,
              child: ListenableBuilder(
                listenable: Listenable.merge([_imageScaleNotifier, _imageOffsetNotifier]),
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(_imageOffsetNotifier.value.dx, _imageOffsetNotifier.value.dy, 0.0, 1.0)
                      ..scaleByDouble(_imageScaleNotifier.value, _imageScaleNotifier.value, 1.0, 1.0),
                    child: child,
                  );
                },
                child: _hasSliding ? _buildPageView() : _buildSingleContent(),
              ),
            ),
          ),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: _imageScaleNotifier.value > 1.01
          ? const NeverScrollableScrollPhysics()
          : null,
      itemCount: _assetIds.length,
      onPageChanged: (index) {
        _resetZoom();
        setState(() {
          _currentIndex = index;
          _currentAsset = null;
          _currentTitle = '';
        });
        _loadAssetAtIndex(index);
      },
      itemBuilder: (context, index) => _ViewerPage(
        assetId: _assetIds[index],
        isCurrentPage: index == _currentIndex,
      ),
    );
  }

  Future<void> _loadAssetAtIndex(int index) async {
    if (index < _assetIds.length) {
      final asset = await AssetEntity.fromId(_assetIds[index]);
      if (asset != null && mounted) {
        setState(() {
          _currentAsset = asset;
          _currentTitle = asset.title ?? 'Photo';
        });
      }
    }
  }

  Widget _buildSingleContent() {
    if (widget.isVaultItem && widget.filePath != null) {
      return Center(
        child: Image.file(
          File(widget.filePath!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.broken_image,
              color: Colors.white24,
              size: 64,
            );
          },
        ),
      );
    }

    if (_currentAsset != null) {
      return Center(
        child: Hero(
          tag: 'gallery-thumb-${_currentAsset!.id}',
          child: AssetEntityImage(
            _currentAsset!,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize.square(800),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image,
                color: Colors.white24,
                size: 64,
              );
            },
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black54,
              ],
              stops: [0, 0.2, 0.8, 1],
            ),
          ),
          child: Column(
            children: [
              SafeArea(
                child: AnimatedSlide(
                  offset: _showControls ? Offset.zero : const Offset(0, -0.3),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _buildTopBar(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                ),
              ),
              AnimatedSlide(
                offset: _showControls ? Offset.zero : const Offset(0, 0.5),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final displayTitle = _currentTitle.isNotEmpty ? _currentTitle : widget.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              displayTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hasSliding)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${_currentIndex + 1}/${_assetIds.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.chipBackground.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!widget.isVaultItem)
              _buildBottomActionButton(
                icon: Icons.crop_rotate,
                label: 'Edit',
                onTap: _edit,
              ),
            _buildBottomActionButton(
              icon: Icons.share,
              label: 'Share',
              onTap: _share,
            ),
            _buildBottomActionButton(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
              label: 'Fav',
              iconColor: _isFavorite ? AppColors.favoriteRed : null,
              onTap: _toggleFavorite,
            ),
            _buildBottomActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              iconColor: AppColors.favoriteRed,
              onTap: _delete,
            ),
            _buildBottomActionButton(
              icon: Icons.more_horiz,
              label: 'More',
              onTap: _showMoreOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: iconColor ?? Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_currentAsset != null) {
      final galleryRef = ProviderScope.containerOf(context).read(galleryProvider.notifier);
      await galleryRef.toggleFavorite(_currentAsset!.id);
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }
  }

  Future<void> _share() async {
    try {
      String? path;
      if (widget.isVaultItem && widget.filePath != null) {
        path = widget.filePath;
      } else if (_currentAsset != null) {
        final file = await _currentAsset!.file;
        path = file?.path;
      }

      if (path != null) {
        await Share.shareXFiles([XFile(path)], text: _currentTitle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share')),
        );
      }
    }
  }

  Future<void> _setAsWallpaper() async {
    if (_currentAsset == null) return;

    try {
      final file = await _currentAsset!.file;
      if (file == null) return;
      if (!mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WallpaperPreviewScreen(
          filePath: file.path,
          title: _currentTitle,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load image')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete?',
    );

    if (confirmed == true && mounted) {
      try {
        if (_currentAsset != null) {
          final success = await TrashService().deleteWithTrash(_currentAsset!);
          if (success && mounted) {
            ProviderScope.containerOf(context)
                .read(galleryProvider.notifier)
                .refresh();
            if (_hasSliding) {
              final newIds = List<String>.from(_assetIds)..removeAt(_currentIndex);
              if (newIds.isEmpty) {
                Navigator.of(context).pop();
              } else {
                final newIndex = _currentIndex.clamp(0, newIds.length - 1);
                final updatedIds = List<String>.from(_assetIds)..removeAt(_currentIndex);
                setState(() {
                  _currentIndex = newIndex;
                });
                _assetIds.clear();
                _assetIds.addAll(updatedIds);
                _pageController.dispose();
                _pageController = PageController(initialPage: newIndex);
                _loadCurrentAsset();
              }
            } else {
              Navigator.of(context).pop();
            }
            showTopMessage(context, 'Moved to trash');
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Could not delete. Grant storage permission in Settings.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')),
          );
        }
      }
    }
  }

  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _getMetadata(),
        builder: (context, snapshot) {
          final metadata = snapshot.data ?? {};
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetDragHandle(),
                const SizedBox(height: 20),
                const Text(
                  'Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow('Name', _currentTitle),
                _infoRow('Type', _currentAsset?.type == AssetType.video ? 'Video' : 'Image'),
                if (metadata['date'] != null)
                  _infoRow('Date', metadata['date']),
                if (metadata['size'] != null)
                  _infoRow('Size', metadata['size']),
                if (metadata['dimensions'] != null)
                  _infoRow('Dimensions', metadata['dimensions']),
                if (widget.isVaultItem) _infoRow('Location', 'Vault'),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit() async {
    if (_currentAsset == null) return;

    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ImageEditScreen(
            asset: _currentAsset,
            title: _currentTitle,
          ),
        ),
      );

      if (result != null && mounted) {
        final newAsset = await AssetEntity.fromId(result);
        if (newAsset != null && _hasSliding) {
          final newIds = List<String>.from(_assetIds)..insert(_currentIndex + 1, result);
          setState(() {
            _assetIds.clear();
            _assetIds.addAll(newIds);
            _currentIndex = _currentIndex + 1;
            _currentAsset = newAsset;
            _currentTitle = newAsset.title ?? 'Edited';
          });
          _pageController.dispose();
          _pageController = PageController(initialPage: _currentIndex);
        } else {
          setState(() {
            _currentAsset = newAsset;
            _currentTitle = newAsset?.title ?? 'Edited';
          });
          _loadCurrentAsset();
        }
        if (!mounted) return;
        ProviderScope.containerOf(context).read(galleryProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Could not open editor');
      }
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetDragHandle(),
            const SizedBox(height: 16),
            _buildMoreOption(
              icon: Icons.edit,
              label: 'Rename',
              onTap: () {
                Navigator.of(context).pop();
                _rename();
              },
            ),
            _buildMoreOption(
              icon: Icons.info_outline,
              label: 'Info',
              onTap: () {
                Navigator.of(context).pop();
                _showInfo();
              },
            ),
            if (!widget.isVaultItem) ...[
              _buildMoreOption(
                icon: Icons.visibility_off,
                label: 'Hide',
                onTap: () {
                  Navigator.of(context).pop();
                  _hideToVault();
                },
              ),
              _buildMoreOption(
                icon: Icons.wallpaper,
                label: 'Set as wallpaper',
                onTap: () {
                  Navigator.of(context).pop();
                  _setAsWallpaper();
                },
              ),
              _buildMoreOption(
                icon: Icons.content_copy,
                label: 'Copy to clipboard',
                onTap: () {
                  Navigator.of(context).pop();
                  _copyToClipboard();
                },
              ),
              _buildMoreOption(
                icon: Icons.file_copy,
                label: 'Copy to album',
                onTap: () {
                  Navigator.of(context).pop();
                  _copyToAlbum();
                },
              ),
              _buildMoreOption(
                icon: Icons.drive_file_move,
                label: 'Move to album',
                onTap: () {
                  Navigator.of(context).pop();
                  _moveToAlbum();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: onTap,
    );
  }

  Future<void> _rename() async {
    final nameController = TextEditingController(
      text: _currentTitle.contains('.') ? _currentTitle.substring(0, _currentTitle.lastIndexOf('.')) : _currentTitle,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sheetBackground,
        title: const Text('Rename', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.favoriteRed),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Rename', style: TextStyle(color: AppColors.favoriteRed)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    if (widget.isVaultItem && widget.filePath != null) {
      try {
        final file = File(widget.filePath!);
        final ext = file.path.contains('.') ? file.path.substring(file.path.lastIndexOf('.')) : '';
        final newPath = '${file.parent.path}/$newName$ext';
        await file.rename(newPath);
        setState(() {
          _currentTitle = '$newName$ext';
        });
        if (!mounted) return;
        showTopMessage(context, 'Renamed');
      } catch (e) {
        if (!mounted) return;
        showTopMessage(context, 'Rename failed');
      }
      return;
    }

    if (_currentAsset == null) return;

    try {
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            if (mounted) {
              showTopMessage(context, 'Files permission needed to rename');
            }
            return;
          }
        }
      }

      final ext = _currentTitle.contains('.')
          ? _currentTitle.substring(_currentTitle.lastIndexOf('.'))
          : '';
      const channel = MethodChannel('com.arqora.gallerio/open_file');
      await channel.invokeMethod('renameAsset', {
        'assetId': _currentAsset!.id,
        'newName': '$newName$ext',
      });

      setState(() {
        _currentTitle = '$newName$ext';
      });
      if (!mounted) return;
      showTopMessage(context, 'Renamed');
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Rename failed: $e');
      }
    }
  }

  Future<void> _hideToVault() async {
    if (_currentAsset == null) return;

    final authState = ProviderScope.containerOf(context).read(authStateProvider);
    if (!authState.isVaultEnabled || !authState.hasVaultCode) {
      showTopMessage(context, 'Enable vault security in Settings first');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sheetBackground,
        title: const Text('Hide?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will move the image to vault and remove it from the gallery.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hide', style: TextStyle(color: AppColors.favoriteRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final file = await _currentAsset!.file;
      if (!mounted) return;
      if (file == null) {
        showTopMessage(context, 'Could not access file');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final thumbDir = Directory('${appDir.path}/vault/thumbs');
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final vaultName = generateVaultName();
      final ext = file.path.contains('.') ? file.path.substring(file.path.lastIndexOf('.')) : '';
      final vaultPath = '${vaultDir.path}/$vaultName$ext';

      await file.copy(vaultPath);

      String? thumbnailPath;
      try {
        final thumbPath = '${thumbDir.path}/$vaultName$ext';
        await file.copy(thumbPath);
        thumbnailPath = thumbPath;
      } catch (_) {}

      final db = GallerioDatabase();
      final name = _currentAsset!.title ?? 'Photo';
      await db.insertVaultItem(VaultItem(
        id: 0,
        name: name,
        encryptedPath: vaultPath,
        originalName: name,
        mimeType: _currentAsset!.type == AssetType.video ? 'video' : 'image',
        size: 0,
        dateAdded: DateTime.now(),
        dateModified: DateTime.now(),
        album: 'Imported',
        iv: '',
        thumbnailPath: thumbnailPath,
      ));

      await TrashService().deleteWithTrash(_currentAsset!);

      if (mounted) {
        ProviderScope.containerOf(context).read(galleryProvider.notifier).refresh();
        ProviderScope.containerOf(context).read(vaultProvider.notifier).refresh();
        showTopMessage(context, 'Moved to vault');

        if (_hasSliding) {
          final newIds = List<String>.from(_assetIds)..removeAt(_currentIndex);
          if (newIds.isEmpty) {
            Navigator.of(context).pop();
          } else {
            final newIndex = _currentIndex.clamp(0, newIds.length - 1);
            setState(() {
              _currentIndex = newIndex;
              _assetIds.clear();
              _assetIds.addAll(newIds);
            });
            _pageController.dispose();
            _pageController = PageController(initialPage: newIndex);
            _loadCurrentAsset();
          }
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Failed to hide: $e');
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_currentAsset == null) return;

    try {
      final file = await _currentAsset!.file;
      if (!mounted) return;
      if (file == null) {
        showTopMessage(context, 'Could not access file');
        return;
      }

      const channel = MethodChannel('com.arqora.gallerio/open_file');
      final result = await channel.invokeMethod('copyImageToClipboard', {
        'filePath': file.path,
      });
      final sdkInt = (result as Map?)?['sdkInt'] as int? ?? 0;

      if (mounted && sdkInt < 33) {
        showTopMessage(context, 'Copied to clipboard');
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Failed to copy');
      }
    }
  }

  Future<void> _copyToAlbum() async {
    if (_currentAsset == null) return;

    if (!mounted) return;

    final result = await Navigator.of(context).push<AlbumPickerResult>(
      MaterialPageRoute(
        builder: (_) => const AlbumPickerScreen(isMove: false),
      ),
    );

    if (result == null || !mounted) return;

    try {
      await PhotoManager.editor.copyAssetToPath(
        asset: _currentAsset!,
        pathEntity: result.album,
      );
      if (mounted) {
        showTopMessage(context, 'Copied to ${result.album.name}');
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Copy failed: $e');
      }
    }
  }

  Future<void> _moveToAlbum() async {
    if (_currentAsset == null) return;

    if (!mounted) return;

    final result = await Navigator.of(context).push<AlbumPickerResult>(
      MaterialPageRoute(
        builder: (_) => const AlbumPickerScreen(isMove: true),
      ),
    );

    if (result == null || !mounted) return;

    try {
      await PhotoManager.editor.copyAssetToPath(
        asset: _currentAsset!,
        pathEntity: result.album,
      );

      final deleted = await TrashService().deleteWithTrash(_currentAsset!);

      if (mounted) {
        ProviderScope.containerOf(context).read(galleryProvider.notifier).refresh();

        if (deleted) {
          showTopMessage(context, 'Moved to ${result.album.name}');
        } else {
          showTopMessage(context, 'Copied but original not removed');
        }

        if (_hasSliding) {
          final newIds = List<String>.from(_assetIds)..removeAt(_currentIndex);
          if (newIds.isEmpty) {
            Navigator.of(context).pop();
          } else {
            final newIndex = _currentIndex.clamp(0, newIds.length - 1);
            setState(() {
              _currentIndex = newIndex;
              _assetIds.clear();
              _assetIds.addAll(newIds);
            });
            _pageController.dispose();
            _pageController = PageController(initialPage: newIndex);
            _loadCurrentAsset();
          }
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Move failed: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _getMetadata() async {
    final metadata = <String, dynamic>{};

    if (_currentAsset != null) {
      final date = _currentAsset!.createDateTime;
      metadata['date'] = _formatDate(date);

      if (_currentAsset!.type == AssetType.video) {
        final duration = _currentAsset!.videoDuration;
        metadata['size'] =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      }

      metadata['dimensions'] = '${_currentAsset!.width}x${_currentAsset!.height}';
    }

    return metadata;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  final String assetId;
  final bool isCurrentPage;

  const _ViewerPage({
    required this.assetId,
    required this.isCurrentPage,
  });

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage>
    with AutomaticKeepAliveClientMixin {
  AssetEntity? _asset;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(covariant _ViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _loadAsset();
    }
  }

  Future<void> _loadAsset() async {
    final asset = await AssetEntity.fromId(widget.assetId);
    if (mounted) {
      setState(() {
        _asset = asset;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_asset == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
      );
    }

    if (_asset!.type == AssetType.video) {
      return _buildVideoPage();
    }

    return _buildImagePage();
  }

  Widget _buildImagePage() {
    return Center(
      child: AssetEntityImage(
        _asset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(800),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image,
            color: Colors.white24,
            size: 64,
          );
        },
      ),
    );
  }

  Widget _buildVideoPage() {
    return Center(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: AssetEntityImage(
                _asset!,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(400),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.broken_image,
                        color: Colors.white24),
                  );
                },
              ),
            ),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
