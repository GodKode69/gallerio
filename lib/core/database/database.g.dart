// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VaultItemsTable extends VaultItems
    with TableInfo<$VaultItemsTable, VaultItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPathMeta = const VerificationMeta(
    'encryptedPath',
  );
  @override
  late final GeneratedColumn<String> encryptedPath = GeneratedColumn<String>(
    'encrypted_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalNameMeta = const VerificationMeta(
    'originalName',
  );
  @override
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
    'original_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _dateModifiedMeta = const VerificationMeta(
    'dateModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateModified = GeneratedColumn<DateTime>(
    'date_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivMeta = const VerificationMeta('iv');
  @override
  late final GeneratedColumn<String> iv = GeneratedColumn<String>(
    'iv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    encryptedPath,
    originalName,
    mimeType,
    size,
    dateAdded,
    dateModified,
    album,
    isFavorite,
    thumbnailPath,
    iv,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('encrypted_path')) {
      context.handle(
        _encryptedPathMeta,
        encryptedPath.isAcceptableOrUnknown(
          data['encrypted_path']!,
          _encryptedPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPathMeta);
    }
    if (data.containsKey('original_name')) {
      context.handle(
        _originalNameMeta,
        originalName.isAcceptableOrUnknown(
          data['original_name']!,
          _originalNameMeta,
        ),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    }
    if (data.containsKey('date_modified')) {
      context.handle(
        _dateModifiedMeta,
        dateModified.isAcceptableOrUnknown(
          data['date_modified']!,
          _dateModifiedMeta,
        ),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('iv')) {
      context.handle(_ivMeta, iv.isAcceptableOrUnknown(data['iv']!, _ivMeta));
    } else if (isInserting) {
      context.missing(_ivMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      encryptedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_path'],
      )!,
      originalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_name'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
      dateModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_modified'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      iv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iv'],
      )!,
    );
  }

  @override
  $VaultItemsTable createAlias(String alias) {
    return $VaultItemsTable(attachedDatabase, alias);
  }
}

