import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/security/security_service.dart';
import '../../auth/providers/auth_provider.dart';

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
  final EncryptionService _encryption;
  final SecurityService _security;

  VaultNotifier(this._db, this._encryption, this._security)
      : super(const VaultState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = state.copyWith(isLoading: true);
      await _loadItems();
      await _loadAlbums();
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load vault');
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
      var key = await _security.getVaultKey();
      if (key == null) {
        key = await _encryption.generateKey();
        await _security.setVaultKey(key);
      }

      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(appDir.path, 'vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      for (final filePath in filePaths) {
        final encryptedName = _encryption.generateEncryptedName();
        final encryptedPath = p.join(vaultDir.path, '$encryptedName.enc');

        final sourceFile = File(filePath);
        if (!await sourceFile.exists()) continue;

        final outputFile = File(encryptedPath);
        await _encryption.encryptFile(
          inputFile: sourceFile,
          key: key,
          outputFile: outputFile,
        );

        final nonce = await _encryption.getLastNonce();

        final name = assetInfo['name'] ?? p.basename(filePath);
        final mimeType = assetInfo['mimeType'] ?? '';
        final size = assetInfo['size'] ?? 0;
        final album = assetInfo['album'] ?? 'Imported';

        await _db.insertVaultItem(VaultItemsCompanion.insert(
          name: name,
          encryptedPath: encryptedPath,
          originalName: Value(name),
          mimeType: Value(mimeType),
          size: Value(size),
          album: Value(album),
          iv: base64Encode(nonce),
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

  Future<File?> decryptForViewing(VaultItem item) async {
    try {
      final key = await _security.getVaultKey();
      if (key == null) return null;

      final encryptedFile = File(item.encryptedPath);
      if (!await encryptedFile.exists()) return null;

      final tempFile = await _encryption.getTempDecryptFile(item.name);
      await _encryption.decryptFile(
        encryptedFile: encryptedFile,
        key: key,
        outputFile: tempFile,
      );
      return tempFile;
    } catch (e) {
      return null;
    }
  }
}

final vaultDatabaseProvider = Provider<GallerioDatabase>((ref) {
  return GallerioDatabase();
});

final vaultEncryptionProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final db = ref.watch(vaultDatabaseProvider);
  final encryption = ref.watch(vaultEncryptionProvider);
  final security = ref.watch(securityServiceProvider);
  return VaultNotifier(db, encryption, security);
});
