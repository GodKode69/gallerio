import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ViewerScreen extends StatefulWidget {
  final String? assetId;
  final String? filePath;
  final String title;
  final bool isVaultItem;
  final int? vaultItemId;

  const ViewerScreen({
    super.key,
    this.assetId,
    this.filePath,
    required this.title,
    this.isVaultItem = false,
    this.vaultItemId,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with SingleTickerProviderStateMixin {
  AssetEntity? _asset;
  bool _isVideo = false;
  bool _showControls = true;
  bool _isInitialized = false;
  String? _filePath;
  bool _fullQualityLoaded = false;

  late AnimationController _fadeController;

  static const _channel = MethodChannel('com.example.gallerio/open_file');

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initMedia();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (widget.isVaultItem && _filePath != null) {
      _cleanupTempFile();
    }
    super.dispose();
  }

  void _cleanupTempFile() {
    try {
      final file = File(_filePath!);
      if (file.existsSync() && file.path.contains('/dec_')) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  Future<void> _initMedia() async {
    if (widget.isVaultItem && widget.filePath != null) {
      final file = File(widget.filePath!);
      if (!await file.exists()) return;

      _filePath = widget.filePath;
      final ext = file.path.split('.').last.toLowerCase();
      _isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
    } else if (widget.assetId != null) {
      final asset = await AssetEntity.fromId(widget.assetId!);
      if (asset == null) return;
      _asset = asset;
      _isVideo = asset.type == AssetType.video;

      if (_isVideo) {
        final file = await asset.file;
        _filePath = file?.path;
      }
    }

    if (mounted) {
      setState(() => _isInitialized = true);
      _fadeController.forward();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _onImageTap() {
    if (!_fullQualityLoaded && _asset != null && !_isVideo) {
      setState(() => _fullQualityLoaded = true);
    }
    _toggleControls();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _onImageTap,
            child: _buildContent(),
          ),
          if (_showControls) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isVideo) {
      return _buildVideoThumbnail();
    }

    if (widget.isVaultItem && _filePath != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            File(_filePath!),
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
      );
    }

    if (widget.assetId != null && _asset != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Hero(
            tag: 'gallery-thumb-${_asset!.id}',
            child: AssetEntityImage(
              _asset!,
              isOriginal: _fullQualityLoaded,
              thumbnailSize: _fullQualityLoaded
                  ? ThumbnailSize(_asset!.width, _asset!.height)
                  : ThumbnailSize(
                      (_asset!.width * 0.1).round().clamp(200, 800),
                      (_asset!.height * 0.1).round().clamp(200, 800),
                    ),
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

    return const Center(
      child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
    );
  }

  Widget _buildVideoThumbnail() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_asset != null)
            AspectRatio(
              aspectRatio: 1,
              child: Hero(
                tag: 'gallery-thumb-${_asset!.id}',
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
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _openInSystemPlayer,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to play in default player',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInSystemPlayer() async {
    if (_filePath == null) return;

    try {
      await _channel.invokeMethod('openVideo', {
        'filePath': _filePath,
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
              widget.title,
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
      if (widget.isVaultItem && _filePath != null) {
        path = _filePath;
      } else if (_asset != null) {
        final file = await _asset!.file;
        path = file?.path;
      }

      if (path != null) {
        await Share.shareXFiles([XFile(path)], text: widget.title);
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
    if (_asset == null) return;

    try {
      final file = await _asset!.file;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        if (_asset != null) {
          await PhotoManager.editor.deleteWithIds([_asset!.id]);
        }
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted')),
          );
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
      backgroundColor: const Color(0xFF1D1D1D),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
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
                _infoRow('Name', widget.title),
                _infoRow('Type', _isVideo ? 'Video' : 'Image'),
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

    if (_asset != null) {
      final date = _asset!.createDateTime;
      metadata['date'] = DateFormat('MMM d, yyyy HH:mm').format(date);

      if (_asset!.type == AssetType.video) {
        final duration = _asset!.videoDuration;
        metadata['size'] =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      }

      metadata['dimensions'] = '${_asset!.width}x${_asset!.height}';
    } else if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        final stat = await file.stat();
        metadata['size'] = _formatFileSize(stat.size);
        metadata['date'] =
            DateFormat('MMM d, yyyy HH:mm').format(stat.modified);
      }
    }

    return metadata;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