class VaultItem extends DataClass implements Insertable<VaultItem> {
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
    required this.mimeType,
    required this.size,
    required this.dateAdded,
    required this.dateModified,
    required this.album,
    required this.isFavorite,
    this.thumbnailPath,
    required this.iv,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['encrypted_path'] = Variable<String>(encryptedPath);
    if (!nullToAbsent || originalName != null) {
      map['original_name'] = Variable<String>(originalName);
    }
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    map['date_added'] = Variable<DateTime>(dateAdded);
    map['date_modified'] = Variable<DateTime>(dateModified);
    map['album'] = Variable<String>(album);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['iv'] = Variable<String>(iv);
    return map;
  }

  VaultItemsCompanion toCompanion(bool nullToAbsent) {
    return VaultItemsCompanion(
      id: Value(id),
      name: Value(name),
      encryptedPath: Value(encryptedPath),
      originalName: originalName == null && nullToAbsent
          ? const Value.absent()
          : Value(originalName),
      mimeType: Value(mimeType),
      size: Value(size),
      dateAdded: Value(dateAdded),
      dateModified: Value(dateModified),
      album: Value(album),
      isFavorite: Value(isFavorite),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      iv: Value(iv),
    );
  }

  factory VaultItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultItem(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      encryptedPath: serializer.fromJson<String>(json['encryptedPath']),
      originalName: serializer.fromJson<String?>(json['originalName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
      dateModified: serializer.fromJson<DateTime>(json['dateModified']),
      album: serializer.fromJson<String>(json['album']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      iv: serializer.fromJson<String>(json['iv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'encryptedPath': serializer.toJson<String>(encryptedPath),
      'originalName': serializer.toJson<String?>(originalName),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
      'dateModified': serializer.toJson<DateTime>(dateModified),
      'album': serializer.toJson<String>(album),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'iv': serializer.toJson<String>(iv),
    };
  }

  VaultItem copyWith({
    int? id,
    String? name,
    String? encryptedPath,
    Value<String?> originalName = const Value.absent(),
    String? mimeType,
    int? size,
    DateTime? dateAdded,
    DateTime? dateModified,
    String? album,
    bool? isFavorite,
    Value<String?> thumbnailPath = const Value.absent(),
    String? iv,
  }) => VaultItem(
    id: id ?? this.id,
    name: name ?? this.name,
    encryptedPath: encryptedPath ?? this.encryptedPath,
    originalName: originalName.present ? originalName.value : this.originalName,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    dateAdded: dateAdded ?? this.dateAdded,
    dateModified: dateModified ?? this.dateModified,
    album: album ?? this.album,
    isFavorite: isFavorite ?? this.isFavorite,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    iv: iv ?? this.iv,
  );
  VaultItem copyWithCompanion(VaultItemsCompanion data) {
    return VaultItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      encryptedPath: data.encryptedPath.present
          ? data.encryptedPath.value
          : this.encryptedPath,
      originalName: data.originalName.present
          ? data.originalName.value
          : this.originalName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      dateModified: data.dateModified.present
          ? data.dateModified.value
          : this.dateModified,
      album: data.album.present ? data.album.value : this.album,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      iv: data.iv.present ? data.iv.value : this.iv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('encryptedPath: $encryptedPath, ')
          ..write('originalName: $originalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('dateModified: $dateModified, ')
          ..write('album: $album, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('iv: $iv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    encryptedPath,
    originalName,
    mimeType,
    size,
    dateAdded,
    dateModified,
    album,
    isFavorite,
    thumbnailPath,
    iv,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.encryptedPath == this.encryptedPath &&
          other.originalName == this.originalName &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.dateAdded == this.dateAdded &&
          other.dateModified == this.dateModified &&
          other.album == this.album &&
          other.isFavorite == this.isFavorite &&
          other.thumbnailPath == this.thumbnailPath &&
          other.iv == this.iv);
}

class VaultItemsCompanion extends UpdateCompanion<VaultItem> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> encryptedPath;
  final Value<String?> originalName;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<DateTime> dateAdded;
  final Value<DateTime> dateModified;
  final Value<String> album;
  final Value<bool> isFavorite;
  final Value<String?> thumbnailPath;
  final Value<String> iv;
  const VaultItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.encryptedPath = const Value.absent(),
    this.originalName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.album = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.iv = const Value.absent(),
  });
  VaultItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String encryptedPath,
    this.originalName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.album = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    required String iv,
  }) : name = Value(name),
       encryptedPath = Value(encryptedPath),
       iv = Value(iv);
  static Insertable<VaultItem> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? encryptedPath,
    Expression<String>? originalName,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<DateTime>? dateAdded,
    Expression<DateTime>? dateModified,
    Expression<String>? album,
    Expression<bool>? isFavorite,
    Expression<String>? thumbnailPath,
    Expression<String>? iv,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (encryptedPath != null) 'encrypted_path': encryptedPath,
      if (originalName != null) 'original_name': originalName,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (dateAdded != null) 'date_added': dateAdded,
      if (dateModified != null) 'date_modified': dateModified,
      if (album != null) 'album': album,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (iv != null) 'iv': iv,
    });
  }

  VaultItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? encryptedPath,
    Value<String?>? originalName,
    Value<String>? mimeType,
    Value<int>? size,
    Value<DateTime>? dateAdded,
    Value<DateTime>? dateModified,
    Value<String>? album,
    Value<bool>? isFavorite,
    Value<String?>? thumbnailPath,
    Value<String>? iv,
  }) {
    return VaultItemsCompanion(
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

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (encryptedPath.present) {
      map['encrypted_path'] = Variable<String>(encryptedPath.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (dateModified.present) {
      map['date_modified'] = Variable<DateTime>(dateModified.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (iv.present) {
      map['iv'] = Variable<String>(iv.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('encryptedPath: $encryptedPath, ')
          ..write('originalName: $originalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('dateModified: $dateModified, ')
          ..write('album: $album, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('iv: $iv')
          ..write(')'))
        .toString();
  }
}

class $TrashItemsTable extends TrashItems
    with TableInfo<$TrashItemsTable, TrashItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrashItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trashPathMeta = const VerificationMeta(
    'trashPath',
  );
  @override
  late final GeneratedColumn<String> trashPath = GeneratedColumn<String>(
    'trash_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    name,
    trashPath,
    mimeType,
    size,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trash_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrashItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('trash_path')) {
      context.handle(
        _trashPathMeta,
        trashPath.isAcceptableOrUnknown(data['trash_path']!, _trashPathMeta),
      );
    } else if (isInserting) {
      context.missing(_trashPathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrashItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrashItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      trashPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trash_path'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $TrashItemsTable createAlias(String alias) {
    return $TrashItemsTable(attachedDatabase, alias);
  }
}

class TrashItem extends DataClass implements Insertable<TrashItem> {
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
    required this.mimeType,
    required this.size,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['name'] = Variable<String>(name);
    map['trash_path'] = Variable<String>(trashPath);
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  TrashItemsCompanion toCompanion(bool nullToAbsent) {
    return TrashItemsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      name: Value(name),
      trashPath: Value(trashPath),
      mimeType: Value(mimeType),
      size: Value(size),
      deletedAt: Value(deletedAt),
    );
  }

  factory TrashItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrashItem(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      name: serializer.fromJson<String>(json['name']),
      trashPath: serializer.fromJson<String>(json['trashPath']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<String>(assetId),
      'name': serializer.toJson<String>(name),
      'trashPath': serializer.toJson<String>(trashPath),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  TrashItem copyWith({
    int? id,
    String? assetId,
    String? name,
    String? trashPath,
    String? mimeType,
    int? size,
    DateTime? deletedAt,
  }) => TrashItem(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    name: name ?? this.name,
    trashPath: trashPath ?? this.trashPath,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    deletedAt: deletedAt ?? this.deletedAt,
  );
  TrashItem copyWithCompanion(TrashItemsCompanion data) {
    return TrashItem(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      name: data.name.present ? data.name.value : this.name,
      trashPath: data.trashPath.present ? data.trashPath.value : this.trashPath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrashItem(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('name: $name, ')
          ..write('trashPath: $trashPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, assetId, name, trashPath, mimeType, size, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrashItem &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.name == this.name &&
          other.trashPath == this.trashPath &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.deletedAt == this.deletedAt);
}

class TrashItemsCompanion extends UpdateCompanion<TrashItem> {
  final Value<int> id;
  final Value<String> assetId;
  final Value<String> name;
  final Value<String> trashPath;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<DateTime> deletedAt;
  const TrashItemsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.name = const Value.absent(),
    this.trashPath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TrashItemsCompanion.insert({
    this.id = const Value.absent(),
    required String assetId,
    required String name,
    required String trashPath,
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : assetId = Value(assetId),
       name = Value(name),
       trashPath = Value(trashPath);
  static Insertable<TrashItem> custom({
    Expression<int>? id,
    Expression<String>? assetId,
    Expression<String>? name,
    Expression<String>? trashPath,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (name != null) 'name': name,
      if (trashPath != null) 'trash_path': trashPath,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TrashItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? assetId,
    Value<String>? name,
    Value<String>? trashPath,
    Value<String>? mimeType,
    Value<int>? size,
    Value<DateTime>? deletedAt,
  }) {
    return TrashItemsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      name: name ?? this.name,
      trashPath: trashPath ?? this.trashPath,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (trashPath.present) {
      map['trash_path'] = Variable<String>(trashPath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrashItemsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('name: $name, ')
          ..write('trashPath: $trashPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$GallerioDatabase extends GeneratedDatabase {
  _$GallerioDatabase(QueryExecutor e) : super(e);
  $GallerioDatabaseManager get managers => $GallerioDatabaseManager(this);
  late final $VaultItemsTable vaultItems = $VaultItemsTable(this);
  late final $TrashItemsTable trashItems = $TrashItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [vaultItems, trashItems];
}

typedef $$VaultItemsTableCreateCompanionBuilder =
    VaultItemsCompanion Function({
      Value<int> id,
      required String name,
      required String encryptedPath,
      Value<String?> originalName,
      Value<String> mimeType,
      Value<int> size,
      Value<DateTime> dateAdded,
      Value<DateTime> dateModified,
      Value<String> album,
      Value<bool> isFavorite,
      Value<String?> thumbnailPath,
      required String iv,
    });
typedef $$VaultItemsTableUpdateCompanionBuilder =
    VaultItemsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> encryptedPath,
      Value<String?> originalName,
      Value<String> mimeType,
      Value<int> size,
      Value<DateTime> dateAdded,
      Value<DateTime> dateModified,
      Value<String> album,
      Value<bool> isFavorite,
      Value<String?> thumbnailPath,
      Value<String> iv,
    });

class $$VaultItemsTableFilterComposer
    extends Composer<_$GallerioDatabase, $VaultItemsTable> {
  $$VaultItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPath => $composableBuilder(
    column: $table.encryptedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultItemsTableOrderingComposer
    extends Composer<_$GallerioDatabase, $VaultItemsTable> {
  $$VaultItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPath => $composableBuilder(
    column: $table.encryptedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultItemsTableAnnotationComposer
    extends Composer<_$GallerioDatabase, $VaultItemsTable> {
  $$VaultItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get encryptedPath => $composableBuilder(
    column: $table.encryptedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  GeneratedColumn<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iv =>
      $composableBuilder(column: $table.iv, builder: (column) => column);
}

class $$VaultItemsTableTableManager
    extends
        RootTableManager<
          _$GallerioDatabase,
          $VaultItemsTable,
          VaultItem,
          $$VaultItemsTableFilterComposer,
          $$VaultItemsTableOrderingComposer,
          $$VaultItemsTableAnnotationComposer,
          $$VaultItemsTableCreateCompanionBuilder,
          $$VaultItemsTableUpdateCompanionBuilder,
          (
            VaultItem,
            BaseReferences<_$GallerioDatabase, $VaultItemsTable, VaultItem>,
          ),
          VaultItem,
          PrefetchHooks Function()
        > {
  $$VaultItemsTableTableManager(_$GallerioDatabase db, $VaultItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> encryptedPath = const Value.absent(),
                Value<String?> originalName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> dateAdded = const Value.absent(),
                Value<DateTime> dateModified = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String> iv = const Value.absent(),
              }) => VaultItemsCompanion(
                id: id,
                name: name,
                encryptedPath: encryptedPath,
                originalName: originalName,
                mimeType: mimeType,
                size: size,
                dateAdded: dateAdded,
                dateModified: dateModified,
                album: album,
                isFavorite: isFavorite,
                thumbnailPath: thumbnailPath,
                iv: iv,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String encryptedPath,
                Value<String?> originalName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> dateAdded = const Value.absent(),
                Value<DateTime> dateModified = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                required String iv,
              }) => VaultItemsCompanion.insert(
                id: id,
                name: name,
                encryptedPath: encryptedPath,
                originalName: originalName,
                mimeType: mimeType,
                size: size,
                dateAdded: dateAdded,
                dateModified: dateModified,
                album: album,
                isFavorite: isFavorite,
                thumbnailPath: thumbnailPath,
                iv: iv,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$GallerioDatabase,
      $VaultItemsTable,
      VaultItem,
      $$VaultItemsTableFilterComposer,
      $$VaultItemsTableOrderingComposer,
      $$VaultItemsTableAnnotationComposer,
      $$VaultItemsTableCreateCompanionBuilder,
      $$VaultItemsTableUpdateCompanionBuilder,
      (
        VaultItem,
        BaseReferences<_$GallerioDatabase, $VaultItemsTable, VaultItem>,
      ),
      VaultItem,
      PrefetchHooks Function()
    >;
typedef $$TrashItemsTableCreateCompanionBuilder =
    TrashItemsCompanion Function({
      Value<int> id,
      required String assetId,
      required String name,
      required String trashPath,
      Value<String> mimeType,
      Value<int> size,
      Value<DateTime> deletedAt,
    });
typedef $$TrashItemsTableUpdateCompanionBuilder =
    TrashItemsCompanion Function({
      Value<int> id,
      Value<String> assetId,
      Value<String> name,
      Value<String> trashPath,
      Value<String> mimeType,
      Value<int> size,
      Value<DateTime> deletedAt,
    });

class $$TrashItemsTableFilterComposer
    extends Composer<_$GallerioDatabase, $TrashItemsTable> {
  $$TrashItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trashPath => $composableBuilder(
    column: $table.trashPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrashItemsTableOrderingComposer
    extends Composer<_$GallerioDatabase, $TrashItemsTable> {
  $$TrashItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trashPath => $composableBuilder(
    column: $table.trashPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrashItemsTableAnnotationComposer
    extends Composer<_$GallerioDatabase, $TrashItemsTable> {
  $$TrashItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get trashPath =>
      $composableBuilder(column: $table.trashPath, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TrashItemsTableTableManager
    extends
        RootTableManager<
          _$GallerioDatabase,
          $TrashItemsTable,
          TrashItem,
          $$TrashItemsTableFilterComposer,
          $$TrashItemsTableOrderingComposer,
          $$TrashItemsTableAnnotationComposer,
          $$TrashItemsTableCreateCompanionBuilder,
          $$TrashItemsTableUpdateCompanionBuilder,
          (
            TrashItem,
            BaseReferences<_$GallerioDatabase, $TrashItemsTable, TrashItem>,
          ),
          TrashItem,
          PrefetchHooks Function()
        > {
  $$TrashItemsTableTableManager(_$GallerioDatabase db, $TrashItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrashItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrashItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrashItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> trashPath = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
              }) => TrashItemsCompanion(
                id: id,
                assetId: assetId,
                name: name,
                trashPath: trashPath,
                mimeType: mimeType,
                size: size,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String assetId,
                required String name,
                required String trashPath,
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
              }) => TrashItemsCompanion.insert(
                id: id,
                assetId: assetId,
                name: name,
                trashPath: trashPath,
                mimeType: mimeType,
                size: size,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrashItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$GallerioDatabase,
      $TrashItemsTable,
      TrashItem,
      $$TrashItemsTableFilterComposer,
      $$TrashItemsTableOrderingComposer,
      $$TrashItemsTableAnnotationComposer,
      $$TrashItemsTableCreateCompanionBuilder,
      $$TrashItemsTableUpdateCompanionBuilder,
      (
        TrashItem,
        BaseReferences<_$GallerioDatabase, $TrashItemsTable, TrashItem>,
      ),
      TrashItem,
      PrefetchHooks Function()
    >;

class $GallerioDatabaseManager {
  final _$GallerioDatabase _db;
  $GallerioDatabaseManager(this._db);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db, _db.vaultItems);
  $$TrashItemsTableTableManager get trashItems =>
      $$TrashItemsTableTableManager(_db, _db.trashItems);
}
