import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart';
import '../../../shared/utils/vault_utils.dart';

class VaultState {
  final List<VaultItem> items;
  final List<VaultItem> filteredItems;
  final List<String> albums;
  final String? currentAlbum;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const VaultState({
    this.items = const [],
    this.filteredItems = const [],
    this.albums = const [],
    this.currentAlbum,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  VaultState copyWith({
    List<VaultItem>? items,
    List<VaultItem>? filteredItems,
    List<String>? albums,
    String? currentAlbum,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return VaultState(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      albums: albums ?? this.albums,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class VaultNotifier extends StateNotifier<VaultState> {
  final GallerioDatabase _db;
  bool _disposed = false;

  VaultNotifier(this._db) : super(const VaultState()) {
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _init() async {
    try {
      state = state.copyWith(isLoading: true);
      await _loadItems();
      if (_disposed) return;
      await _loadAlbums();
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(isLoading: false, error: 'Failed to load vault');
      }
    }
  }

  Future<void> _loadItems() async {
    final items = await _db.getAllVaultItems();
    state = state.copyWith(
      items: items,
      filteredItems: items,
      isLoading: false,
    );
  }

  Future<void> _loadAlbums() async {
    final albums = await _db.getAllAlbums();
    state = state.copyWith(albums: albums);
  }

  Future<void> _loadItemsAndAlbums() async {
    final items = await _db.getAllVaultItems();
    final albums = await _db.getAllAlbums();
    state = state.copyWith(
      items: items,
      filteredItems: items,
      albums: albums,
      isLoading: false,
    );
  }

  Future<void> importFiles({
    required List<String> filePaths,
    required Map<String, dynamic> assetInfo,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(appDir.path, 'vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final thumbDir = Directory(p.join(vaultDir.path, 'thumbs'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      for (final filePath in filePaths) {
        final vaultName = generateVaultName();
        final ext = p.extension(filePath);
        final vaultPath = p.join(vaultDir.path, '$vaultName$ext');

        final sourceFile = File(filePath);
        if (!await sourceFile.exists()) continue;

        await sourceFile.copy(vaultPath);

        final name = assetInfo['name'] ?? p.basename(filePath);
        final mimeType = assetInfo['mimeType'] ?? '';
        final size = assetInfo['size'] ?? 0;
        final album = assetInfo['album'] ?? 'Imported';

        String? thumbnailPath;
        try {
          final thumbPath = p.join(thumbDir.path, '$vaultName$ext');
          await sourceFile.copy(thumbPath);
          thumbnailPath = thumbPath;
        } catch (_) {}

        await _db.insertVaultItem(VaultItemsCompanion.insert(
          name: name,
          encryptedPath: vaultPath,
          originalName: Value(name),
          mimeType: Value(mimeType),
          size: Value(size),
          album: Value(album),
          iv: '',
          thumbnailPath: Value(thumbnailPath),
        ));
      }

      await _loadItemsAndAlbums();
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to import files: $e',
        isLoading: false,
      );
    }
  }

  Future<void> deleteItem(int id) async {
    final item = await _db.getVaultItemById(id);
    if (item != null) {
      final file = File(item.encryptedPath);
      if (await file.exists()) {
        await file.delete();
      }
      if (item.thumbnailPath != null) {
        final thumbFile = File(item.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }
    }
    await _db.deleteVaultItem(id);
    await _loadItemsAndAlbums();
  }

  Future<void> toggleFavorite(int id) async {
    final item = await _db.getVaultItemById(id);
    if (item != null) {
      await _db.updateVaultItem(VaultItemsCompanion(
        id: Value(id),
        isFavorite: Value(!item.isFavorite),
      ));
      final updatedItems = state.items.map((i) {
        if (i.id == id) {
          return VaultItem(
            id: i.id,
            name: i.name,
            encryptedPath: i.encryptedPath,
            originalName: i.originalName,
            mimeType: i.mimeType,
            size: i.size,
            dateAdded: i.dateAdded,
            dateModified: i.dateModified,
            album: i.album,
            isFavorite: !i.isFavorite,
            thumbnailPath: i.thumbnailPath,
            iv: i.iv,
          );
        }
        return i;
      }).toList();
      state = state.copyWith(
        items: updatedItems,
        filteredItems: updatedItems,
      );
    }
  }

  Future<void> selectAlbum(String? album) async {
    state = state.copyWith(currentAlbum: album);
    if (album == null) {
      state = state.copyWith(filteredItems: state.items);
    } else {
      final items = state.items.where((i) => i.album == album).toList();
      state = state.copyWith(filteredItems: items);
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.isEmpty) {
      state = state.copyWith(filteredItems: state.items);
    } else {
      final items = await _db.searchVaultItems(query);
      state = state.copyWith(filteredItems: items);
    }
  }

  Future<File?> getFileForViewing(VaultItem item) async {
    try {
      final file = File(item.encryptedPath);
      if (!await file.exists()) return null;
      return file;
    } catch (e) {
      return null;
    }
  }
}

final vaultDatabaseProvider = Provider<GallerioDatabase>((ref) {
  return GallerioDatabase();
});

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final db = ref.watch(vaultDatabaseProvider);
  return VaultNotifier(db);
});
