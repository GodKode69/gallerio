import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../database/database.dart';

class TrashService {
  final GallerioDatabase _db = GallerioDatabase();

  static const Duration _retentionPeriod = Duration(days: 30);

  Future<Directory> _getTrashDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final trashDir = Directory(p.join(appDir.path, 'trash'));
    if (!await trashDir.exists()) {
      await trashDir.create(recursive: true);
    }
    return trashDir;
  }

  Future<void> moveToTrash(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null || !await file.exists()) return;

      final trashDir = await _getTrashDir();
      final trashPath = p.join(trashDir.path, '${asset.id}_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');

      await file.copy(trashPath);

      await _db.insertTrashItem(TrashItemsCompanion.insert(
        assetId: asset.id,
        name: asset.title ?? 'Photo',
        trashPath: trashPath,
        mimeType: drift.Value(asset.type == AssetType.video ? 'video' : 'image'),
        size: drift.Value(asset.width * asset.height),
      ));
    } catch (_) {}
  }

  Future<bool> deleteWithTrash(AssetEntity asset) async {
    await moveToTrash(asset);
    try {
      await PhotoManager.editor.deleteWithIds([asset.id]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteMultipleWithTrash(List<AssetEntity> assets) async {
    for (final asset in assets) {
      await moveToTrash(asset);
    }
    final ids = assets.map((a) => a.id).toList();
    try {
      await PhotoManager.editor.deleteWithIds(ids);
    } catch (_) {}
  }

  Future<bool> restoreFromTrash(TrashItem item) async {
    try {
      final file = File(item.trashPath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      await PhotoManager.editor.saveImage(
        bytes,
        filename: p.basename(item.trashPath),
        title: item.name,
      );

      await file.delete();
      await _db.deleteTrashItem(item.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> permanentDelete(TrashItem item) async {
    final file = File(item.trashPath);
    if (await file.exists()) {
      await file.delete();
    }
    await _db.deleteTrashItem(item.id);
  }

  Future<List<TrashItem>> getTrashItems() async {
    return _db.getAllTrashItems();
  }

  Future<void> purgeExpired() async {
    final cutoff = DateTime.now().subtract(_retentionPeriod);
    await _db.purgeExpiredTrash(cutoff);
  }

  Future<void> emptyTrash() async {
    final items = await _db.getAllTrashItems();
    for (final item in items) {
      final file = File(item.trashPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteAllTrashItems();
  }
}
