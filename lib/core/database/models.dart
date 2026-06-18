class VaultItem {
  final int id;
  final String name;
  final String encryptedPath;
  final String? originalName;
  final String mimeType;
  final int size;
  final DateTime dateAdded;
  final DateTime dateModified;
  final String album;
  final bool isFavorite;
  final String? thumbnailPath;
  final String iv;

  const VaultItem({
    required this.id,
    required this.name,
    required this.encryptedPath,
    this.originalName,
    this.mimeType = '',
    this.size = 0,
    required this.dateAdded,
    required this.dateModified,
    this.album = '',
    this.isFavorite = false,
    this.thumbnailPath,
    this.iv = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'encrypted_path': encryptedPath,
        'original_name': originalName,
        'mime_type': mimeType,
        'size': size,
        'date_added': dateAdded.millisecondsSinceEpoch,
        'date_modified': dateModified.millisecondsSinceEpoch,
        'album': album,
        'is_favorite': isFavorite ? 1 : 0,
        'thumbnail_path': thumbnailPath,
        'iv': iv,
      };

  factory VaultItem.fromMap(Map<String, dynamic> m) => VaultItem(
        id: m['id'] as int,
        name: m['name'] as String,
        encryptedPath: m['encrypted_path'] as String,
        originalName: m['original_name'] as String?,
        mimeType: m['mime_type'] as String? ?? '',
        size: m['size'] as int? ?? 0,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(m['date_added'] as int),
        dateModified:
            DateTime.fromMillisecondsSinceEpoch(m['date_modified'] as int),
        album: m['album'] as String? ?? '',
        isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
        thumbnailPath: m['thumbnail_path'] as String?,
        iv: m['iv'] as String? ?? '',
      );

  VaultItem copyWith({
    int? id,
    String? name,
    String? encryptedPath,
    String? originalName,
    String? mimeType,
    int? size,
    DateTime? dateAdded,
    DateTime? dateModified,
    String? album,
    bool? isFavorite,
    String? thumbnailPath,
    String? iv,
  }) =>
      VaultItem(
        id: id ?? this.id,
        name: name ?? this.name,
        encryptedPath: encryptedPath ?? this.encryptedPath,
        originalName: originalName ?? this.originalName,
        mimeType: mimeType ?? this.mimeType,
        size: size ?? this.size,
        dateAdded: dateAdded ?? this.dateAdded,
        dateModified: dateModified ?? this.dateModified,
        album: album ?? this.album,
        isFavorite: isFavorite ?? this.isFavorite,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        iv: iv ?? this.iv,
      );
}

class TrashItem {
  final int id;
  final String assetId;
  final String name;
  final String trashPath;
  final String mimeType;
  final int size;
  final DateTime deletedAt;

  const TrashItem({
    required this.id,
    required this.assetId,
    required this.name,
    required this.trashPath,
    this.mimeType = '',
    this.size = 0,
    required this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'asset_id': assetId,
        'name': name,
        'trash_path': trashPath,
        'mime_type': mimeType,
        'size': size,
        'deleted_at': deletedAt.millisecondsSinceEpoch,
      };

  factory TrashItem.fromMap(Map<String, dynamic> m) => TrashItem(
        id: m['id'] as int,
        assetId: m['asset_id'] as String,
        name: m['name'] as String,
        trashPath: m['trash_path'] as String,
        mimeType: m['mime_type'] as String? ?? '',
        size: m['size'] as int? ?? 0,
        deletedAt: DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
      );
}
