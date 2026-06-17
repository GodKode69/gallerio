import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class ThumbnailPrefetcher extends ChangeNotifier {
  int cellPixelSize;

  List<AssetEntity> _assets = [];
  final Map<String, Uint8List> _cache = {};
  final Set<String> _fetching = {};
  final List<_PrefetchTask> _queue = [];
  Set<String> _visibleIds = {};
  Timer? _notifyTimer;
  static const int _concurrency = 4;

  ThumbnailPrefetcher({required this.cellPixelSize});

  void updateAssets(List<AssetEntity> assets) {
    if (identical(_assets, assets)) return;
    _assets = assets;
    _cache.clear();
    _fetching.clear();
    _queue.clear();
    _visibleIds = {};
    notifyListeners();
    _prefetch();
  }

  void updateVisibleIds(Set<String> visibleIds) {
    if (_setEquals(_visibleIds, visibleIds)) return;
    _visibleIds = visibleIds;
    _prefetch();
  }

  Uint8List? getCachedThumbnail(String assetId) => _cache[assetId];

  void _prefetch() {
    if (_assets.isEmpty) return;

    final candidates = <_PrefetchTask>[];
    for (int i = 0; i < _assets.length; i++) {
      final asset = _assets[i];
      if (_cache.containsKey(asset.id) || _fetching.contains(asset.id)) {
        continue;
      }
      final priority = _visibleIds.contains(asset.id) ? 0 : 1;
      candidates.add(_PrefetchTask(
        asset: asset,
        priority: priority,
        index: i,
      ));
    }

    candidates.sort((a, b) {
      if (a.priority != b.priority) return a.priority - b.priority;
      return a.index - b.index;
    });

    _queue
      ..clear()
      ..addAll(candidates);

    _processQueue();
  }

  void _processQueue() {
    while (_fetching.length < _concurrency && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      if (_cache.containsKey(task.asset.id)) continue;
      _fetchOne(task.asset);
    }
  }

  Future<void> _fetchOne(AssetEntity asset) async {
    _fetching.add(asset.id);
    try {
      final size = ThumbnailSize(cellPixelSize, cellPixelSize);
      final bytes = await asset.thumbnailDataWithSize(size);
      if (bytes != null && !_cache.containsKey(asset.id)) {
        _cache[asset.id] = bytes;
        _scheduleNotify();
      }
    } catch (_) {}
    _fetching.remove(asset.id);
    _processQueue();
  }

  void _scheduleNotify() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 16), () {
      if (hasListeners) notifyListeners();
    });
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every((e) => b.contains(e));
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _queue.clear();
    _fetching.clear();
    super.dispose();
  }
}

class _PrefetchTask {
  final AssetEntity asset;
  final int priority;
  final int index;
  const _PrefetchTask({
    required this.asset,
    required this.priority,
    required this.index,
  });
}
