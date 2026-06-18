import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/theme.dart';
import '../../../core/cache/thumbnail_prefetcher.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gallery_scroll_handle.dart';
import '../providers/gallery_provider.dart';
import '../widgets/monthly_gallery.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/multi_select_bar.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  double _scaleStart = 1.0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, Offset> _pointers = {};
  ThumbnailPrefetcher? _prefetcher;
  List<AssetEntity>? _lastDisplayAssets;
  List<MonthSection> _sections = [];
  Set<String> _collapsedMonths = {};

  @override
  void initState() {
    super.initState();
    _prefetcher = ThumbnailPrefetcher(cellPixelSize: 200);
  }

  @override
  void dispose() {
    _prefetcher?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _sectionsEquals(List<MonthSection> a, List<MonthSection> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].offset != b[i].offset || a[i].label != b[i].label) return false;
    }
    return true;
  }

  Widget _buildBody(BuildContext context) {
    final isPinching = ref.watch(isPinchingProvider);
    final displayAssets = ref.watch(
      galleryProvider.select((s) => s.displayAssets),
    );
    final gridColumns = ref.watch(
      galleryProvider.select((s) => s.gridColumns),
    );
    final isSelectionMode = ref.watch(
      galleryProvider.select((s) => s.isSelectionMode),
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    const spacing = 2.0;
    final cellWidth = (screenWidth - spacing * (gridColumns + 1)) / gridColumns;
    final cellPx = (cellWidth * dpr).round();

    _prefetcher!.cellPixelSize = cellPx;

    if (!identical(_lastDisplayAssets, displayAssets)) {
      _lastDisplayAssets = displayAssets;
      _prefetcher!.updateAssets(displayAssets);
    }

    final content = Listener(
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
      child: GalleryScrollHandle(
        scrollController: _scrollController,
        sections: _sections,
        bottomReservedHeight: MediaQuery.of(context).viewPadding.bottom + 68.0,
        child: MonthlyGallery(
          assets: displayAssets,
          columns: gridColumns,
          selectedAssetIds: ref.read(galleryProvider).selectedAssetIds,
          isSelectionMode: isSelectionMode,
          favoriteIds: ref.read(galleryProvider).favoriteIds,
          onToggleSelection: (id) =>
              ref.read(galleryProvider.notifier).toggleSelection(id),
          onSetSelection: (ids) =>
              ref.read(galleryProvider.notifier).setSelection(ids),
          onEnterSelectionMode: () =>
              ref.read(galleryProvider.notifier).enterSelectionMode(),
          externalScrollController: _scrollController,
          prefetcher: _prefetcher,
          collapsedMonths: _collapsedMonths,
          onCollapsedMonthsChanged: (months) {
            setState(() => _collapsedMonths = months);
          },
          onSectionsBuilt: (sections) {
            if (!_sectionsEquals(_sections, sections)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _sections = sections);
                }
              });
            }
          },
        ),
      ),
    );

    if (isPinching) return content;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: AppColors.navBarBackground,
      onRefresh: () async {
        await ref.read(galleryProvider.notifier).refresh();
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPermission = ref.watch(
      galleryProvider.select((s) => s.hasPermission),
    );
    final isLoading = ref.watch(
      galleryProvider.select((s) => s.isLoading),
    );
    final gridColumns = ref.watch(
      galleryProvider.select((s) => s.gridColumns),
    );
    final isSelectionMode = ref.watch(
      galleryProvider.select((s) => s.isSelectionMode),
    );
    final selectedCount = ref.watch(
      galleryProvider.select((s) => s.selectedCount),
    );
    final showFavoritesOnly = ref.watch(
      galleryProvider.select((s) => s.showFavoritesOnly),
    );
    final sortOrder = ref.watch(
      galleryProvider.select((s) => s.sortOrder),
    );
    final assets = ref.watch(
      galleryProvider.select((s) => s.assets),
    );

    return Scaffold(
      appBar: AppBar(
        title: isSelectionMode
            ? Text('$selectedCount selected')
            : const Text('Gallerio'),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(galleryProvider.notifier).exitSelectionMode(),
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                color: showFavoritesOnly
                    ? AppColors.favoriteRed
                    : AppColors.textMuted,
              ),
              onPressed: () => ref
                  .read(galleryProvider.notifier)
                  .setShowFavoritesOnly(!showFavoritesOnly),
              tooltip: showFavoritesOnly ? 'Show all' : 'Favorites',
            ),
            IconButton(
              icon: Icon(
                Icons.sort,
                color: sortOrder != SortOrder.newest
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () => SortSheet.show(context),
              tooltip: 'Sort',
            ),
          ],
        ],
      ),
      body: !hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'Gallery access required',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(galleryProvider.notifier).init(),
                    child: const Text('Grant Access'),
                  ),
                ],
              ),
            )
          : isLoading && assets.isEmpty
              ? ShimmerLoading(columns: gridColumns)
              : assets.isEmpty
                  ? const EmptyState(
                      icon: Icons.photo_library_outlined,
                      message: 'No photos found',
                    )
                  : _buildBody(context),
      bottomNavigationBar: const MultiSelectBar(),
    );
  }
}
