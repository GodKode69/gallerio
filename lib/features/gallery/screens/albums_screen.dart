import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/shell_screen.dart';
import '../../../app/theme.dart';
import '../../../core/cache/thumbnail_prefetcher.dart';
import '../../../core/database/database.dart';
import '../../../core/trash/trash_service.dart';
import '../../../shared/utils/vault_utils.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/navbar_scroll_observer.dart';
import '../providers/gallery_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/staggered_animation.dart';
import '../widgets/monthly_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class AlbumsScreen extends ConsumerStatefulWidget {
  final NavbarScrollObserver? navbarObserver;
  const AlbumsScreen({super.key, this.navbarObserver});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _albumAssets = [];
  bool _isLoadingAlbum = false;
  double _scaleStart = 1.0;
  final Map<int, Offset> _pointers = {};
  ThumbnailPrefetcher? _albumPrefetcher;
  String _albumTypeFilter = 'all';
  final Set<String> _albumCollapsedMonths = {};

  final Set<String> _albumSelectedIds = {};
  bool _albumSelectionMode = false;

  final ScrollController _albumScrollController = ScrollController();
  final ScrollController _albumDetailScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    resetAlbumDetail.addListener(_onResetAlbumDetail);
    albumHasSelection.addListener(_onAlbumSelectionCleared);
  }

  @override
  void dispose() {
    resetAlbumDetail.removeListener(_onResetAlbumDetail);
    albumHasSelection.removeListener(_onAlbumSelectionCleared);
    _albumPrefetcher?.dispose();
    _albumScrollController.dispose();
    _albumDetailScrollController.dispose();
    super.dispose();
  }

  void _onAlbumSelectionCleared() {
    if (!albumHasSelection.value && _albumSelectionMode) {
      setState(() {
        _albumSelectedIds.clear();
        _albumSelectionMode = false;
      });
    }
  }

  void _onResetAlbumDetail() {
    if (_selectedAlbum != null) {
      _albumPrefetcher?.dispose();
      _albumPrefetcher = null;
      albumHasSelection.value = false;
      setState(() {
        _selectedAlbum = null;
        _albumAssets = [];
        _albumTypeFilter = 'all';
        _albumCollapsedMonths.clear();
        _albumSelectedIds.clear();
        _albumSelectionMode = false;
      });
    }
  }

  void _toggleAlbumSelection(String id) {
    setState(() {
      if (_albumSelectedIds.contains(id)) {
        _albumSelectedIds.remove(id);
      } else {
        _albumSelectedIds.add(id);
      }
      _albumSelectionMode = _albumSelectedIds.isNotEmpty;
      albumHasSelection.value = _albumSelectionMode;
    });
  }

  void _setAlbumSelection(Set<String> ids) {
    setState(() {
      _albumSelectedIds
        ..clear()
        ..addAll(ids);
      _albumSelectionMode = _albumSelectedIds.isNotEmpty;
      albumHasSelection.value = _albumSelectionMode;
    });
  }

  void _enterAlbumSelectionMode() {
    setState(() {
      _albumSelectionMode = true;
      albumHasSelection.value = true;
    });
  }

  void _exitAlbumSelectionMode() {
    setState(() {
      _albumSelectedIds.clear();
      _albumSelectionMode = false;
      albumHasSelection.value = false;
    });
  }

  void _selectAllAlbum() {
    setState(() {
      _albumSelectedIds
        ..clear()
        ..addAll(_filteredAlbumAssets.map((a) => a.id));
    });
  }

  List<AssetEntity> get _albumSelectedAssets {
    return _filteredAlbumAssets
        .where((a) => _albumSelectedIds.contains(a.id))
        .toList();
  }

  List<AssetEntity> get _filteredAlbumAssets {
    switch (_albumTypeFilter) {
      case 'photos':
        return _albumAssets.where((a) => a.type == AssetType.image).toList();
      case 'videos':
        return _albumAssets.where((a) => a.type == AssetType.video).toList();
      default:
        return _albumAssets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPermission = ref.watch(
      galleryProvider.select((s) => s.hasPermission),
    );
    final albums = ref.watch(
      galleryProvider.select((s) => s.albums),
    );
    final isLoading = ref.watch(
      galleryProvider.select((s) => s.isLoading),
    );

    if (!hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Albums')),
        body: const Center(
          child: Text(
            'No gallery permission',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_selectedAlbum != null) {
      return _buildAlbumView();
    }

    final observer = widget.navbarObserver;

    Widget gridBody = GridView.builder(
      controller: _albumScrollController,
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewPadding.bottom + 68,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return StaggeredAnimation(
          index: index,
          itemCount: albums.length,
          child: AlbumCard(
            key: ValueKey(album.id),
            album: album,
            displayName: ref
                .read(galleryProvider)
                .getAlbumDisplayName(album),
            sourceAlbums: ref
                .read(galleryProvider)
                .mergedAlbumSources[album.id] ?? [],
            onTap: () => _openAlbum(album),
          ),
        );
      },
    );

    if (observer != null) {
      gridBody = NavbarAwareScrollWrapper(
        scrollController: _albumScrollController,
        observer: observer,
        child: gridBody,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
      ),
      body: albums.isEmpty
          ? isLoading
              ? const ShimmerAlbumLoading()
              : const Center(
                  child: Text(
                    'No albums found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
          : gridBody,
    );
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    setState(() {
      _isLoadingAlbum = true;
      _selectedAlbum = album;
      _albumCollapsedMonths.clear();
    });
    ref.read(isAlbumDetailProvider.notifier).state = true;

    try {
      final sorted = await ref.read(galleryProvider.notifier).loadMergedAssets(album);

      if (!mounted) return;
      final screenWidth = MediaQuery.of(context).size.width;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final gridColumns = ref.read(galleryProvider).gridColumns;
      const spacing = 2.0;
      final cellWidth = (screenWidth - spacing * (gridColumns + 1)) / gridColumns;
      final cellPx = (cellWidth * dpr).round();

      _albumPrefetcher?.dispose();
      _albumPrefetcher = ThumbnailPrefetcher(cellPixelSize: cellPx);
      _albumPrefetcher!.updateAssets(sorted);

      setState(() {
        _albumAssets = sorted;
        _isLoadingAlbum = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAlbum = false;
        _selectedAlbum = null;
      });
      ref.read(isAlbumDetailProvider.notifier).state = false;
    }
  }

  Widget _buildAlbumTypeFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildAlbumFilterChip('Photos', 'photos'),
          const SizedBox(width: 8),
          _buildAlbumFilterChip('Videos', 'videos'),
        ],
      ),
    );
  }

  Widget _buildAlbumFilterChip(String label, String value) {
    final isSelected = _albumTypeFilter == value;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final newFilter = isSelected ? 'all' : value;
        setState(() => _albumTypeFilter = newFilter);
        final filtered = _filteredAlbumAssets;
        _albumPrefetcher?.updateAssets(filtered);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumView() {
    final gridColumns = ref.watch(
      galleryProvider.select((s) => s.gridColumns),
    );
    final observer = widget.navbarObserver;

    Widget albumContent;
    if (_isLoadingAlbum) {
      albumContent = const Center(child: CircularProgressIndicator());
    } else if (_filteredAlbumAssets.isEmpty) {
      albumContent = const Center(
        child: Text(
          'No photos in this album',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    } else {
      albumContent = Listener(
        onPointerDown: (event) {
          _pointers[event.pointer] = event.position;
          if (_pointers.length == 2) {
            ref.read(isPinchingProvider.notifier).state = true;
            final pts = _pointers.values.toList();
            _scaleStart = (pts[0] - pts[1]).distance;
          }
        },
        onPointerMove: (event) {
          _pointers[event.pointer] = event.position;
          if (_pointers.length == 2) {
            final pts = _pointers.values.toList();
            final currentDist = (pts[0] - pts[1]).distance;
            if (_scaleStart > 0) {
              final scale = currentDist / _scaleStart;
              final notifier = ref.read(galleryProvider.notifier);
              final current = ref.read(galleryProvider).gridColumns;

              if (scale > 1.225) {
                final newColumns = current - 1;
                if (newColumns >= 3 && newColumns != current) {
                  HapticFeedback.lightImpact();
                  notifier.setGridColumns(newColumns);
                  _scaleStart = currentDist;
                }
              } else if (scale < 0.775) {
                final newColumns = current + 1;
                if (newColumns <= 6 && newColumns != current) {
                  HapticFeedback.lightImpact();
                  notifier.setGridColumns(newColumns);
                  _scaleStart = currentDist;
                }
              }
            }
          }
        },
        onPointerUp: (event) {
          _pointers.remove(event.pointer);
          if (_pointers.length < 2) {
            _scaleStart = 0;
            ref.read(isPinchingProvider.notifier).state = false;
          }
        },
        onPointerCancel: (event) {
          _pointers.remove(event.pointer);
          if (_pointers.length < 2) {
            _scaleStart = 0;
            ref.read(isPinchingProvider.notifier).state = false;
          }
        },
        child: MonthlyGallery(
          assets: _filteredAlbumAssets,
          columns: gridColumns,
          selectedAssetIds: _albumSelectedIds,
          isSelectionMode: _albumSelectionMode,
          favoriteIds: ref.read(galleryProvider).favoriteIds,
          collapsedMonths: _albumCollapsedMonths,
          onCollapsedMonthsChanged: (months) {
            setState(() => _albumCollapsedMonths
              ..clear()
              ..addAll(months));
          },
          prefetcher: _albumPrefetcher,
          onToggleSelection: _toggleAlbumSelection,
          onSetSelection: _setAlbumSelection,
          onEnterSelectionMode: _enterAlbumSelectionMode,
          externalScrollController: _albumDetailScrollController,
        ),
      );

      if (observer != null) {
        albumContent = NavbarAwareScrollWrapper(
          scrollController: _albumDetailScrollController,
          observer: observer,
          child: albumContent,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _albumSelectionMode
            ? Text('${_albumSelectedIds.length} selected')
            : Text(
                _selectedAlbum != null
                    ? ref.read(galleryProvider).getAlbumDisplayName(_selectedAlbum!)
                    : 'Album',
              ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_albumSelectionMode) {
              _exitAlbumSelectionMode();
              return;
            }
            ref.read(isAlbumDetailProvider.notifier).state = false;
            albumHasSelection.value = false;
            _albumPrefetcher?.dispose();
            _albumPrefetcher = null;
            setState(() {
              _selectedAlbum = null;
              _albumAssets = [];
              _albumCollapsedMonths.clear();
              _albumSelectedIds.clear();
              _albumSelectionMode = false;
            });
          },
        ),
        actions: [
          if (_albumSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitAlbumSelectionMode,
            ),
        ],
      ),
      bottomNavigationBar: _albumSelectionMode
          ? _AlbumMultiSelectBar(
              selectedCount: _albumSelectedIds.length,
              onExit: _exitAlbumSelectionMode,
              onSelectAll: _selectAllAlbum,
              onShare: () => _shareAlbumSelected(),
              onDelete: () => _deleteAlbumSelected(),
              onVault: () => _moveAlbumSelectedToVault(),
            )
          : null,
      body: Column(
        children: [
          _buildAlbumTypeFilterChips(),
          Expanded(child: albumContent),
        ],
      ),
    );
  }

  Future<void> _shareAlbumSelected() async {
    final assets = _albumSelectedAssets;
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
    _exitAlbumSelectionMode();
  }

  Future<void> _deleteAlbumSelected() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Items?',
    );
    if (confirmed == true) {
      final assets = _albumSelectedAssets;
      try {
        await TrashService().deleteMultipleWithTrash(assets);
      } catch (_) {}
      _exitAlbumSelectionMode();
      _openAlbum(_selectedAlbum!);
    }
  }

  Future<void> _moveAlbumSelectedToVault() async {
    final assets = _albumSelectedAssets;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to move to vault')),
        );
      }
    }
    _exitAlbumSelectionMode();
  }
}

