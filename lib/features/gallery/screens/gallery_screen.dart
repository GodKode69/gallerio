import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gallery_provider.dart';
import '../widgets/monthly_gallery.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/multi_select_bar.dart';
import '../widgets/timeline_scrubber.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  double _scaleStart = 1.0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, Offset> _pointers = {};
  bool _isPinching = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPermission = ref.watch(
      galleryProvider.select((s) => s.hasPermission),
    );
    final isLoading = ref.watch(
      galleryProvider.select((s) => s.isLoading),
    );
    final displayAssets = ref.watch(
      galleryProvider.select((s) => s.displayAssets),
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
    final assets = ref.watch(
      galleryProvider.select((s) => s.assets),
    );
    final showFavoritesOnly = ref.watch(
      galleryProvider.select((s) => s.showFavoritesOnly),
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
                color: showFavoritesOnly ? Colors.redAccent : Colors.white70,
              ),
              onPressed: () => ref
                  .read(galleryProvider.notifier)
                  .setShowFavoritesOnly(!showFavoritesOnly),
              tooltip: showFavoritesOnly ? 'Show all' : 'Favorites',
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () => SortSheet.show(context),
              tooltip: 'Sort',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$gridColumns',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
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
              : RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: _isPinching ? () async {} : () async {
                    await ref.read(galleryProvider.notifier).refresh();
                  },
                  child: Stack(
                    children: [
                      Listener(
                        onPointerDown: (event) {
                          _pointers[event.pointer] = event.position;
                          if (_pointers.length == 2) {
                            _isPinching = true;
                            final pts = _pointers.values.toList();
                            _scaleStart = (pts[0] - pts[1]).distance;
                          }
                        },
                        onPointerMove: (event) {
                          _pointers[event.pointer] = event.position;
                          if (_pointers.length == 2) {
                            final pts = _pointers.values.toList();
                            final currentDist =
                                (pts[0] - pts[1]).distance;
                            if (_scaleStart > 0) {
                              final scale =
                                  currentDist / _scaleStart;
                              final notifier =
                                  ref.read(galleryProvider.notifier);
                              final current =
                                  ref.read(galleryProvider).gridColumns;

                              if (scale > 1.225) {
                                final newColumns = current - 1;
                                if (newColumns >= 3 &&
                                    newColumns != current) {
                                  HapticFeedback.lightImpact();
                                  notifier.setGridColumns(newColumns);
                                  _scaleStart = currentDist;
                                }
                              } else if (scale < 0.775) {
                                final newColumns = current + 1;
                                if (newColumns <= 6 &&
                                    newColumns != current) {
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
                            _isPinching = false;
                          }
                        },
                        onPointerCancel: (event) {
                          _pointers.remove(event.pointer);
                          if (_pointers.length < 2) {
                            _scaleStart = 0;
                            _isPinching = false;
                          }
                        },
                        child: MonthlyGallery(
                          assets: displayAssets,
                          columns: gridColumns,
                          onLoadMore: () =>
                              ref.read(galleryProvider.notifier).loadMore(),
                          selectedAssetIds: ref
                              .read(galleryProvider)
                              .selectedAssetIds,
                          isSelectionMode: isSelectionMode,
                          favoriteIds:
                              ref.read(galleryProvider).favoriteIds,
                          onToggleSelection: (id) => ref
                              .read(galleryProvider.notifier)
                              .toggleSelection(id),
                          onEnterSelectionMode: () => ref
                              .read(galleryProvider.notifier)
                              .enterSelectionMode(),
                          externalScrollController: _scrollController,
                        ),
                      ),
                      if (!isSelectionMode)
                        Positioned(
                          right: 4,
                          top: 0,
                          bottom: 0,
                          child: TimelineScrubber(
                            assets: assets,
                            scrollController: _scrollController,
                          ),
                        ),
                    ],
                  ),
                ),
      bottomNavigationBar: const MultiSelectBar(),
    );
  }
}
