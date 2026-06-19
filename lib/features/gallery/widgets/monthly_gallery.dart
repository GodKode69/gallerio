import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/router.dart';
import '../../../core/cache/thumbnail_prefetcher.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gallery_scroll_handle.dart';
import 'gallery_thumbnail.dart';

const double _kHeaderHeight = 48.0;
const double _kAutoScrollEdgeZone = 80.0;
const double _kAutoScrollMaxSpeed = 20.0;

class MonthlyGallery extends StatefulWidget {
  final List<AssetEntity> assets;
  final int columns;
  final Set<String> selectedAssetIds;
  final bool isSelectionMode;
  final Set<String> favoriteIds;
  final Set<String> collapsedMonths;
  final ValueChanged<String>? onToggleSelection;
  final ValueChanged<Set<String>>? onSetSelection;
  final VoidCallback? onEnterSelectionMode;
  final ValueChanged<String>? onToggleFavorite;
  final ScrollController? externalScrollController;
  final ThumbnailPrefetcher? prefetcher;
  final ValueChanged<Set<String>>? onCollapsedMonthsChanged;
  final ValueChanged<List<MonthSection>>? onSectionsBuilt;

  const MonthlyGallery({
    super.key,
    required this.assets,
    required this.collapsedMonths,
    this.columns = 5,
    this.selectedAssetIds = const {},
    this.isSelectionMode = false,
    this.favoriteIds = const {},
    this.onToggleSelection,
    this.onSetSelection,
    this.onEnterSelectionMode,
    this.onToggleFavorite,
    this.externalScrollController,
    this.prefetcher,
    this.onCollapsedMonthsChanged,
    this.onSectionsBuilt,
  });

  @override
  State<MonthlyGallery> createState() => _MonthlyGalleryState();
}

class _MonthlyGalleryState extends State<MonthlyGallery> {
  late ScrollController _scrollController;
  List<_ListItem>? _cachedItems;
  List<AssetEntity>? _lastAssets;