class _AlbumMultiSelectBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExit;
  final VoidCallback onSelectAll;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onVault;

  const _AlbumMultiSelectBar({
    required this.selectedCount,
    required this.onExit,
    required this.onSelectAll,
    required this.onShare,
    required this.onDelete,
    required this.onVault,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.navBarBackground,
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onExit,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$selectedCount',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          _AlbumActionButton(
            icon: Icons.select_all,
            label: 'All',
            onTap: onSelectAll,
          ),
          _AlbumActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: onShare,
          ),
          _AlbumActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: onDelete,
          ),
          _AlbumActionButton(
            icon: Icons.lock,
            label: 'Vault',
            onTap: onVault,
          ),
        ],
      ),
    );
  }
}

class _AlbumActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AlbumActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatefulWidget {
  final AssetPathEntity album;
  final String displayName;
  final List<AssetPathEntity> sourceAlbums;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.album,
    required this.displayName,
    this.sourceAlbums = const [],
    required this.onTap,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  late Future<List<AssetEntity>> _thumbnailFuture;
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    if (widget.sourceAlbums.isNotEmpty) {
      _thumbnailFuture = _loadMergedThumbnails();
      _countFuture = _loadMergedCount();
    } else {
      _thumbnailFuture = _loadSingleAlbumThumbnails();
      _countFuture = widget.album.assetCountAsync;
    }
  }

  Future<List<AssetEntity>> _loadSingleAlbumThumbnails() async {
    final count = await widget.album.assetCountAsync;
    if (count == 0) return [];
    final assets = await widget.album.getAssetListRange(start: 0, end: count);
    assets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return assets.take(4).toList();
  }

  Future<List<AssetEntity>> _loadMergedThumbnails() async {
    final futures = widget.sourceAlbums.map((src) async {
      final count = await src.assetCountAsync;
      if (count == 0) return <AssetEntity>[];
      return src.getAssetListRange(start: 0, end: count);
    });
    final results = await Future.wait(futures);
    final allAssets = results.expand((list) => list).toList();
    allAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return allAssets.take(4).toList();
  }

  Future<int> _loadMergedCount() async {
    final results = await Future.wait(
      widget.sourceAlbums.map((src) => src.assetCountAsync),
    );
    return results.fold<int>(0, (sum, c) => sum + c);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnailGrid(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FutureBuilder<int>(
            future: _countFuture,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                '$count items',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    return FutureBuilder<List<AssetEntity>>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return const Center(
            child: Icon(Icons.photo_library_outlined,
                color: Colors.white24, size: 40),
          );
        }

        if (assets.length == 1) {
          return AssetEntityImage(
            assets.first,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize.square(200),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.grey[900]);
            },
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          physics: const NeverScrollableScrollPhysics(),
          children: assets.map((asset) {
            return AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(200),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[900]);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
