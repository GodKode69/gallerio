import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_sheet_drag_handle.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../core/trash/trash_service.dart';

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
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  String _currentTitle = '';
  AssetEntity? _currentAsset;

  late AnimationController _fadeController;

  static const _channel = MethodChannel('com.arqora.gallerio/open_file');

  bool get _hasSliding => widget.assetIds != null && widget.assetIds!.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentTitle = widget.title;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadCurrentAsset();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadCurrentAsset() async {
    if (widget.isVaultItem) {
      _fadeController.forward();
      return;
    }

    if (widget.assetIds != null && _currentIndex < widget.assetIds!.length) {
      final asset = await AssetEntity.fromId(widget.assetIds![_currentIndex]);
      if (asset != null && mounted) {
        setState(() => _currentAsset = asset);
      }
    } else if (widget.assetId != null) {
      final asset = await AssetEntity.fromId(widget.assetId!);
      if (asset != null && mounted) {
        setState(() => _currentAsset = asset);
      }
    }

    if (mounted) _fadeController.forward();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _showTopMessage(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 48,
        right: 48,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.sheetBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _hasSliding ? _buildPageView() : _buildSingleContent(),
          if (_showControls) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.assetIds!.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _currentAsset = null;
          _currentTitle = '';
        });
        _loadAssetAtIndex(index);
      },
      itemBuilder: (context, index) => _ViewerPage(
        assetId: widget.assetIds![index],
        isCurrentPage: index == _currentIndex,
        onTap: () {
          if (!_showControls) {
            _toggleControls();
          }
        },
      ),
    );
  }

  Future<void> _loadAssetAtIndex(int index) async {
    if (index < widget.assetIds!.length) {
      final asset = await AssetEntity.fromId(widget.assetIds![index]);
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
      return GestureDetector(
        onTap: _toggleControls,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
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
          ),
        ),
      );
    }

    if (_currentAsset != null) {
      return GestureDetector(
        onTap: _toggleControls,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
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
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
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
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final displayTitle = _currentTitle.isNotEmpty ? _currentTitle : widget.title;
    final counter = _hasSliding
        ? ' ${_currentIndex + 1}/${widget.assetIds!.length}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              '$displayTitle$counter',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomActionButton(
            icon: Icons.info_outline,
            label: 'Info',
            onTap: _showInfo,
          ),
          _buildBottomActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: _share,
          ),
          if (!widget.isVaultItem)
            _buildBottomActionButton(
              icon: Icons.wallpaper,
              label: 'Wallpaper',
              onTap: _setAsWallpaper,
            ),
          _buildBottomActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: _delete,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
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
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  Future<void> _setAsWallpaper() async {
    if (_currentAsset == null) return;

    try {
      final file = await _currentAsset!.file;
      if (file == null) return;

      await _channel.invokeMethod('setWallpaper', {
        'filePath': file.path,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting wallpaper...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set wallpaper: $e')),
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
            if (_hasSliding) {
              final newIds = List<String>.from(widget.assetIds!)
                ..removeAt(_currentIndex);
              if (newIds.isEmpty) {
                context.pop();
              } else {
                final newIndex = _currentIndex.clamp(0, newIds.length - 1);
                setState(() {
                  widget.assetIds!.removeAt(_currentIndex);
                  _currentIndex = newIndex;
                });
                _pageController = PageController(initialPage: newIndex);
                _loadCurrentAsset();
              }
            } else {
              context.pop();
            }
            _showTopMessage(context, 'Trashed');
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

  Future<Map<String, dynamic>> _getMetadata() async {
    final metadata = <String, dynamic>{};

    if (_currentAsset != null) {
      final date = _currentAsset!.createDateTime;
      metadata['date'] = DateFormat('MMM d, yyyy HH:mm').format(date);

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
  final VoidCallback? onTap;

  const _ViewerPage({
    required this.assetId,
    required this.isCurrentPage,
    this.onTap,
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
    setState(() => _isLoading = true);
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
    return GestureDetector(
      onTap: widget.onTap,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
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
        ),
      ),
    );
  }

  Widget _buildVideoPage() {
    return GestureDetector(
      onTap: () => _openInSystemPlayer(),
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

  Future<void> _openInSystemPlayer() async {
    try {
      final file = await _asset!.file;
      if (file == null) return;
      await _ViewerScreenState._channel.invokeMethod('openVideo', {
        'filePath': file.path,
        'mimeType': 'video/*',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open video: $e')),
        );
      }
    }
  }
}
