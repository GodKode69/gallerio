import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/trash/trash_service.dart';

enum SortField { date, name, size }

enum SortOrder { newest, oldest, nameAsc, nameDesc, largest, smallest }

class GalleryState {
  final List<AssetPathEntity> albums;
  final List<AssetEntity> assets;
  final List<AssetEntity> recentAssets;
  final List<AssetEntity> recentlyViewed;
  final AssetPathEntity? currentAlbum;
  final bool isLoading;
  final bool hasPermission;
  final String? error;
  final int gridColumns;

  final Set<String> selectedAssetIds;
  final bool isSelectionMode;

  final Set<String> favoriteIds;
  final bool showFavoritesOnly;

  final SortOrder sortOrder;

  final Map<String, String> albumDisplayNames;
  final Map<String, List<AssetPathEntity>> mergedAlbumSources;
  final List<AssetPathEntity> allDeviceAlbums;

  const GalleryState({
    this.albums = const [],
    this.assets = const [],
    this.recentAssets = const [],
    this.recentlyViewed = const [],
    this.currentAlbum,
    this.isLoading = false,
    this.hasPermission = false,
    this.error,
    this.gridColumns = 4,
    this.selectedAssetIds = const {},
    this.isSelectionMode = false,
    this.favoriteIds = const {},
    this.showFavoritesOnly = false,
    this.sortOrder = SortOrder.newest,
    this.albumDisplayNames = const {},
    this.mergedAlbumSources = const {},
    this.allDeviceAlbums = const [],
  });

  GalleryState copyWith({
    List<AssetPathEntity>? albums,
    List<AssetEntity>? assets,
    List<AssetEntity>? recentAssets,
    List<AssetEntity>? recentlyViewed,
    AssetPathEntity? currentAlbum,
    bool? isLoading,
    bool? hasPermission,
    String? error,
    int? gridColumns,
    Set<String>? selectedAssetIds,
    bool? isSelectionMode,
    Set<String>? favoriteIds,
    bool? showFavoritesOnly,
    SortOrder? sortOrder,
    Map<String, String>? albumDisplayNames,
    Map<String, List<AssetPathEntity>>? mergedAlbumSources,
    List<AssetPathEntity>? allDeviceAlbums,
  }) {
    return GalleryState(
      albums: albums ?? this.albums,
      assets: assets ?? this.assets,
      recentAssets: recentAssets ?? this.recentAssets,
      recentlyViewed: recentlyViewed ?? this.recentlyViewed,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
      gridColumns: gridColumns ?? this.gridColumns,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      sortOrder: sortOrder ?? this.sortOrder,
      albumDisplayNames: albumDisplayNames ?? this.albumDisplayNames,
      mergedAlbumSources: mergedAlbumSources ?? this.mergedAlbumSources,
      allDeviceAlbums: allDeviceAlbums ?? this.allDeviceAlbums,
    );
  }

  List<AssetEntity> get displayAssets {
    var list = showFavoritesOnly
        ? assets.where((a) => favoriteIds.contains(a.id)).toList()
        : assets;
    return list;
  }

  int get selectedCount => selectedAssetIds.length;

  bool isSelected(String id) => selectedAssetIds.contains(id);

  String getAlbumDisplayName(AssetPathEntity album) {
    return albumDisplayNames[album.id] ?? album.name;
  }
}

class GalleryNotifier extends StateNotifier<GalleryState> {
  static const int _maxRecentlyViewed = 50;
  Timer? _gridColumnsSaveTimer;

  @override
  void dispose() {
    _gridColumnsSaveTimer?.cancel();
    super.dispose();
  }

  GalleryNotifier() : super(const GalleryState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    await _requestPermission();
    await _requestStoragePermission();

    if (state.hasPermission) {
      await _loadSortOrder();
      await _loadAlbums();
      await _loadRecentAssets();
      await _loadRecentlyViewed();
      await _loadGridColumns();
      await _loadFavorites();

      TrashService().purgeExpired();
    }
  }

