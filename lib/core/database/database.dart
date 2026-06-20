import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

export 'models.dart';

class GallerioDatabase {
  static GallerioDatabase? _instance;
  Database? _db;

  factory GallerioDatabase() => _instance ??= GallerioDatabase._();
  GallerioDatabase._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'gallerio.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            encrypted_path TEXT NOT NULL,
            original_name TEXT,
            mime_type TEXT DEFAULT '',
            size INTEGER DEFAULT 0,
            date_added INTEGER NOT NULL,
            date_modified INTEGER NOT NULL,
            album TEXT DEFAULT '',
            is_favorite INTEGER DEFAULT 0,
            thumbnail_path TEXT,
            iv TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE trash_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_id TEXT NOT NULL,
            name TEXT NOT NULL,
            trash_path TEXT NOT NULL,
            mime_type TEXT DEFAULT '',
            size INTEGER DEFAULT 0,
            deleted_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE trash_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              asset_id TEXT NOT NULL,
              name TEXT NOT NULL,
              trash_path TEXT NOT NULL,
              mime_type TEXT DEFAULT '',
              size INTEGER DEFAULT 0,
              deleted_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
    return _db!;
  }

  // --- Vault Items ---

  Future<int> insertVaultItem(VaultItem item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    return db.insert('vault_items', map);
  }

  Future<bool> updateVaultItem(VaultItem item) async {
    final db = await database;
    final count = await db.update(
      'vault_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return count > 0;
  }

  Future<int> deleteVaultItem(int id) async {
    final db = await database;
    return db.delete('vault_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<VaultItem?> getVaultItemById(int id) async {
    final db = await database;
    final rows = await db.query('vault_items',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return VaultItem.fromMap(rows.first);
  }

  Future<List<VaultItem>> getAllVaultItems() async {
    final db = await database;
    final rows = await db.query('vault_items', orderBy: 'date_added DESC');
    return rows.map(VaultItem.fromMap).toList();
  }

  Future<List<VaultItem>> searchVaultItems(String query) async {
    final db = await database;
    final rows = await db.query(
      'vault_items',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'date_added DESC',
    );
    return rows.map(VaultItem.fromMap).toList();
  }

  Future<List<String>> getAllAlbums() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT album FROM vault_items WHERE album != "" ORDER BY album');
    return rows.map((r) => r['album'] as String).toList();
  }

  // --- Trash Items ---

  Future<int> insertTrashItem(TrashItem item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    return db.insert('trash_items', map);
  }

  Future<List<TrashItem>> getAllTrashItems() async {
    final db = await database;
    final rows = await db.query('trash_items', orderBy: 'deleted_at DESC');
    return rows.map(TrashItem.fromMap).toList();
  }

  Future<TrashItem?> getTrashItemById(int id) async {
    final db = await database;
    final rows = await db.query('trash_items',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TrashItem.fromMap(rows.first);
  }

  Future<int> deleteTrashItem(int id) async {
    final db = await database;
    return db.delete('trash_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllTrashItems() async {
    final db = await database;
    return db.delete('trash_items');
  }

  Future<int> purgeExpiredTrash(DateTime cutoff) async {
    final db = await database;
    final rows = await db.query('trash_items',
        where: 'deleted_at < ?', whereArgs: [cutoff.millisecondsSinceEpoch]);
    final deleted = await db.delete('trash_items',
        where: 'deleted_at < ?', whereArgs: [cutoff.millisecondsSinceEpoch]);
    for (final row in rows) {
      try {
        final file = File(row['trash_path'] as String);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    return deleted;
  }
}
