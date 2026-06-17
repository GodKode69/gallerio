import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class VaultItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get encryptedPath => text()();
  TextColumn get originalName => text().nullable()();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dateModified => dateTime().withDefault(currentDateAndTime)();
  TextColumn get album => text().withDefault(const Constant(''))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get iv => text()();
}

class TrashItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get assetId => text()();
  TextColumn get name => text()();
  TextColumn get trashPath => text()();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [VaultItems, TrashItems])
class GallerioDatabase extends _$GallerioDatabase {
  static GallerioDatabase? _instance;

  factory GallerioDatabase() => _instance ??= GallerioDatabase._();

  GallerioDatabase._() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(trashItems);
          }
        },
      );

  // --- Vault Items ---

  Future<int> insertVaultItem(VaultItemsCompanion item) =>
      into(vaultItems).insert(item);

  Future<bool> updateVaultItem(VaultItemsCompanion item) =>
      update(vaultItems).replace(item);

  Future<int> deleteVaultItem(int id) =>
      (delete(vaultItems)..where((t) => t.id.equals(id))).go();

  Future<VaultItem?> getVaultItemById(int id) =>
      (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<VaultItem>> getAllVaultItems() => select(vaultItems).get();

  Future<List<VaultItem>> searchVaultItems(String query) async {
    final queryLower = query.toLowerCase();
    final allItems = await select(vaultItems).get();
    return allItems
        .where((item) => item.name.toLowerCase().contains(queryLower))
        .toList();
  }

  Future<List<String>> getAllAlbums() async {
    final query = selectOnly(vaultItems)
      ..addColumns([vaultItems.album])
      ..groupBy([vaultItems.album]);
    final results = await query.get();
    return results
        .map((row) => row.read(vaultItems.album) ?? '')
        .where((a) => a.isNotEmpty)
        .toList();
  }

  // --- Trash Items ---

  Future<int> insertTrashItem(TrashItemsCompanion item) =>
      into(trashItems).insert(item);

  Future<List<TrashItem>> getAllTrashItems() => select(trashItems).get();

  Future<TrashItem?> getTrashItemById(int id) =>
      (select(trashItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> deleteTrashItem(int id) =>
      (delete(trashItems)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllTrashItems() => delete(trashItems).go();

  Future<int> purgeExpiredTrash(DateTime cutoff) async {
    final expired = await (select(trashItems)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    for (final item in expired) {
      final file = File(item.trashPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    return (delete(trashItems)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gallerio.db'));
    return NativeDatabase(file);
  });
}