  Future<void> _requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    state = state.copyWith(hasPermission: ps.isAuth || ps.hasAccess);
  }

  Future<void> _requestStoragePermission() async {
    try {
      if (await Permission.manageExternalStorage.isGranted) return;
      if (await Permission.manageExternalStorage.isPermanentlyDenied) return;
      await Permission.manageExternalStorage.request();
    } catch (_) {}
  }

  Future<void> _loadAlbums() async {
    try {
      final rawAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      if (rawAlbums.isEmpty) {
        state = state.copyWith(albums: [], isLoading: false);
        return;
      }

      final displayNames = <String, String>{};
      final mergedSources = <String, List<AssetPathEntity>>{};

      final whatsappAlbums = rawAlbums
          .where((a) => a.name.toLowerCase().contains('whatsapp'))
          .toList();
      if (whatsappAlbums.isNotEmpty) {
        displayNames[whatsappAlbums.first.id] = 'WhatsApp';
        if (whatsappAlbums.length > 1) {
          mergedSources[whatsappAlbums.first.id] = whatsappAlbums;
        }
      }

      final albums = rawAlbums.where((a) {
        final name = a.name.toLowerCase();
        if (name.contains('recent')) return false;
        if (whatsappAlbums.contains(a) && a.id != whatsappAlbums.first.id) {
          return false;
        }
        return true;
      }).toList();

      albums.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        if (aName == 'camera') return -1;
        if (bName == 'camera') return 1;
        if (aName.contains('screenshot')) return -1;
        if (bName.contains('screenshot')) return 1;
        return 0;
      });

      state = state.copyWith(
        albums: albums,
        albumDisplayNames: displayNames,
        mergedAlbumSources: mergedSources,
        allDeviceAlbums: rawAlbums,
        currentAlbum: albums.first,
      );
      await _loadAllAssets(rawAlbums);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load albums', isLoading: false);
    }
  }

  Future<void> _loadAllAssets(List<AssetPathEntity> sourceAlbums) async {
    try {
      if (sourceAlbums.isEmpty) {
        state = state.copyWith(assets: [], isLoading: false);
        return;
      }

      final futures = sourceAlbums.map((album) async {
        final count = await album.assetCountAsync;
        if (count == 0) return <AssetEntity>[];
        return (await album.getAssetListRange(start: 0, end: count)).toList();
      });

      final results = await Future.wait(futures);
      final seenIds = <String>{};
      final allAssets = <AssetEntity>[];
      for (final list in results) {
        for (final asset in list) {
          if (seenIds.add(asset.id)) {
            allAssets.add(asset);
          }
        }
      }
      final sortedAssets = _sortAssets(allAssets);

      state = state.copyWith(
        assets: sortedAssets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load photos', isLoading: false);
    }
  }

  Future<List<AssetEntity>> loadMergedAssets(AssetPathEntity album) async {
    final sources = state.mergedAlbumSources[album.id];
    if (sources == null || sources.isEmpty) {
      final count = await album.assetCountAsync;
      if (count == 0) return [];
      return (await album.getAssetListRange(start: 0, end: count)).toList();
    }

    final futures = sources.map((src) async {
      final count = await src.assetCountAsync;
      if (count == 0) return <AssetEntity>[];
      return (await src.getAssetListRange(start: 0, end: count)).toList();
    });

    final results = await Future.wait(futures);
    final allAssets = results.expand((list) => list).toList();
    allAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return allAssets;
  }

  Future<int> getMergedAssetCount(AssetPathEntity album) async {
    final sources = state.mergedAlbumSources[album.id];
    if (sources == null || sources.isEmpty) {
      return album.assetCountAsync;
    }

    final results = await Future.wait(
      sources.map((src) => src.assetCountAsync),
    );
    return results.fold<int>(0, (sum, c) => sum + c);
  }

  Future<List<AssetEntity>> getMergedThumbnails(
    AssetPathEntity album, {
    int limit = 4,
  }) async {
    final sources = state.mergedAlbumSources[album.id];
    if (sources == null || sources.isEmpty) {
      return album.getAssetListPaged(page: 0, size: limit);
    }

    final futures = sources.map((src) async {
      return src.getAssetListPaged(page: 0, size: limit);
    });
    final results = await Future.wait(futures);
    final allAssets = results.expand((list) => list).toList();
    allAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return allAssets.take(limit).toList();
  }

  Future<void> _loadRecentAssets() async {
    try {
      final allAssets = state.assets;
      if (allAssets.isEmpty) return;

      final recent = allAssets.take(20).toList();
      state = state.copyWith(recentAssets: recent);
    } catch (_) {}
  }

  Future<void> _loadAssets(AssetPathEntity album, {bool reset = false}) async {
    try {
      final count = await album.assetCountAsync;
      if (count == 0) {
        state = state.copyWith(
          assets: [],
          currentAlbum: album,
          isLoading: false,
        );
        return;
      }
      final allAssets = await album.getAssetListRange(start: 0, end: count);
      final sortedAssets = _sortAssets(allAssets.toList());

      state = state.copyWith(
        assets: sortedAssets,
        currentAlbum: album,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load photos', isLoading: false);
    }
  }

  List<AssetEntity> _sortAssets(List<AssetEntity> list) {
    switch (state.sortOrder) {
      case SortOrder.newest:
        list.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      case SortOrder.oldest:
        list.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      case SortOrder.nameAsc:
        list.sort((a, b) =>
          (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
      case SortOrder.nameDesc:
        list.sort((a, b) =>
          (b.title ?? '').toLowerCase().compareTo((a.title ?? '').toLowerCase()));
      case SortOrder.largest:
        list.sort((a, b) => b.width * b.height - a.width * a.height);
      case SortOrder.smallest:
        list.sort((a, b) => a.width * a.height - b.width * b.height);
    }
    return list;
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    if (album.id == state.currentAlbum?.id) return;
    state = state.copyWith(isLoading: true);
    await _loadAssets(album, reset: true);
  }

  Future<void> loadMore() async {}

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadAllAssets(state.allDeviceAlbums);
  }

  // --- Search (moved to provider, not build()) ---

  List<AssetEntity> searchAssets(String query, {AssetType? typeFilter}) {
    if (query.isEmpty) {
      return state.showFavoritesOnly
          ? state.assets.where((a) => state.favoriteIds.contains(a.id)).toList()
          : state.assets;
    }

    final lowerQuery = query.toLowerCase();
    return state.assets.where((asset) {
      final matchesQuery =
          asset.title?.toLowerCase().contains(lowerQuery) ?? false;
      final matchesType = typeFilter == null || asset.type == typeFilter;
      final matchesFav =
          !state.showFavoritesOnly || state.favoriteIds.contains(asset.id);
      return matchesQuery && matchesType && matchesFav;
    }).toList();
  }

  // --- Multi-select ---

  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  void exitSelectionMode() {
    state = state.copyWith(isSelectionMode: false, selectedAssetIds: {});
  }

  void toggleSelection(String assetId) {
    final newSelected = Set<String>.from(state.selectedAssetIds);
    if (newSelected.contains(assetId)) {
      newSelected.remove(assetId);
    } else {
      newSelected.add(assetId);
    }
    state = state.copyWith(
      selectedAssetIds: newSelected,
    );
  }

  void setSelection(Set<String> ids) {
    state = state.copyWith(
      selectedAssetIds: ids,
    );
  }

  void selectAll() {
    final allIds = state.displayAssets.map((a) => a.id).toSet();
    state = state.copyWith(selectedAssetIds: allIds);
  }

  void deselectAll() {
    state = state.copyWith(selectedAssetIds: {});
  }

  List<AssetEntity> get selectedAssets {
    return state.assets
        .where((a) => state.selectedAssetIds.contains(a.id))
        .toList();
  }

  // --- Favorites ---

  Future<void> toggleFavorite(String assetId) async {
    final newFavs = Set<String>.from(state.favoriteIds);
    if (newFavs.contains(assetId)) {
      newFavs.remove(assetId);
    } else {
      newFavs.add(assetId);
    }
    state = state.copyWith(favoriteIds: newFavs);
    await _saveFavorites();
  }

  void setShowFavoritesOnly(bool value) {
    state = state.copyWith(showFavoritesOnly: value);
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await LocalPrefs().getStringList('favorite_ids');
      state = state.copyWith(favoriteIds: favs.toSet());
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      await LocalPrefs().setStringList(
          'favorite_ids', state.favoriteIds.toList());
    } catch (_) {}
  }

  // --- Sort ---

  Future<void> setSortOrder(SortOrder order) async {
    if (order == state.sortOrder) return;
    state = state.copyWith(sortOrder: order, isLoading: true);
    await _loadAssets(state.currentAlbum!, reset: true);
    await _saveSortOrder();
  }

  Future<void> _loadSortOrder() async {
    try {
      final index = await LocalPrefs().getInt('sort_order') ?? 0;
      state = state.copyWith(
          sortOrder: SortOrder.values[index.clamp(0, SortOrder.values.length - 1)]);
    } catch (_) {}
  }

  Future<void> _saveSortOrder() async {
    try {
      await LocalPrefs().setInt('sort_order', state.sortOrder.index);
    } catch (_) {}
  }

  // --- Recently viewed ---

  Future<void> addToRecentlyViewed(AssetEntity asset) async {
    final currentList = List<AssetEntity>.from(state.recentlyViewed);
    currentList.removeWhere((a) => a.id == asset.id);
    currentList.insert(0, asset);
    if (currentList.length > _maxRecentlyViewed) {
      currentList.removeRange(_maxRecentlyViewed, currentList.length);
    }
    state = state.copyWith(recentlyViewed: currentList);
    await _saveRecentlyViewed();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final ids = await LocalPrefs().getStringList('recently_viewed_ids');
      final results = await Future.wait(
        ids.map((id) => AssetEntity.fromId(id)),
      );
      final assets = results.whereType<AssetEntity>().toList();
      state = state.copyWith(recentlyViewed: assets);
    } catch (_) {}
  }

  Future<void> _saveRecentlyViewed() async {
    try {
      final ids = state.recentlyViewed.map((a) => a.id).toList();
      await LocalPrefs().setStringList('recently_viewed_ids', ids);
    } catch (_) {}
  }

  // --- Grid columns ---

  Future<void> setGridColumns(int columns) async {
    final clamped = columns.clamp(3, 6);
    state = state.copyWith(gridColumns: clamped);
    _gridColumnsSaveTimer?.cancel();
    _gridColumnsSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveGridColumns(clamped);
    });
  }

  Future<void> _loadGridColumns() async {
    try {
      final saved = await LocalPrefs().getInt('grid_columns');
      if (saved == 5) {
        await LocalPrefs().remove('grid_columns');
        state = state.copyWith(gridColumns: 4);
      } else {
        final columns = saved ?? 4;
        state = state.copyWith(gridColumns: columns.clamp(3, 6));
      }
    } catch (_) {}
  }

  Future<void> _saveGridColumns(int columns) async {
    try {
      await LocalPrefs().setInt('grid_columns', columns);
    } catch (_) {}
  }
}

final galleryProvider = StateNotifierProvider<GalleryNotifier, GalleryState>(
  (ref) => GalleryNotifier(),
);

final isPinchingProvider = StateProvider<bool>((ref) => false);

final isAlbumDetailProvider = StateProvider<bool>((ref) => false);