  int _dragStartIndex = -1;
  bool _isDragging = false;
  Offset? _lastFingerPosition;
  Ticker? _autoScrollTicker;
  double _autoScrollSpeed = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.externalScrollController ?? ScrollController();
    _scrollController.addListener(_onScrollForPrefetch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushVisibleIds();
      _emitSections(_cachedItems ?? _buildFlatList(widget.assets));
    });
  }

  bool _collapsedMonthsChanged(Set<String> a, Set<String> b) {
    if (a.length != b.length) return true;
    return !a.containsAll(b);
  }

  @override
  void didUpdateWidget(covariant MonthlyGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.assets, widget.assets) ||
        oldWidget.columns != widget.columns ||
        _collapsedMonthsChanged(oldWidget.collapsedMonths, widget.collapsedMonths)) {
      _cachedItems = null;
      _lastAssets = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emitSections(_cachedItems ?? _buildFlatList(widget.assets));
      });
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.removeListener(_onScrollForPrefetch);
    if (widget.externalScrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScrollForPrefetch() {
    _pushVisibleIds();
  }

  void _pushVisibleIds() {
    if (!mounted || widget.prefetcher == null || !_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    final viewportHeight = MediaQuery.of(context).size.height;
    final items = _cachedItems ?? _buildFlatList(widget.assets);

    final visibleIds = <String>{};
    double y = 0;
    for (final item in items) {
      final h = item.height;
      if (item is _RowItem && y + h > offset && y < offset + viewportHeight) {
        for (final a in item.assets) {
          visibleIds.add(a.id);
        }
      }
      y += h;
    }
    widget.prefetcher!.updateVisibleIds(visibleIds);
  }

  int _getGlobalIndexAtPosition(Offset globalPosition, BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return -1;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final screenWidth = MediaQuery.of(context).size.width;
    const spacing = 2.0;
    final cellWidth = (screenWidth - spacing * (widget.columns + 1)) / widget.columns;
    final cellHeight = cellWidth;

    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final adjustedY = localPosition.dy + scrollOffset;

    final items = _buildFlatList(widget.assets);
    double currentY = 0;

    for (final item in items) {
      if (item is _HeaderItem) {
        currentY += _kHeaderHeight;
        continue;
      }
      if (item is _CollapsedMonthItem) continue;

      final row = item as _RowItem;
      if (adjustedY >= currentY && adjustedY < currentY + cellHeight) {
        final colIndex = ((localPosition.dx - spacing) / (cellWidth + spacing)).floor();
        if (colIndex >= 0 && colIndex < row.assets.length) {
          return widget.assets.indexOf(row.assets[colIndex]);
        }
      }
      currentY += cellHeight + spacing;
    }
    return -1;
  }

  void _onDragStart(Offset globalPosition, BuildContext context) {
    final index = _getGlobalIndexAtPosition(globalPosition, context);
    if (index < 0 || index >= widget.assets.length) return;

    _dragStartIndex = index;
    _isDragging = true;
    _lastFingerPosition = globalPosition;

    if (!widget.isSelectionMode) {
      widget.onEnterSelectionMode?.call();
    }

    final newIds = {widget.assets[index].id};
    widget.onSetSelection?.call(newIds);
  }

  void _onDragUpdate(Offset globalPosition, BuildContext context) {
    if (!_isDragging) return;

    _lastFingerPosition = globalPosition;
    final index = _getGlobalIndexAtPosition(globalPosition, context);
    if (index < 0 || index >= widget.assets.length) return;

    _updateSelectionForRange(index);
    _checkAutoScroll(globalPosition, context);
  }

  void _onDragEnd() {
    _isDragging = false;
    _dragStartIndex = -1;
    _lastFingerPosition = null;
    _stopAutoScroll();
  }

  void _updateSelectionForRange(int hoverIndex) {
    final start = _dragStartIndex < hoverIndex ? _dragStartIndex : hoverIndex;
    final end = _dragStartIndex < hoverIndex ? hoverIndex : _dragStartIndex;

    final newIds = <String>{};
    for (int i = start; i <= end; i++) {
      newIds.add(widget.assets[i].id);
    }
    widget.onSetSelection?.call(newIds);
  }

  void _checkAutoScroll(Offset globalPosition, BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localY = renderBox.globalToLocal(globalPosition).dy;
    final screenHeight = renderBox.size.height;

    if (localY < _kAutoScrollEdgeZone && _scrollController.offset > 0) {
      final ratio = 1.0 - (localY / _kAutoScrollEdgeZone);
      _autoScrollSpeed = -ratio * _kAutoScrollMaxSpeed;
      _startAutoScroll();
    } else if (localY > screenHeight - _kAutoScrollEdgeZone &&
        _scrollController.offset < _scrollController.position.maxScrollExtent) {
      final ratio = 1.0 - ((screenHeight - localY) / _kAutoScrollEdgeZone);
      _autoScrollSpeed = ratio * _kAutoScrollMaxSpeed;
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (_autoScrollTicker != null && _autoScrollTicker!.isActive) return;
    _autoScrollTicker = Ticker((elapsed) {
      if (!_isDragging || _lastFingerPosition == null) {
        _stopAutoScroll();
        return;
      }
      if (!_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final newOffset = (_scrollController.offset + _autoScrollSpeed)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);

      if (_lastFingerPosition != null && mounted) {
        final context = this.context;
        final index = _getGlobalIndexAtPosition(_lastFingerPosition!, context);
        if (index >= 0 && index < widget.assets.length) {
          _updateSelectionForRange(index);
        }
      }
    });
    _autoScrollTicker!.start();
  }

  void _stopAutoScroll() {
    _autoScrollTicker?.stop();
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
    _autoScrollSpeed = 0;
  }

  void _toggleMonthCollapse(String monthKey) {
    final newCollapsed = Set<String>.from(widget.collapsedMonths);
    if (newCollapsed.contains(monthKey)) {
      newCollapsed.remove(monthKey);
    } else {
      newCollapsed.add(monthKey);
    }
    _cachedItems = null;
    _lastAssets = null;
    widget.onCollapsedMonthsChanged?.call(newCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'No photos found',
      );
    }

    final items = _buildFlatList(widget.assets);

    return GestureDetector(
      onLongPressStart: (details) => _onDragStart(details.globalPosition, context),
      onLongPressMoveUpdate: (details) => _onDragUpdate(details.globalPosition, context),
      onLongPressEnd: (_) => _onDragEnd(),
      child: ListView.builder(
        key: const PageStorageKey<String>('gallery_list'),
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is _HeaderItem) {
            return GestureDetector(
              onTap: () => _toggleMonthCollapse(item.monthKey),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                child: Row(
                  children: [
                    Text(
                      item.month,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: SizedBox(
                        height: 20,
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: double.infinity,
                            height: 0.5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: item.collapsed ? -0.25 : 0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (item is _CollapsedMonthItem) {
            return const SizedBox.shrink();
          }

          final row = item as _RowItem;
          const spacing = 2.0;
          return Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
            child: Row(
              spacing: spacing,
              children: [
                for (int i = 0; i < widget.columns; i++)
                  Expanded(
                    child: i < row.assets.length
                        ? GalleryThumbnail(
                            asset: row.assets[i],
                            thumbnailSize: ThumbnailSize(
                              widget.prefetcher?.cellPixelSize ?? 200,
                              widget.prefetcher?.cellPixelSize ?? 200,
                            ),
                            prefetcher: widget.prefetcher,
                            isSelected: widget.selectedAssetIds
                                .contains(row.assets[i].id),
                            isFavorite: widget.favoriteIds
                                .contains(row.assets[i].id),
                            showSelection: widget.isSelectionMode,
                            enableHero: false,
                            onTap: () {
                              if (widget.isSelectionMode) {
                                widget.onToggleSelection
                                    ?.call(row.assets[i].id);
                              } else {
                                final flatIndex =
                                    widget.assets.indexOf(row.assets[i]);
                                AppNavigator.goToViewer(
                                  context,
                                  assetId: row.assets[i].id,
                                  title: row.assets[i].title ?? 'Photo',
                                  assetIds:
                                      widget.assets.map((a) => a.id).toList(),
                                  initialIndex:
                                      flatIndex >= 0 ? flatIndex : 0,
                                );
                              }
                            },
                          )
                        : const SizedBox(height: 1),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _emitSections(List<_ListItem> items) {
    if (widget.onSectionsBuilt == null) return;
    final sections = <MonthSection>[];
    double yOffset = 0;
    for (final item in items) {
      if (item is _HeaderItem) {
        sections.add(MonthSection(offset: yOffset, label: item.month));
      }
      yOffset += item.height;
    }
    widget.onSectionsBuilt!(sections);
  }

  List<_ListItem> _buildFlatList(List<AssetEntity> assets) {
    if (_cachedItems != null && identical(_lastAssets, assets)) {
      return _cachedItems!;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const spacing = 2.0;
    final cellWidth =
        (screenWidth - spacing * (widget.columns + 1)) / widget.columns;
    final rowHeight = cellWidth + 2;

    final grouped = <DateTime, List<AssetEntity>>{};

    for (final asset in assets) {
      final date = asset.createDateTime;
      final monthKey = DateTime(date.year, date.month);
      grouped.putIfAbsent(monthKey, () => []).add(asset);
    }

    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final items = <_ListItem>[];

    for (final month in sortedMonths) {
      final monthAssets = grouped[month]!;
      final monthKeyStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final isCollapsed = widget.collapsedMonths.contains(monthKeyStr);

      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      items.add(_HeaderItem(
        month: '${monthNames[month.month - 1]} ${month.year}',
        monthKey: monthKeyStr,
        collapsed: isCollapsed,
      ));

      if (isCollapsed) {
        items.add(_CollapsedMonthItem(monthKey: monthKeyStr));
        continue;
      }

      monthAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

      for (int i = 0; i < monthAssets.length; i += widget.columns) {
        final rowAssets = monthAssets.sublist(
          i,
          i + widget.columns > monthAssets.length
              ? monthAssets.length
              : i + widget.columns,
        );
        items.add(_RowItem(rowAssets, rowHeight: rowHeight));
      }
    }

    _cachedItems = items;
    _lastAssets = assets;
    return _cachedItems!;
  }
}

sealed class _ListItem {
  double get height;
}

class _HeaderItem extends _ListItem {
  final String month;
  final String monthKey;
  final bool collapsed;
  @override
  double get height => _kHeaderHeight;
  _HeaderItem(
      {required this.month, required this.monthKey, this.collapsed = false});
}

class _CollapsedMonthItem extends _ListItem {
  final String monthKey;
  @override
  double get height => 0;
  _CollapsedMonthItem({required this.monthKey});
}

class _RowItem extends _ListItem {
  final List<AssetEntity> assets;
  final double rowHeight;
  @override
  double get height => rowHeight;
  _RowItem(this.assets, {this.rowHeight = 0});
}
