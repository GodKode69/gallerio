import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../app/shell_screen.dart';
import '../../../app/theme.dart';
import '../providers/gallery_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/staggered_animation.dart';
import '../widgets/gallery_thumbnail.dart';

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _albumAssets = [];
  bool _isLoadingAlbum = false;
  double _scaleStart = 1.0;
  final Map<int, Offset> _pointers = {};
  bool _isDragging = false;
  final Set<String> _dragSelectedIds = {};
  String? _lastDraggedAssetId;

  @override
  void initState() {
    super.initState();
    resetAlbumDetail.addListener(_onResetAlbumDetail);
  }

  @override
  void dispose() {
    resetAlbumDetail.removeListener(_onResetAlbumDetail);
    super.dispose();
  }

  void _onResetAlbumDetail() {
    if (_selectedAlbum != null) {
      setState(() {
        _selectedAlbum = null;
        _albumAssets = [];
      });
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
    final favoriteIds = ref.watch(
      galleryProvider.select((s) => s.favoriteIds),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          if (favoriteIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.favorite, color: AppColors.favoriteRed),
              onPressed: () {
                ref.read(galleryProvider.notifier).setShowFavoritesOnly(true);
                context.go('/search');
              },
              tooltip: 'Favorites',
            ),
        ],
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
          : GridView.builder(
              padding: const EdgeInsets.all(12),
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
                    onTap: () => _openAlbum(album),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    setState(() {
      _isLoadingAlbum = true;
      _selectedAlbum = album;
    });
    ref.read(isAlbumDetailProvider.notifier).state = true;

    try {
      final assets = await album.getAssetListPaged(page: 0, size: 200);
      setState(() {
        _albumAssets = assets.toList()
          ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
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

  void _onDragStart(Offset globalPosition, BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = screenWidth / ref.read(galleryProvider).gridColumns;

    final colIndex = (localPosition.dx / cellSize).floor();
    final rowIndex = (localPosition.dy / cellSize).floor();
    final flatIndex = rowIndex * ref.read(galleryProvider).gridColumns + colIndex;

    if (flatIndex >= 0 && flatIndex < _albumAssets.length) {
      _isDragging = true;
      _dragSelectedIds.clear();
      _dragSelectedIds.add(_albumAssets[flatIndex].id);
      _lastDraggedAssetId = _albumAssets[flatIndex].id;
      ref.read(galleryProvider.notifier).enterSelectionMode();
      ref.read(galleryProvider.notifier).toggleSelection(_albumAssets[flatIndex].id);
    }
  }

  void _onDragUpdate(Offset globalPosition, BuildContext context) {
    if (!_isDragging) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = screenWidth / ref.read(galleryProvider).gridColumns;

    final colIndex = (localPosition.dx / cellSize).floor();
    final rowIndex = (localPosition.dy / cellSize).floor();
    final flatIndex = rowIndex * ref.read(galleryProvider).gridColumns + colIndex;

    if (flatIndex >= 0 && flatIndex < _albumAssets.length) {
      final assetId = _albumAssets[flatIndex].id;
      if (assetId != _lastDraggedAssetId) {
        _lastDraggedAssetId = assetId;

        final newDragIds = <String>{assetId};
        if (_dragSelectedIds.isNotEmpty) {
          final lastId = _dragSelectedIds.last;
          final lastIndex = _albumAssets.indexWhere((a) => a.id == lastId);
          final currentIndex = _albumAssets.indexWhere((a) => a.id == assetId);

          if (lastIndex >= 0 && currentIndex >= 0) {
            final start = lastIndex < currentIndex ? lastIndex : currentIndex;
            final end = lastIndex < currentIndex ? currentIndex : lastIndex;
            for (int i = start; i <= end; i++) {
              newDragIds.add(_albumAssets[i].id);
            }
          }
        }

        final toSelect = newDragIds.difference(_dragSelectedIds);
        final toDeselect = _dragSelectedIds.difference(newDragIds);

        _dragSelectedIds
          ..clear()
          ..addAll(newDragIds);

        for (final id in toSelect) {
          if (!ref.read(galleryProvider).selectedAssetIds.contains(id)) {
            ref.read(galleryProvider.notifier).toggleSelection(id);
          }
        }
        for (final id in toDeselect) {
          if (ref.read(galleryProvider).selectedAssetIds.contains(id)) {
            ref.read(galleryProvider.notifier).toggleSelection(id);
          }
        }
      }
    }
  }

  void _onDragEnd() {
    _isDragging = false;
    _dragSelectedIds.clear();
    _lastDraggedAssetId = null;
  }

  Widget _buildAlbumView() {
    final gridColumns = ref.watch(
      galleryProvider.select((s) => s.gridColumns),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedAlbum?.name ?? 'Album'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(isAlbumDetailProvider.notifier).state = false;
            setState(() {
              _selectedAlbum = null;
              _albumAssets = [];
            });
          },
        ),
        actions: [],
      ),
      body: _isLoadingAlbum
          ? const Center(child: CircularProgressIndicator())
          : _albumAssets.isEmpty
              ? const Center(
                  child: Text(
                    'No photos in this album',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Listener(
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
                  child: GestureDetector(
                    onLongPressStart: (details) => _onDragStart(details.globalPosition, context),
                    onLongPressMoveUpdate: (details) => _onDragUpdate(details.globalPosition, context),
                    onLongPressEnd: (_) => _onDragEnd(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: _albumAssets.length,
                      itemBuilder: (context, index) {
                        final asset = _albumAssets[index];
                        final isSelectionMode = ref.watch(
                          galleryProvider.select((s) => s.isSelectionMode),
                        );
                        final selectedAssetIds = ref.watch(
                          galleryProvider.select((s) => s.selectedAssetIds),
                        );

                        return GalleryThumbnail(
                          asset: asset,
                          enableHero: true,
                          isSelected: selectedAssetIds.contains(asset.id),
                          showSelection: isSelectionMode,
                          onTap: () {
                            if (isSelectionMode) {
                              ref.read(galleryProvider.notifier).toggleSelection(asset.id);
                            } else {
                              context.push('/viewer', extra: {
                                'assetId': asset.id,
                                'title': asset.title ?? 'Photo',
                                'assetIds': _albumAssets.map((a) => a.id).toList(),
                                'initialIndex': index,
                              });
                            }
                          },
                          onLongPress: () {
                            if (!isSelectionMode) {
                              ref.read(galleryProvider.notifier).enterSelectionMode();
                              ref.read(galleryProvider.notifier).toggleSelection(asset.id);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

class AlbumCard extends StatefulWidget {
  final AssetPathEntity album;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.album,
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
    _thumbnailFuture = widget.album.getAssetListPaged(page: 0, size: 4);
    _countFuture = widget.album.assetCountAsync;
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
            widget.album.name,
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
