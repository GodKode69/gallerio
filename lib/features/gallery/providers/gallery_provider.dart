import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final int page;
  final bool hasMore;
  final int gridColumns;

  final Set<String> selectedAssetIds;
  final bool isSelectionMode;

  final Set<String> favoriteIds;
  final bool showFavoritesOnly;

  final SortOrder sortOrder;

  const GalleryState({
    this.albums = const [],
    this.assets = const [],
    this.recentAssets = const [],
    this.recentlyViewed = const [],
    this.currentAlbum,
    this.isLoading = false,
    this.hasPermission = false,
    this.error,
    this.page = 0,
    this.hasMore = true,
    this.gridColumns = 4,
    this.selectedAssetIds = const {},
    this.isSelectionMode = false,
    this.favoriteIds = const {},
    this.showFavoritesOnly = false,
    this.sortOrder = SortOrder.newest,
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
    int? page,
    bool? hasMore,
    int? gridColumns,
    Set<String>? selectedAssetIds,
    bool? isSelectionMode,
    Set<String>? favoriteIds,
    bool? showFavoritesOnly,
    SortOrder? sortOrder,
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
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      gridColumns: gridColumns ?? this.gridColumns,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      sortOrder: sortOrder ?? this.sortOrder,
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
}

class GalleryNotifier extends StateNotifier<GalleryState> {
  static const int _pageSize = 80;
  static const int _maxRecentlyViewed = 50;

  GalleryNotifier() : super(const GalleryState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    await _requestPermission();
    await _requestStoragePermission();

    if (state.hasPermission) {
      await _loadAlbums();
      await _loadRecentAssets();
      await _loadRecentlyViewed();
      await _loadGridColumns();
      await _loadFavorites();
      await _loadSortOrder();

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
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      if (albums.isEmpty) {
        state = state.copyWith(albums: [], isLoading: false);
        return;
      }

      state = state.copyWith(albums: albums, currentAlbum: albums.first);
      await _loadAssets(albums.first, reset: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load albums', isLoading: false);
    }
  }

  Future<void> _loadRecentAssets() async {
    try {
      final albums = state.albums;
      if (albums.isEmpty) return;

      final allAssets = await albums.first.getAssetListPaged(
        page: 0,
        size: 20,
      );

      state = state.copyWith(recentAssets: _sortAssets(allAssets.toList()));
    } catch (_) {}
  }

  Future<void> _loadAssets(AssetPathEntity album, {bool reset = false}) async {
    try {
      final page = reset ? 0 : state.page + 1;
      final assets = await album.getAssetListPaged(page: page, size: _pageSize);
      final mergedAssets = reset ? assets : [...state.assets, ...assets];
      final sortedAssets = _sortAssets(mergedAssets.toList());

      state = state.copyWith(
        assets: sortedAssets,
        currentAlbum: album,
        page: page,
        hasMore: assets.length == _pageSize,
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

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    await _loadAssets(state.currentAlbum!, reset: false);
  }

  Future<void> refresh() async {
    if (state.currentAlbum == null) return;
    state = state.copyWith(isLoading: true);
    await _loadAssets(state.currentAlbum!, reset: true);
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
      isSelectionMode: newSelected.isNotEmpty,
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
      final prefs = await SharedPreferences.getInstance();
      final favs = prefs.getStringList('favorite_ids') ?? [];
      state = state.copyWith(favoriteIds: favs.toSet());
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
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
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt('sort_order') ?? 0;
      state = state.copyWith(
          sortOrder: SortOrder.values[index.clamp(0, SortOrder.values.length - 1)]);
    } catch (_) {}
  }

  Future<void> _saveSortOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sort_order', state.sortOrder.index);
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
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('recently_viewed_ids') ?? [];
      final results = await Future.wait(
        ids.map((id) => AssetEntity.fromId(id)),
      );
      final assets = results.whereType<AssetEntity>().toList();
      state = state.copyWith(recentlyViewed: assets);
    } catch (_) {}
  }

  Future<void> _saveRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = state.recentlyViewed.map((a) => a.id).toList();
      await prefs.setStringList('recently_viewed_ids', ids);
    } catch (_) {}
  }

  // --- Grid columns ---

  Future<void> setGridColumns(int columns) async {
    final clamped = columns.clamp(3, 6);
    state = state.copyWith(gridColumns: clamped);
    await _saveGridColumns(clamped);
  }

  Future<void> _loadGridColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('grid_columns');
      if (saved == 5) {
        await prefs.remove('grid_columns');
        state = state.copyWith(gridColumns: 4);
      } else {
        final columns = saved ?? 4;
        state = state.copyWith(gridColumns: columns.clamp(3, 6));
      }
    } catch (_) {}
  }

  Future<void> _saveGridColumns(int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('grid_columns', columns);
    } catch (_) {}
  }
}

final galleryProvider = StateNotifierProvider<GalleryNotifier, GalleryState>(
  (ref) => GalleryNotifier(),
);

final isPinchingProvider = StateProvider<bool>((ref) => false);

final isAlbumDetailProvider = StateProvider<bool>((ref) => false);
