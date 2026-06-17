import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import 'gallery_thumbnail.dart';
import 'staggered_animation.dart';

class MonthlyGallery extends StatefulWidget {
  final List<AssetEntity> assets;
  final int columns;
  final Set<String> selectedAssetIds;
  final bool isSelectionMode;
  final Set<String> favoriteIds;
  final ValueChanged<String>? onToggleSelection;
  final VoidCallback? onEnterSelectionMode;
  final ValueChanged<String>? onToggleFavorite;
  final ScrollController? externalScrollController;
  final ValueChanged<Set<String>>? onDragSelectionUpdate;

  const MonthlyGallery({
    super.key,
    required this.assets,
    this.columns = 5,
    this.selectedAssetIds = const {},
    this.isSelectionMode = false,
    this.favoriteIds = const {},
    this.onToggleSelection,
    this.onEnterSelectionMode,
    this.onToggleFavorite,
    this.externalScrollController,
    this.onDragSelectionUpdate,
  });

  @override
  State<MonthlyGallery> createState() => _MonthlyGalleryState();
}

class _MonthlyGalleryState extends State<MonthlyGallery> {
  late ScrollController _scrollController;
  List<_ListItem>? _cachedItems;
  List<AssetEntity>? _lastAssets;
  bool _isDragging = false;
  final Set<String> _dragSelectedIds = {};
  String? _lastDraggedAssetId;
  final Set<String> _collapsedMonths = {};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.externalScrollController ?? ScrollController();
  }

  @override
  void didUpdateWidget(covariant MonthlyGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.assets, widget.assets)) {
      _cachedItems = null;
      _lastAssets = null;
    }
  }

  @override
  void dispose() {
    if (widget.externalScrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  String? _getAssetIdAtPosition(Offset globalPosition, BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = 2.0;
    final cellSize = (screenWidth - spacing * (widget.columns + 1)) / widget.columns;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    final adjustedY = localPosition.dy + scrollOffset;

    final items = _buildFlatList(widget.assets);
    int currentY = 0;

    for (final item in items) {
      if (item is _HeaderItem) {
        currentY += item.collapsed ? 52 : 52;
        continue;
      }

      if (item is _CollapsedMonthItem) {
        currentY += 0;
        continue;
      }

      final row = item as _RowItem;

      if (adjustedY >= currentY && adjustedY < currentY + cellSize) {
        final colIndex = ((localPosition.dx - spacing) / (cellSize + spacing)).floor();
        if (colIndex >= 0 && colIndex < row.assets.length) {
          return row.assets[colIndex].id;
        }
      }

      currentY += (cellSize + spacing).toInt();
    }

    return null;
  }

  void _onDragStart(Offset globalPosition, BuildContext context) {
    final assetId = _getAssetIdAtPosition(globalPosition, context);
    if (assetId != null) {
      _isDragging = true;
      _dragSelectedIds.clear();
      _dragSelectedIds.add(assetId);
      _lastDraggedAssetId = assetId;

      if (!widget.isSelectionMode) {
        widget.onEnterSelectionMode?.call();
      }

      for (final id in _dragSelectedIds) {
        if (!widget.selectedAssetIds.contains(id)) {
          widget.onToggleSelection?.call(id);
        }
      }
    }
  }

  void _onDragUpdate(Offset globalPosition, BuildContext context) {
    if (!_isDragging) return;

    final assetId = _getAssetIdAtPosition(globalPosition, context);
    if (assetId != null && assetId != _lastDraggedAssetId) {
      _lastDraggedAssetId = assetId;

      final newDragIds = <String>{assetId};

      if (_dragSelectedIds.isNotEmpty) {
        final allAssets = widget.assets;
        final lastId = _dragSelectedIds.last;
        final lastIndex = allAssets.indexWhere((a) => a.id == lastId);
        final currentIndex = allAssets.indexWhere((a) => a.id == assetId);

        if (lastIndex >= 0 && currentIndex >= 0) {
          final start = lastIndex < currentIndex ? lastIndex : currentIndex;
          final end = lastIndex < currentIndex ? currentIndex : lastIndex;

          for (int i = start; i <= end; i++) {
            newDragIds.add(allAssets[i].id);
          }
        }
      }

      final toSelect = newDragIds.difference(_dragSelectedIds);
      final toDeselect = _dragSelectedIds.difference(newDragIds);

      _dragSelectedIds
        ..clear()
        ..addAll(newDragIds);

      for (final id in toSelect) {
        if (!widget.selectedAssetIds.contains(id)) {
          widget.onToggleSelection?.call(id);
        }
      }
      for (final id in toDeselect) {
        if (widget.selectedAssetIds.contains(id)) {
          widget.onToggleSelection?.call(id);
        }
      }
    }
  }

  void _onDragEnd() {
    _isDragging = false;
    _dragSelectedIds.clear();
    _lastDraggedAssetId = null;
  }

  void _toggleMonthCollapse(String monthKey) {
    setState(() {
      if (_collapsedMonths.contains(monthKey)) {
        _collapsedMonths.remove(monthKey);
      } else {
        _collapsedMonths.add(monthKey);
      }
      _cachedItems = null;
      _lastAssets = null;
    });
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
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is _HeaderItem) {
            return GestureDetector(
              onTap: () => _toggleMonthCollapse(item.monthKey),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
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
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: item.collapsed ? -0.25 : 0.25,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
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
          final spacing = 2.0;
          return Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
            child: Row(
              spacing: spacing,
              children: [
                for (int i = 0; i < widget.columns; i++)
                  Expanded(
                    child: i < row.assets.length
                        ? StaggeredAnimation(
                            index: index * widget.columns + i,
                            itemCount: items.length * widget.columns,
                            child: GalleryThumbnail(
                              asset: row.assets[i],
                              isSelected:
                                  widget.selectedAssetIds.contains(row.assets[i].id),
                              isFavorite:
                                  widget.favoriteIds.contains(row.assets[i].id),
                              showSelection: widget.isSelectionMode,
                              enableHero: false,
                              onTap: () {
                                if (widget.isSelectionMode) {
                                  widget.onToggleSelection
                                      ?.call(row.assets[i].id);
                                } else {
                                  final flatIndex = widget.assets.indexOf(row.assets[i]);
                                  context.push('/viewer', extra: {
                                    'assetId': row.assets[i].id,
                                    'title': row.assets[i].title ?? 'Photo',
                                    'assetIds': widget.assets.map((a) => a.id).toList(),
                                    'initialIndex': flatIndex >= 0 ? flatIndex : 0,
                                  });
                                }
                              },
                              onLongPress: () {
                                if (!widget.isSelectionMode) {
                                  widget.onEnterSelectionMode?.call();
                                  widget.onToggleSelection
                                      ?.call(row.assets[i].id);
                                }
                              },
                            ),
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

  List<_ListItem> _buildFlatList(List<AssetEntity> assets) {
    if (_cachedItems != null && identical(_lastAssets, assets)) {
      return _cachedItems!;
    }

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
      final monthKeyStr = DateFormat('yyyy-MM').format(month);
      final isCollapsed = _collapsedMonths.contains(monthKeyStr);

      items.add(_HeaderItem(
        month: DateFormat('MMM yyyy').format(month),
        monthKey: monthKeyStr,
        collapsed: isCollapsed,
      ));

      if (isCollapsed) {
        items.add(_CollapsedMonthItem(monthKey: monthKeyStr));
        continue;
      }

      for (int i = 0; i < monthAssets.length; i += widget.columns) {
        final rowAssets = monthAssets.sublist(
          i,
          i + widget.columns > monthAssets.length
              ? monthAssets.length
              : i + widget.columns,
        );
        items.add(_RowItem(rowAssets));
      }
    }

    _cachedItems = items;
    _lastAssets = assets;
    return _cachedItems!;
  }
}

sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final String month;
  final String monthKey;
  final bool collapsed;
  _HeaderItem({required this.month, required this.monthKey, this.collapsed = false});
}

class _CollapsedMonthItem extends _ListItem {
  final String monthKey;
  _CollapsedMonthItem({required this.monthKey});
}

class _RowItem extends _ListItem {
  final List<AssetEntity> assets;
  _RowItem(this.assets);
}
