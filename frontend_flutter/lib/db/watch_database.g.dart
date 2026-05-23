// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_database.dart';

// ignore_for_file: type=lint
class $AnimeHistoryTable extends AnimeHistory
    with TableInfo<$AnimeHistoryTable, AnimeHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnimeHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
      'titulo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imagenMeta = const VerificationMeta('imagen');
  @override
  late final GeneratedColumn<String> imagen = GeneratedColumn<String>(
      'imagen', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _lastEpUrlMeta =
      const VerificationMeta('lastEpUrl');
  @override
  late final GeneratedColumn<String> lastEpUrl = GeneratedColumn<String>(
      'last_ep_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _lastEpNameMeta =
      const VerificationMeta('lastEpName');
  @override
  late final GeneratedColumn<String> lastEpName = GeneratedColumn<String>(
      'last_ep_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _epCountMeta =
      const VerificationMeta('epCount');
  @override
  late final GeneratedColumn<int> epCount = GeneratedColumn<int>(
      'ep_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
      'estado', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        url,
        titulo,
        imagen,
        lastEpUrl,
        lastEpName,
        epCount,
        estado,
        ts,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anime_history';
  @override
  VerificationContext validateIntegrity(Insertable<AnimeHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('titulo')) {
      context.handle(_tituloMeta,
          titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta));
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('imagen')) {
      context.handle(_imagenMeta,
          imagen.isAcceptableOrUnknown(data['imagen']!, _imagenMeta));
    }
    if (data.containsKey('last_ep_url')) {
      context.handle(
          _lastEpUrlMeta,
          lastEpUrl.isAcceptableOrUnknown(
              data['last_ep_url']!, _lastEpUrlMeta));
    }
    if (data.containsKey('last_ep_name')) {
      context.handle(
          _lastEpNameMeta,
          lastEpName.isAcceptableOrUnknown(
              data['last_ep_name']!, _lastEpNameMeta));
    }
    if (data.containsKey('ep_count')) {
      context.handle(_epCountMeta,
          epCount.isAcceptableOrUnknown(data['ep_count']!, _epCountMeta));
    }
    if (data.containsKey('estado')) {
      context.handle(_estadoMeta,
          estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  AnimeHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnimeHistoryData(
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      titulo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}titulo'])!,
      imagen: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imagen'])!,
      lastEpUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_ep_url'])!,
      lastEpName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_ep_name'])!,
      epCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ep_count'])!,
      estado: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $AnimeHistoryTable createAlias(String alias) {
    return $AnimeHistoryTable(attachedDatabase, alias);
  }
}

class AnimeHistoryData extends DataClass
    implements Insertable<AnimeHistoryData> {
  final String url;
  final String titulo;
  final String imagen;
  final String lastEpUrl;
  final String lastEpName;
  final int epCount;
  final String estado;
  final int ts;
  final int updatedAt;
  final int? deletedAt;
  const AnimeHistoryData(
      {required this.url,
      required this.titulo,
      required this.imagen,
      required this.lastEpUrl,
      required this.lastEpName,
      required this.epCount,
      required this.estado,
      required this.ts,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['titulo'] = Variable<String>(titulo);
    map['imagen'] = Variable<String>(imagen);
    map['last_ep_url'] = Variable<String>(lastEpUrl);
    map['last_ep_name'] = Variable<String>(lastEpName);
    map['ep_count'] = Variable<int>(epCount);
    map['estado'] = Variable<String>(estado);
    map['ts'] = Variable<int>(ts);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  AnimeHistoryCompanion toCompanion(bool nullToAbsent) {
    return AnimeHistoryCompanion(
      url: Value(url),
      titulo: Value(titulo),
      imagen: Value(imagen),
      lastEpUrl: Value(lastEpUrl),
      lastEpName: Value(lastEpName),
      epCount: Value(epCount),
      estado: Value(estado),
      ts: Value(ts),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AnimeHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnimeHistoryData(
      url: serializer.fromJson<String>(json['url']),
      titulo: serializer.fromJson<String>(json['titulo']),
      imagen: serializer.fromJson<String>(json['imagen']),
      lastEpUrl: serializer.fromJson<String>(json['lastEpUrl']),
      lastEpName: serializer.fromJson<String>(json['lastEpName']),
      epCount: serializer.fromJson<int>(json['epCount']),
      estado: serializer.fromJson<String>(json['estado']),
      ts: serializer.fromJson<int>(json['ts']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'titulo': serializer.toJson<String>(titulo),
      'imagen': serializer.toJson<String>(imagen),
      'lastEpUrl': serializer.toJson<String>(lastEpUrl),
      'lastEpName': serializer.toJson<String>(lastEpName),
      'epCount': serializer.toJson<int>(epCount),
      'estado': serializer.toJson<String>(estado),
      'ts': serializer.toJson<int>(ts),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  AnimeHistoryData copyWith(
          {String? url,
          String? titulo,
          String? imagen,
          String? lastEpUrl,
          String? lastEpName,
          int? epCount,
          String? estado,
          int? ts,
          int? updatedAt,
          Value<int?> deletedAt = const Value.absent()}) =>
      AnimeHistoryData(
        url: url ?? this.url,
        titulo: titulo ?? this.titulo,
        imagen: imagen ?? this.imagen,
        lastEpUrl: lastEpUrl ?? this.lastEpUrl,
        lastEpName: lastEpName ?? this.lastEpName,
        epCount: epCount ?? this.epCount,
        estado: estado ?? this.estado,
        ts: ts ?? this.ts,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  AnimeHistoryData copyWithCompanion(AnimeHistoryCompanion data) {
    return AnimeHistoryData(
      url: data.url.present ? data.url.value : this.url,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      imagen: data.imagen.present ? data.imagen.value : this.imagen,
      lastEpUrl: data.lastEpUrl.present ? data.lastEpUrl.value : this.lastEpUrl,
      lastEpName:
          data.lastEpName.present ? data.lastEpName.value : this.lastEpName,
      epCount: data.epCount.present ? data.epCount.value : this.epCount,
      estado: data.estado.present ? data.estado.value : this.estado,
      ts: data.ts.present ? data.ts.value : this.ts,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnimeHistoryData(')
          ..write('url: $url, ')
          ..write('titulo: $titulo, ')
          ..write('imagen: $imagen, ')
          ..write('lastEpUrl: $lastEpUrl, ')
          ..write('lastEpName: $lastEpName, ')
          ..write('epCount: $epCount, ')
          ..write('estado: $estado, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(url, titulo, imagen, lastEpUrl, lastEpName,
      epCount, estado, ts, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnimeHistoryData &&
          other.url == this.url &&
          other.titulo == this.titulo &&
          other.imagen == this.imagen &&
          other.lastEpUrl == this.lastEpUrl &&
          other.lastEpName == this.lastEpName &&
          other.epCount == this.epCount &&
          other.estado == this.estado &&
          other.ts == this.ts &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AnimeHistoryCompanion extends UpdateCompanion<AnimeHistoryData> {
  final Value<String> url;
  final Value<String> titulo;
  final Value<String> imagen;
  final Value<String> lastEpUrl;
  final Value<String> lastEpName;
  final Value<int> epCount;
  final Value<String> estado;
  final Value<int> ts;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const AnimeHistoryCompanion({
    this.url = const Value.absent(),
    this.titulo = const Value.absent(),
    this.imagen = const Value.absent(),
    this.lastEpUrl = const Value.absent(),
    this.lastEpName = const Value.absent(),
    this.epCount = const Value.absent(),
    this.estado = const Value.absent(),
    this.ts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnimeHistoryCompanion.insert({
    required String url,
    required String titulo,
    this.imagen = const Value.absent(),
    this.lastEpUrl = const Value.absent(),
    this.lastEpName = const Value.absent(),
    this.epCount = const Value.absent(),
    this.estado = const Value.absent(),
    required int ts,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : url = Value(url),
        titulo = Value(titulo),
        ts = Value(ts);
  static Insertable<AnimeHistoryData> custom({
    Expression<String>? url,
    Expression<String>? titulo,
    Expression<String>? imagen,
    Expression<String>? lastEpUrl,
    Expression<String>? lastEpName,
    Expression<int>? epCount,
    Expression<String>? estado,
    Expression<int>? ts,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (titulo != null) 'titulo': titulo,
      if (imagen != null) 'imagen': imagen,
      if (lastEpUrl != null) 'last_ep_url': lastEpUrl,
      if (lastEpName != null) 'last_ep_name': lastEpName,
      if (epCount != null) 'ep_count': epCount,
      if (estado != null) 'estado': estado,
      if (ts != null) 'ts': ts,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnimeHistoryCompanion copyWith(
      {Value<String>? url,
      Value<String>? titulo,
      Value<String>? imagen,
      Value<String>? lastEpUrl,
      Value<String>? lastEpName,
      Value<int>? epCount,
      Value<String>? estado,
      Value<int>? ts,
      Value<int>? updatedAt,
      Value<int?>? deletedAt,
      Value<int>? rowid}) {
    return AnimeHistoryCompanion(
      url: url ?? this.url,
      titulo: titulo ?? this.titulo,
      imagen: imagen ?? this.imagen,
      lastEpUrl: lastEpUrl ?? this.lastEpUrl,
      lastEpName: lastEpName ?? this.lastEpName,
      epCount: epCount ?? this.epCount,
      estado: estado ?? this.estado,
      ts: ts ?? this.ts,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (imagen.present) {
      map['imagen'] = Variable<String>(imagen.value);
    }
    if (lastEpUrl.present) {
      map['last_ep_url'] = Variable<String>(lastEpUrl.value);
    }
    if (lastEpName.present) {
      map['last_ep_name'] = Variable<String>(lastEpName.value);
    }
    if (epCount.present) {
      map['ep_count'] = Variable<int>(epCount.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnimeHistoryCompanion(')
          ..write('url: $url, ')
          ..write('titulo: $titulo, ')
          ..write('imagen: $imagen, ')
          ..write('lastEpUrl: $lastEpUrl, ')
          ..write('lastEpName: $lastEpName, ')
          ..write('epCount: $epCount, ')
          ..write('estado: $estado, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchedEpisodesTable extends WatchedEpisodes
    with TableInfo<$WatchedEpisodesTable, WatchedEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchedEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeUrlMeta =
      const VerificationMeta('episodeUrl');
  @override
  late final GeneratedColumn<String> episodeUrl = GeneratedColumn<String>(
      'episode_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [episodeUrl, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watched_episodes';
  @override
  VerificationContext validateIntegrity(Insertable<WatchedEpisode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_url')) {
      context.handle(
          _episodeUrlMeta,
          episodeUrl.isAcceptableOrUnknown(
              data['episode_url']!, _episodeUrlMeta));
    } else if (isInserting) {
      context.missing(_episodeUrlMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeUrl};
  @override
  WatchedEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchedEpisode(
      episodeUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}episode_url'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $WatchedEpisodesTable createAlias(String alias) {
    return $WatchedEpisodesTable(attachedDatabase, alias);
  }
}

class WatchedEpisode extends DataClass implements Insertable<WatchedEpisode> {
  final String episodeUrl;
  final int updatedAt;
  final int? deletedAt;
  const WatchedEpisode(
      {required this.episodeUrl, required this.updatedAt, this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_url'] = Variable<String>(episodeUrl);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WatchedEpisodesCompanion toCompanion(bool nullToAbsent) {
    return WatchedEpisodesCompanion(
      episodeUrl: Value(episodeUrl),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WatchedEpisode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchedEpisode(
      episodeUrl: serializer.fromJson<String>(json['episodeUrl']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeUrl': serializer.toJson<String>(episodeUrl),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WatchedEpisode copyWith(
          {String? episodeUrl,
          int? updatedAt,
          Value<int?> deletedAt = const Value.absent()}) =>
      WatchedEpisode(
        episodeUrl: episodeUrl ?? this.episodeUrl,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  WatchedEpisode copyWithCompanion(WatchedEpisodesCompanion data) {
    return WatchedEpisode(
      episodeUrl:
          data.episodeUrl.present ? data.episodeUrl.value : this.episodeUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchedEpisode(')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(episodeUrl, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchedEpisode &&
          other.episodeUrl == this.episodeUrl &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WatchedEpisodesCompanion extends UpdateCompanion<WatchedEpisode> {
  final Value<String> episodeUrl;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WatchedEpisodesCompanion({
    this.episodeUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchedEpisodesCompanion.insert({
    required String episodeUrl,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : episodeUrl = Value(episodeUrl);
  static Insertable<WatchedEpisode> custom({
    Expression<String>? episodeUrl,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (episodeUrl != null) 'episode_url': episodeUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchedEpisodesCompanion copyWith(
      {Value<String>? episodeUrl,
      Value<int>? updatedAt,
      Value<int?>? deletedAt,
      Value<int>? rowid}) {
    return WatchedEpisodesCompanion(
      episodeUrl: episodeUrl ?? this.episodeUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeUrl.present) {
      map['episode_url'] = Variable<String>(episodeUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchedEpisodesCompanion(')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodeProgressTable extends EpisodeProgress
    with TableInfo<$EpisodeProgressTable, EpisodeProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeUrlMeta =
      const VerificationMeta('episodeUrl');
  @override
  late final GeneratedColumn<String> episodeUrl = GeneratedColumn<String>(
      'episode_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
      'position', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
      'duration', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [episodeUrl, position, duration, ts, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<EpisodeProgressData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_url')) {
      context.handle(
          _episodeUrlMeta,
          episodeUrl.isAcceptableOrUnknown(
              data['episode_url']!, _episodeUrlMeta));
    } else if (isInserting) {
      context.missing(_episodeUrlMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeUrl};
  @override
  EpisodeProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeProgressData(
      episodeUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}episode_url'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $EpisodeProgressTable createAlias(String alias) {
    return $EpisodeProgressTable(attachedDatabase, alias);
  }
}

class EpisodeProgressData extends DataClass
    implements Insertable<EpisodeProgressData> {
  final String episodeUrl;
  final double position;
  final double duration;
  final int ts;
  final int updatedAt;
  final int? deletedAt;
  const EpisodeProgressData(
      {required this.episodeUrl,
      required this.position,
      required this.duration,
      required this.ts,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_url'] = Variable<String>(episodeUrl);
    map['position'] = Variable<double>(position);
    map['duration'] = Variable<double>(duration);
    map['ts'] = Variable<int>(ts);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  EpisodeProgressCompanion toCompanion(bool nullToAbsent) {
    return EpisodeProgressCompanion(
      episodeUrl: Value(episodeUrl),
      position: Value(position),
      duration: Value(duration),
      ts: Value(ts),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EpisodeProgressData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeProgressData(
      episodeUrl: serializer.fromJson<String>(json['episodeUrl']),
      position: serializer.fromJson<double>(json['position']),
      duration: serializer.fromJson<double>(json['duration']),
      ts: serializer.fromJson<int>(json['ts']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeUrl': serializer.toJson<String>(episodeUrl),
      'position': serializer.toJson<double>(position),
      'duration': serializer.toJson<double>(duration),
      'ts': serializer.toJson<int>(ts),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  EpisodeProgressData copyWith(
          {String? episodeUrl,
          double? position,
          double? duration,
          int? ts,
          int? updatedAt,
          Value<int?> deletedAt = const Value.absent()}) =>
      EpisodeProgressData(
        episodeUrl: episodeUrl ?? this.episodeUrl,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        ts: ts ?? this.ts,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  EpisodeProgressData copyWithCompanion(EpisodeProgressCompanion data) {
    return EpisodeProgressData(
      episodeUrl:
          data.episodeUrl.present ? data.episodeUrl.value : this.episodeUrl,
      position: data.position.present ? data.position.value : this.position,
      duration: data.duration.present ? data.duration.value : this.duration,
      ts: data.ts.present ? data.ts.value : this.ts,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeProgressData(')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(episodeUrl, position, duration, ts, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeProgressData &&
          other.episodeUrl == this.episodeUrl &&
          other.position == this.position &&
          other.duration == this.duration &&
          other.ts == this.ts &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EpisodeProgressCompanion extends UpdateCompanion<EpisodeProgressData> {
  final Value<String> episodeUrl;
  final Value<double> position;
  final Value<double> duration;
  final Value<int> ts;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const EpisodeProgressCompanion({
    this.episodeUrl = const Value.absent(),
    this.position = const Value.absent(),
    this.duration = const Value.absent(),
    this.ts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodeProgressCompanion.insert({
    required String episodeUrl,
    required double position,
    required double duration,
    required int ts,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : episodeUrl = Value(episodeUrl),
        position = Value(position),
        duration = Value(duration),
        ts = Value(ts);
  static Insertable<EpisodeProgressData> custom({
    Expression<String>? episodeUrl,
    Expression<double>? position,
    Expression<double>? duration,
    Expression<int>? ts,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (episodeUrl != null) 'episode_url': episodeUrl,
      if (position != null) 'position': position,
      if (duration != null) 'duration': duration,
      if (ts != null) 'ts': ts,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodeProgressCompanion copyWith(
      {Value<String>? episodeUrl,
      Value<double>? position,
      Value<double>? duration,
      Value<int>? ts,
      Value<int>? updatedAt,
      Value<int?>? deletedAt,
      Value<int>? rowid}) {
    return EpisodeProgressCompanion(
      episodeUrl: episodeUrl ?? this.episodeUrl,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      ts: ts ?? this.ts,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeUrl.present) {
      map['episode_url'] = Variable<String>(episodeUrl.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeProgressCompanion(')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListingsCacheTable extends ListingsCache
    with TableInfo<$ListingsCacheTable, ListingsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListingsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataJsonMeta =
      const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
      'data_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, dataJson, ts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listings_cache';
  @override
  VerificationContext validateIntegrity(Insertable<ListingsCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(_dataJsonMeta,
          dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta));
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ListingsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListingsCacheData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      dataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_json'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
    );
  }

  @override
  $ListingsCacheTable createAlias(String alias) {
    return $ListingsCacheTable(attachedDatabase, alias);
  }
}

class ListingsCacheData extends DataClass
    implements Insertable<ListingsCacheData> {
  final String key;
  final String dataJson;
  final int ts;
  const ListingsCacheData(
      {required this.key, required this.dataJson, required this.ts});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['data_json'] = Variable<String>(dataJson);
    map['ts'] = Variable<int>(ts);
    return map;
  }

  ListingsCacheCompanion toCompanion(bool nullToAbsent) {
    return ListingsCacheCompanion(
      key: Value(key),
      dataJson: Value(dataJson),
      ts: Value(ts),
    );
  }

  factory ListingsCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListingsCacheData(
      key: serializer.fromJson<String>(json['key']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      ts: serializer.fromJson<int>(json['ts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'dataJson': serializer.toJson<String>(dataJson),
      'ts': serializer.toJson<int>(ts),
    };
  }

  ListingsCacheData copyWith({String? key, String? dataJson, int? ts}) =>
      ListingsCacheData(
        key: key ?? this.key,
        dataJson: dataJson ?? this.dataJson,
        ts: ts ?? this.ts,
      );
  ListingsCacheData copyWithCompanion(ListingsCacheCompanion data) {
    return ListingsCacheData(
      key: data.key.present ? data.key.value : this.key,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      ts: data.ts.present ? data.ts.value : this.ts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListingsCacheData(')
          ..write('key: $key, ')
          ..write('dataJson: $dataJson, ')
          ..write('ts: $ts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, dataJson, ts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListingsCacheData &&
          other.key == this.key &&
          other.dataJson == this.dataJson &&
          other.ts == this.ts);
}

class ListingsCacheCompanion extends UpdateCompanion<ListingsCacheData> {
  final Value<String> key;
  final Value<String> dataJson;
  final Value<int> ts;
  final Value<int> rowid;
  const ListingsCacheCompanion({
    this.key = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.ts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListingsCacheCompanion.insert({
    required String key,
    required String dataJson,
    required int ts,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        dataJson = Value(dataJson),
        ts = Value(ts);
  static Insertable<ListingsCacheData> custom({
    Expression<String>? key,
    Expression<String>? dataJson,
    Expression<int>? ts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (dataJson != null) 'data_json': dataJson,
      if (ts != null) 'ts': ts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListingsCacheCompanion copyWith(
      {Value<String>? key,
      Value<String>? dataJson,
      Value<int>? ts,
      Value<int>? rowid}) {
    return ListingsCacheCompanion(
      key: key ?? this.key,
      dataJson: dataJson ?? this.dataJson,
      ts: ts ?? this.ts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListingsCacheCompanion(')
          ..write('key: $key, ')
          ..write('dataJson: $dataJson, ')
          ..write('ts: $ts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MyListEntriesTable extends MyListEntries
    with TableInfo<$MyListEntriesTable, MyListEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MyListEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _animeUrlMeta =
      const VerificationMeta('animeUrl');
  @override
  late final GeneratedColumn<String> animeUrl = GeneratedColumn<String>(
      'anime_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
      'titulo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imagenMeta = const VerificationMeta('imagen');
  @override
  late final GeneratedColumn<String> imagen = GeneratedColumn<String>(
      'imagen', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _episodesWatchedMeta =
      const VerificationMeta('episodesWatched');
  @override
  late final GeneratedColumn<int> episodesWatched = GeneratedColumn<int>(
      'episodes_watched', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalEpisodesMeta =
      const VerificationMeta('totalEpisodes');
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
      'total_episodes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        animeUrl,
        titulo,
        imagen,
        status,
        episodesWatched,
        totalEpisodes,
        ts,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'my_list_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MyListEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anime_url')) {
      context.handle(_animeUrlMeta,
          animeUrl.isAcceptableOrUnknown(data['anime_url']!, _animeUrlMeta));
    } else if (isInserting) {
      context.missing(_animeUrlMeta);
    }
    if (data.containsKey('titulo')) {
      context.handle(_tituloMeta,
          titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta));
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('imagen')) {
      context.handle(_imagenMeta,
          imagen.isAcceptableOrUnknown(data['imagen']!, _imagenMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('episodes_watched')) {
      context.handle(
          _episodesWatchedMeta,
          episodesWatched.isAcceptableOrUnknown(
              data['episodes_watched']!, _episodesWatchedMeta));
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
          _totalEpisodesMeta,
          totalEpisodes.isAcceptableOrUnknown(
              data['total_episodes']!, _totalEpisodesMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {animeUrl};
  @override
  MyListEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MyListEntry(
      animeUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anime_url'])!,
      titulo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}titulo'])!,
      imagen: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imagen'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      episodesWatched: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episodes_watched'])!,
      totalEpisodes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_episodes'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $MyListEntriesTable createAlias(String alias) {
    return $MyListEntriesTable(attachedDatabase, alias);
  }
}

class MyListEntry extends DataClass implements Insertable<MyListEntry> {
  final String animeUrl;
  final String titulo;
  final String imagen;
  final String status;
  final int episodesWatched;
  final int totalEpisodes;
  final int ts;
  final int updatedAt;
  final int? deletedAt;
  const MyListEntry(
      {required this.animeUrl,
      required this.titulo,
      required this.imagen,
      required this.status,
      required this.episodesWatched,
      required this.totalEpisodes,
      required this.ts,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anime_url'] = Variable<String>(animeUrl);
    map['titulo'] = Variable<String>(titulo);
    map['imagen'] = Variable<String>(imagen);
    map['status'] = Variable<String>(status);
    map['episodes_watched'] = Variable<int>(episodesWatched);
    map['total_episodes'] = Variable<int>(totalEpisodes);
    map['ts'] = Variable<int>(ts);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  MyListEntriesCompanion toCompanion(bool nullToAbsent) {
    return MyListEntriesCompanion(
      animeUrl: Value(animeUrl),
      titulo: Value(titulo),
      imagen: Value(imagen),
      status: Value(status),
      episodesWatched: Value(episodesWatched),
      totalEpisodes: Value(totalEpisodes),
      ts: Value(ts),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MyListEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MyListEntry(
      animeUrl: serializer.fromJson<String>(json['animeUrl']),
      titulo: serializer.fromJson<String>(json['titulo']),
      imagen: serializer.fromJson<String>(json['imagen']),
      status: serializer.fromJson<String>(json['status']),
      episodesWatched: serializer.fromJson<int>(json['episodesWatched']),
      totalEpisodes: serializer.fromJson<int>(json['totalEpisodes']),
      ts: serializer.fromJson<int>(json['ts']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'animeUrl': serializer.toJson<String>(animeUrl),
      'titulo': serializer.toJson<String>(titulo),
      'imagen': serializer.toJson<String>(imagen),
      'status': serializer.toJson<String>(status),
      'episodesWatched': serializer.toJson<int>(episodesWatched),
      'totalEpisodes': serializer.toJson<int>(totalEpisodes),
      'ts': serializer.toJson<int>(ts),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  MyListEntry copyWith(
          {String? animeUrl,
          String? titulo,
          String? imagen,
          String? status,
          int? episodesWatched,
          int? totalEpisodes,
          int? ts,
          int? updatedAt,
          Value<int?> deletedAt = const Value.absent()}) =>
      MyListEntry(
        animeUrl: animeUrl ?? this.animeUrl,
        titulo: titulo ?? this.titulo,
        imagen: imagen ?? this.imagen,
        status: status ?? this.status,
        episodesWatched: episodesWatched ?? this.episodesWatched,
        totalEpisodes: totalEpisodes ?? this.totalEpisodes,
        ts: ts ?? this.ts,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  MyListEntry copyWithCompanion(MyListEntriesCompanion data) {
    return MyListEntry(
      animeUrl: data.animeUrl.present ? data.animeUrl.value : this.animeUrl,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      imagen: data.imagen.present ? data.imagen.value : this.imagen,
      status: data.status.present ? data.status.value : this.status,
      episodesWatched: data.episodesWatched.present
          ? data.episodesWatched.value
          : this.episodesWatched,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      ts: data.ts.present ? data.ts.value : this.ts,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MyListEntry(')
          ..write('animeUrl: $animeUrl, ')
          ..write('titulo: $titulo, ')
          ..write('imagen: $imagen, ')
          ..write('status: $status, ')
          ..write('episodesWatched: $episodesWatched, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(animeUrl, titulo, imagen, status,
      episodesWatched, totalEpisodes, ts, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MyListEntry &&
          other.animeUrl == this.animeUrl &&
          other.titulo == this.titulo &&
          other.imagen == this.imagen &&
          other.status == this.status &&
          other.episodesWatched == this.episodesWatched &&
          other.totalEpisodes == this.totalEpisodes &&
          other.ts == this.ts &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MyListEntriesCompanion extends UpdateCompanion<MyListEntry> {
  final Value<String> animeUrl;
  final Value<String> titulo;
  final Value<String> imagen;
  final Value<String> status;
  final Value<int> episodesWatched;
  final Value<int> totalEpisodes;
  final Value<int> ts;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const MyListEntriesCompanion({
    this.animeUrl = const Value.absent(),
    this.titulo = const Value.absent(),
    this.imagen = const Value.absent(),
    this.status = const Value.absent(),
    this.episodesWatched = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.ts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MyListEntriesCompanion.insert({
    required String animeUrl,
    required String titulo,
    this.imagen = const Value.absent(),
    required String status,
    this.episodesWatched = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    required int ts,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : animeUrl = Value(animeUrl),
        titulo = Value(titulo),
        status = Value(status),
        ts = Value(ts);
  static Insertable<MyListEntry> custom({
    Expression<String>? animeUrl,
    Expression<String>? titulo,
    Expression<String>? imagen,
    Expression<String>? status,
    Expression<int>? episodesWatched,
    Expression<int>? totalEpisodes,
    Expression<int>? ts,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (animeUrl != null) 'anime_url': animeUrl,
      if (titulo != null) 'titulo': titulo,
      if (imagen != null) 'imagen': imagen,
      if (status != null) 'status': status,
      if (episodesWatched != null) 'episodes_watched': episodesWatched,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (ts != null) 'ts': ts,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MyListEntriesCompanion copyWith(
      {Value<String>? animeUrl,
      Value<String>? titulo,
      Value<String>? imagen,
      Value<String>? status,
      Value<int>? episodesWatched,
      Value<int>? totalEpisodes,
      Value<int>? ts,
      Value<int>? updatedAt,
      Value<int?>? deletedAt,
      Value<int>? rowid}) {
    return MyListEntriesCompanion(
      animeUrl: animeUrl ?? this.animeUrl,
      titulo: titulo ?? this.titulo,
      imagen: imagen ?? this.imagen,
      status: status ?? this.status,
      episodesWatched: episodesWatched ?? this.episodesWatched,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      ts: ts ?? this.ts,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (animeUrl.present) {
      map['anime_url'] = Variable<String>(animeUrl.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (imagen.present) {
      map['imagen'] = Variable<String>(imagen.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (episodesWatched.present) {
      map['episodes_watched'] = Variable<int>(episodesWatched.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MyListEntriesCompanion(')
          ..write('animeUrl: $animeUrl, ')
          ..write('titulo: $titulo, ')
          ..write('imagen: $imagen, ')
          ..write('status: $status, ')
          ..write('episodesWatched: $episodesWatched, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('ts: $ts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WatchDatabase extends GeneratedDatabase {
  _$WatchDatabase(QueryExecutor e) : super(e);
  $WatchDatabaseManager get managers => $WatchDatabaseManager(this);
  late final $AnimeHistoryTable animeHistory = $AnimeHistoryTable(this);
  late final $WatchedEpisodesTable watchedEpisodes =
      $WatchedEpisodesTable(this);
  late final $EpisodeProgressTable episodeProgress =
      $EpisodeProgressTable(this);
  late final $ListingsCacheTable listingsCache = $ListingsCacheTable(this);
  late final $MyListEntriesTable myListEntries = $MyListEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        animeHistory,
        watchedEpisodes,
        episodeProgress,
        listingsCache,
        myListEntries
      ];
}

typedef $$AnimeHistoryTableCreateCompanionBuilder = AnimeHistoryCompanion
    Function({
  required String url,
  required String titulo,
  Value<String> imagen,
  Value<String> lastEpUrl,
  Value<String> lastEpName,
  Value<int> epCount,
  Value<String> estado,
  required int ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$AnimeHistoryTableUpdateCompanionBuilder = AnimeHistoryCompanion
    Function({
  Value<String> url,
  Value<String> titulo,
  Value<String> imagen,
  Value<String> lastEpUrl,
  Value<String> lastEpName,
  Value<int> epCount,
  Value<String> estado,
  Value<int> ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$AnimeHistoryTableFilterComposer
    extends Composer<_$WatchDatabase, $AnimeHistoryTable> {
  $$AnimeHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagen => $composableBuilder(
      column: $table.imagen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastEpUrl => $composableBuilder(
      column: $table.lastEpUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastEpName => $composableBuilder(
      column: $table.lastEpName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get epCount => $composableBuilder(
      column: $table.epCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$AnimeHistoryTableOrderingComposer
    extends Composer<_$WatchDatabase, $AnimeHistoryTable> {
  $$AnimeHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagen => $composableBuilder(
      column: $table.imagen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastEpUrl => $composableBuilder(
      column: $table.lastEpUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastEpName => $composableBuilder(
      column: $table.lastEpName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get epCount => $composableBuilder(
      column: $table.epCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$AnimeHistoryTableAnnotationComposer
    extends Composer<_$WatchDatabase, $AnimeHistoryTable> {
  $$AnimeHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get imagen =>
      $composableBuilder(column: $table.imagen, builder: (column) => column);

  GeneratedColumn<String> get lastEpUrl =>
      $composableBuilder(column: $table.lastEpUrl, builder: (column) => column);

  GeneratedColumn<String> get lastEpName => $composableBuilder(
      column: $table.lastEpName, builder: (column) => column);

  GeneratedColumn<int> get epCount =>
      $composableBuilder(column: $table.epCount, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AnimeHistoryTableTableManager extends RootTableManager<
    _$WatchDatabase,
    $AnimeHistoryTable,
    AnimeHistoryData,
    $$AnimeHistoryTableFilterComposer,
    $$AnimeHistoryTableOrderingComposer,
    $$AnimeHistoryTableAnnotationComposer,
    $$AnimeHistoryTableCreateCompanionBuilder,
    $$AnimeHistoryTableUpdateCompanionBuilder,
    (
      AnimeHistoryData,
      BaseReferences<_$WatchDatabase, $AnimeHistoryTable, AnimeHistoryData>
    ),
    AnimeHistoryData,
    PrefetchHooks Function()> {
  $$AnimeHistoryTableTableManager(_$WatchDatabase db, $AnimeHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnimeHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnimeHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnimeHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> url = const Value.absent(),
            Value<String> titulo = const Value.absent(),
            Value<String> imagen = const Value.absent(),
            Value<String> lastEpUrl = const Value.absent(),
            Value<String> lastEpName = const Value.absent(),
            Value<int> epCount = const Value.absent(),
            Value<String> estado = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnimeHistoryCompanion(
            url: url,
            titulo: titulo,
            imagen: imagen,
            lastEpUrl: lastEpUrl,
            lastEpName: lastEpName,
            epCount: epCount,
            estado: estado,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String url,
            required String titulo,
            Value<String> imagen = const Value.absent(),
            Value<String> lastEpUrl = const Value.absent(),
            Value<String> lastEpName = const Value.absent(),
            Value<int> epCount = const Value.absent(),
            Value<String> estado = const Value.absent(),
            required int ts,
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnimeHistoryCompanion.insert(
            url: url,
            titulo: titulo,
            imagen: imagen,
            lastEpUrl: lastEpUrl,
            lastEpName: lastEpName,
            epCount: epCount,
            estado: estado,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnimeHistoryTableProcessedTableManager = ProcessedTableManager<
    _$WatchDatabase,
    $AnimeHistoryTable,
    AnimeHistoryData,
    $$AnimeHistoryTableFilterComposer,
    $$AnimeHistoryTableOrderingComposer,
    $$AnimeHistoryTableAnnotationComposer,
    $$AnimeHistoryTableCreateCompanionBuilder,
    $$AnimeHistoryTableUpdateCompanionBuilder,
    (
      AnimeHistoryData,
      BaseReferences<_$WatchDatabase, $AnimeHistoryTable, AnimeHistoryData>
    ),
    AnimeHistoryData,
    PrefetchHooks Function()>;
typedef $$WatchedEpisodesTableCreateCompanionBuilder = WatchedEpisodesCompanion
    Function({
  required String episodeUrl,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$WatchedEpisodesTableUpdateCompanionBuilder = WatchedEpisodesCompanion
    Function({
  Value<String> episodeUrl,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$WatchedEpisodesTableFilterComposer
    extends Composer<_$WatchDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$WatchedEpisodesTableOrderingComposer
    extends Composer<_$WatchDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$WatchedEpisodesTableAnnotationComposer
    extends Composer<_$WatchDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WatchedEpisodesTableTableManager extends RootTableManager<
    _$WatchDatabase,
    $WatchedEpisodesTable,
    WatchedEpisode,
    $$WatchedEpisodesTableFilterComposer,
    $$WatchedEpisodesTableOrderingComposer,
    $$WatchedEpisodesTableAnnotationComposer,
    $$WatchedEpisodesTableCreateCompanionBuilder,
    $$WatchedEpisodesTableUpdateCompanionBuilder,
    (
      WatchedEpisode,
      BaseReferences<_$WatchDatabase, $WatchedEpisodesTable, WatchedEpisode>
    ),
    WatchedEpisode,
    PrefetchHooks Function()> {
  $$WatchedEpisodesTableTableManager(
      _$WatchDatabase db, $WatchedEpisodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchedEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchedEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchedEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> episodeUrl = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchedEpisodesCompanion(
            episodeUrl: episodeUrl,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String episodeUrl,
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchedEpisodesCompanion.insert(
            episodeUrl: episodeUrl,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchedEpisodesTableProcessedTableManager = ProcessedTableManager<
    _$WatchDatabase,
    $WatchedEpisodesTable,
    WatchedEpisode,
    $$WatchedEpisodesTableFilterComposer,
    $$WatchedEpisodesTableOrderingComposer,
    $$WatchedEpisodesTableAnnotationComposer,
    $$WatchedEpisodesTableCreateCompanionBuilder,
    $$WatchedEpisodesTableUpdateCompanionBuilder,
    (
      WatchedEpisode,
      BaseReferences<_$WatchDatabase, $WatchedEpisodesTable, WatchedEpisode>
    ),
    WatchedEpisode,
    PrefetchHooks Function()>;
typedef $$EpisodeProgressTableCreateCompanionBuilder = EpisodeProgressCompanion
    Function({
  required String episodeUrl,
  required double position,
  required double duration,
  required int ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$EpisodeProgressTableUpdateCompanionBuilder = EpisodeProgressCompanion
    Function({
  Value<String> episodeUrl,
  Value<double> position,
  Value<double> duration,
  Value<int> ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$EpisodeProgressTableFilterComposer
    extends Composer<_$WatchDatabase, $EpisodeProgressTable> {
  $$EpisodeProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$EpisodeProgressTableOrderingComposer
    extends Composer<_$WatchDatabase, $EpisodeProgressTable> {
  $$EpisodeProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$EpisodeProgressTableAnnotationComposer
    extends Composer<_$WatchDatabase, $EpisodeProgressTable> {
  $$EpisodeProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get episodeUrl => $composableBuilder(
      column: $table.episodeUrl, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EpisodeProgressTableTableManager extends RootTableManager<
    _$WatchDatabase,
    $EpisodeProgressTable,
    EpisodeProgressData,
    $$EpisodeProgressTableFilterComposer,
    $$EpisodeProgressTableOrderingComposer,
    $$EpisodeProgressTableAnnotationComposer,
    $$EpisodeProgressTableCreateCompanionBuilder,
    $$EpisodeProgressTableUpdateCompanionBuilder,
    (
      EpisodeProgressData,
      BaseReferences<_$WatchDatabase, $EpisodeProgressTable,
          EpisodeProgressData>
    ),
    EpisodeProgressData,
    PrefetchHooks Function()> {
  $$EpisodeProgressTableTableManager(
      _$WatchDatabase db, $EpisodeProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> episodeUrl = const Value.absent(),
            Value<double> position = const Value.absent(),
            Value<double> duration = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodeProgressCompanion(
            episodeUrl: episodeUrl,
            position: position,
            duration: duration,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String episodeUrl,
            required double position,
            required double duration,
            required int ts,
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodeProgressCompanion.insert(
            episodeUrl: episodeUrl,
            position: position,
            duration: duration,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EpisodeProgressTableProcessedTableManager = ProcessedTableManager<
    _$WatchDatabase,
    $EpisodeProgressTable,
    EpisodeProgressData,
    $$EpisodeProgressTableFilterComposer,
    $$EpisodeProgressTableOrderingComposer,
    $$EpisodeProgressTableAnnotationComposer,
    $$EpisodeProgressTableCreateCompanionBuilder,
    $$EpisodeProgressTableUpdateCompanionBuilder,
    (
      EpisodeProgressData,
      BaseReferences<_$WatchDatabase, $EpisodeProgressTable,
          EpisodeProgressData>
    ),
    EpisodeProgressData,
    PrefetchHooks Function()>;
typedef $$ListingsCacheTableCreateCompanionBuilder = ListingsCacheCompanion
    Function({
  required String key,
  required String dataJson,
  required int ts,
  Value<int> rowid,
});
typedef $$ListingsCacheTableUpdateCompanionBuilder = ListingsCacheCompanion
    Function({
  Value<String> key,
  Value<String> dataJson,
  Value<int> ts,
  Value<int> rowid,
});

class $$ListingsCacheTableFilterComposer
    extends Composer<_$WatchDatabase, $ListingsCacheTable> {
  $$ListingsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));
}

class $$ListingsCacheTableOrderingComposer
    extends Composer<_$WatchDatabase, $ListingsCacheTable> {
  $$ListingsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));
}

class $$ListingsCacheTableAnnotationComposer
    extends Composer<_$WatchDatabase, $ListingsCacheTable> {
  $$ListingsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);
}

class $$ListingsCacheTableTableManager extends RootTableManager<
    _$WatchDatabase,
    $ListingsCacheTable,
    ListingsCacheData,
    $$ListingsCacheTableFilterComposer,
    $$ListingsCacheTableOrderingComposer,
    $$ListingsCacheTableAnnotationComposer,
    $$ListingsCacheTableCreateCompanionBuilder,
    $$ListingsCacheTableUpdateCompanionBuilder,
    (
      ListingsCacheData,
      BaseReferences<_$WatchDatabase, $ListingsCacheTable, ListingsCacheData>
    ),
    ListingsCacheData,
    PrefetchHooks Function()> {
  $$ListingsCacheTableTableManager(
      _$WatchDatabase db, $ListingsCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListingsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListingsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListingsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> dataJson = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ListingsCacheCompanion(
            key: key,
            dataJson: dataJson,
            ts: ts,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String dataJson,
            required int ts,
            Value<int> rowid = const Value.absent(),
          }) =>
              ListingsCacheCompanion.insert(
            key: key,
            dataJson: dataJson,
            ts: ts,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ListingsCacheTableProcessedTableManager = ProcessedTableManager<
    _$WatchDatabase,
    $ListingsCacheTable,
    ListingsCacheData,
    $$ListingsCacheTableFilterComposer,
    $$ListingsCacheTableOrderingComposer,
    $$ListingsCacheTableAnnotationComposer,
    $$ListingsCacheTableCreateCompanionBuilder,
    $$ListingsCacheTableUpdateCompanionBuilder,
    (
      ListingsCacheData,
      BaseReferences<_$WatchDatabase, $ListingsCacheTable, ListingsCacheData>
    ),
    ListingsCacheData,
    PrefetchHooks Function()>;
typedef $$MyListEntriesTableCreateCompanionBuilder = MyListEntriesCompanion
    Function({
  required String animeUrl,
  required String titulo,
  Value<String> imagen,
  required String status,
  Value<int> episodesWatched,
  Value<int> totalEpisodes,
  required int ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$MyListEntriesTableUpdateCompanionBuilder = MyListEntriesCompanion
    Function({
  Value<String> animeUrl,
  Value<String> titulo,
  Value<String> imagen,
  Value<String> status,
  Value<int> episodesWatched,
  Value<int> totalEpisodes,
  Value<int> ts,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$MyListEntriesTableFilterComposer
    extends Composer<_$WatchDatabase, $MyListEntriesTable> {
  $$MyListEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get animeUrl => $composableBuilder(
      column: $table.animeUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagen => $composableBuilder(
      column: $table.imagen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodesWatched => $composableBuilder(
      column: $table.episodesWatched,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$MyListEntriesTableOrderingComposer
    extends Composer<_$WatchDatabase, $MyListEntriesTable> {
  $$MyListEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get animeUrl => $composableBuilder(
      column: $table.animeUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titulo => $composableBuilder(
      column: $table.titulo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagen => $composableBuilder(
      column: $table.imagen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodesWatched => $composableBuilder(
      column: $table.episodesWatched,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$MyListEntriesTableAnnotationComposer
    extends Composer<_$WatchDatabase, $MyListEntriesTable> {
  $$MyListEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get animeUrl =>
      $composableBuilder(column: $table.animeUrl, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get imagen =>
      $composableBuilder(column: $table.imagen, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get episodesWatched => $composableBuilder(
      column: $table.episodesWatched, builder: (column) => column);

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MyListEntriesTableTableManager extends RootTableManager<
    _$WatchDatabase,
    $MyListEntriesTable,
    MyListEntry,
    $$MyListEntriesTableFilterComposer,
    $$MyListEntriesTableOrderingComposer,
    $$MyListEntriesTableAnnotationComposer,
    $$MyListEntriesTableCreateCompanionBuilder,
    $$MyListEntriesTableUpdateCompanionBuilder,
    (
      MyListEntry,
      BaseReferences<_$WatchDatabase, $MyListEntriesTable, MyListEntry>
    ),
    MyListEntry,
    PrefetchHooks Function()> {
  $$MyListEntriesTableTableManager(
      _$WatchDatabase db, $MyListEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MyListEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MyListEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MyListEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> animeUrl = const Value.absent(),
            Value<String> titulo = const Value.absent(),
            Value<String> imagen = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> episodesWatched = const Value.absent(),
            Value<int> totalEpisodes = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MyListEntriesCompanion(
            animeUrl: animeUrl,
            titulo: titulo,
            imagen: imagen,
            status: status,
            episodesWatched: episodesWatched,
            totalEpisodes: totalEpisodes,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String animeUrl,
            required String titulo,
            Value<String> imagen = const Value.absent(),
            required String status,
            Value<int> episodesWatched = const Value.absent(),
            Value<int> totalEpisodes = const Value.absent(),
            required int ts,
            Value<int> updatedAt = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MyListEntriesCompanion.insert(
            animeUrl: animeUrl,
            titulo: titulo,
            imagen: imagen,
            status: status,
            episodesWatched: episodesWatched,
            totalEpisodes: totalEpisodes,
            ts: ts,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MyListEntriesTableProcessedTableManager = ProcessedTableManager<
    _$WatchDatabase,
    $MyListEntriesTable,
    MyListEntry,
    $$MyListEntriesTableFilterComposer,
    $$MyListEntriesTableOrderingComposer,
    $$MyListEntriesTableAnnotationComposer,
    $$MyListEntriesTableCreateCompanionBuilder,
    $$MyListEntriesTableUpdateCompanionBuilder,
    (
      MyListEntry,
      BaseReferences<_$WatchDatabase, $MyListEntriesTable, MyListEntry>
    ),
    MyListEntry,
    PrefetchHooks Function()>;

class $WatchDatabaseManager {
  final _$WatchDatabase _db;
  $WatchDatabaseManager(this._db);
  $$AnimeHistoryTableTableManager get animeHistory =>
      $$AnimeHistoryTableTableManager(_db, _db.animeHistory);
  $$WatchedEpisodesTableTableManager get watchedEpisodes =>
      $$WatchedEpisodesTableTableManager(_db, _db.watchedEpisodes);
  $$EpisodeProgressTableTableManager get episodeProgress =>
      $$EpisodeProgressTableTableManager(_db, _db.episodeProgress);
  $$ListingsCacheTableTableManager get listingsCache =>
      $$ListingsCacheTableTableManager(_db, _db.listingsCache);
  $$MyListEntriesTableTableManager get myListEntries =>
      $$MyListEntriesTableTableManager(_db, _db.myListEntries);
}
