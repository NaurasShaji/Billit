import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import '../models/models.dart';
import 'schema.dart';
import 'sqlite_connection.dart';

export 'sqlite_connection.dart' show SqliteConnection;

part 'entity_stores.dart';

/// The app's SQLite database.
///
/// Every table is read into memory when the database opens, so reads are
/// synchronous and return the same object instances on each call. Writes go to
/// SQLite first and update the in-memory copy only once they have succeeded.
class Db {
  Db._();

  static AppDatabase? _instance;
  static String _activeDatabaseKey = 'local';

  /// Identifies the currently opened local tenant database (never an auth token).
  static String get activeDatabaseKey => _activeDatabaseKey;

  static AppDatabase get instance =>
      _instance ?? (throw StateError('Db.open() has not been called'));

  static bool get isOpen => _instance != null;

  /// Opens the on-device database file (IndexedDB-backed on the web).
  static Future<void> open() async {
    if (_instance != null) return;
    _activeDatabaseKey = 'local';
    _instance = AppDatabase(await openAppDatabase());
  }

  /// Opens a physically separate SQLite/IndexedDB file for one shop.
  /// The original `billit.db` is deliberately left untouched for safe legacy
  /// migration and local-only use. Shop IDs are validated before becoming a
  /// filename/database name.
  static Future<void> openTenantDatabase(String shopId) async {
    if (shopId.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(shopId)) {
      throw ArgumentError.value(shopId, 'shopId', 'Invalid shop identifier');
    }
    final key = 'shop:$shopId';
    if (_instance != null && _activeDatabaseKey == key) return;
    _instance?.close();
    _instance = null;
    _activeDatabaseKey = key;
    try {
      _instance = AppDatabase(
        await openAppDatabase(databaseName: 'billit_shop_$shopId'),
      );
    } catch (_) {
      _activeDatabaseKey = 'local';
      _instance = AppDatabase(await openAppDatabase());
      rethrow;
    }
  }

  /// Returns to the original local database without copying or deleting data.
  static Future<void> openLocalDatabase() async {
    if (_instance != null && _activeDatabaseKey == 'local') return;
    _instance?.close();
    _instance = null;
    _activeDatabaseKey = 'local';
    _instance = AppDatabase(await openAppDatabase());
  }

  static Future<List<SyncOutboxChange>> pendingSyncChanges({int limit = 100, int afterId = 0}) =>
      instance.pendingSyncChanges(limit: limit, afterId: afterId);

  static bool hasPendingSyncChange(String tableName, String recordId) =>
      instance.hasPendingSyncChange(tableName, recordId);

  static Future<void> acknowledgeSyncChange(int id, int revision) =>
      instance.acknowledgeSyncChange(id, revision);

  static Future<void> recordSyncFailure(int id, int revision, String error) =>
      instance.recordSyncFailure(id, revision, error);

  static Future<void> discardSyncChange(String tableName, String recordId) =>
      instance.discardSyncChange(tableName, recordId);

  static Future<R> withoutOutbox<R>(Future<R> Function() action) =>
      instance.withoutOutbox(action);

  /// Uses an already opened connection, e.g. an in-memory database in tests.
  static void openWith(SqliteConnection connection) {
    _instance?.close();
    _activeDatabaseKey = 'local';
    _instance = AppDatabase(connection);
  }

  static void close() {
    _instance?.close();
    _instance = null;
    _activeDatabaseKey = 'local';
  }

  static EntityStore<User> get users => instance.users;
  static EntityStore<Product> get products => instance.products;
  static EntityStore<Sale> get sales => instance.sales;
  static EntityStore<Expense> get expenses => instance.expenses;
  static EntityStore<Employee> get employees => instance.employees;

  /// Business, invoice, GST, appearance and printer preferences.
  static KeyValueStore get settings => instance.settings;

  /// The signed-in user and backup bookkeeping.
  static KeyValueStore get session => instance.session;

  /// Per-device values: Drive auto-sync and the saved printer address.
  static KeyValueStore get deviceSettings => instance.deviceSettings;

  static KeyValueStore get meta => instance.meta;

  /// Runs [action] in one SQLite transaction. If it throws, every write made
  /// inside it is rolled back.
  static Future<R> transaction<R>(Future<R> Function() action) =>
      instance.transaction(action);
}

class AppDatabase {
  AppDatabase(this.connection) {
    migrateSchema(db);
    users = _UserStore(this);
    products = _ProductStore(this);
    sales = _SaleStore(this);
    expenses = _ExpenseStore(this);
    employees = _EmployeeStore(this);
    settings = KeyValueStore._(this, 'app_settings');
    session = KeyValueStore._(this, 'session');
    deviceSettings = KeyValueStore._(this, 'device_settings');
    meta = KeyValueStore._(this, 'meta');
    _stores = [
      users,
      products,
      sales,
      expenses,
      employees,
      settings,
      session,
      deviceSettings,
      meta,
    ];
    for (final store in _stores) {
      store._load();
    }
  }

  final SqliteConnection connection;
  CommonDatabase get db => connection.db;

  late final EntityStore<User> users;
  late final EntityStore<Product> products;
  late final EntityStore<Sale> sales;
  late final EntityStore<Expense> expenses;
  late final EntityStore<Employee> employees;
  late final KeyValueStore settings;
  late final KeyValueStore session;
  late final KeyValueStore deviceSettings;
  late final KeyValueStore meta;

  late final List<_Store> _stores;
  final Map<String, CommonPreparedStatement> _statements = {};
  bool _inTransaction = false;

  Future<List<SyncOutboxChange>> pendingSyncChanges({int limit = 100, int afterId = 0}) async {
    final rows = db.select(
      'SELECT id, table_name, record_id, operation, changed_at, attempts, revision, next_attempt_at '
      'FROM local_sync_outbox WHERE id > ? AND next_attempt_at <= ? ORDER BY id LIMIT ?',
      [afterId, DateTime.now().millisecondsSinceEpoch, limit.clamp(1, 500)],
    );
    return rows.map((row) => SyncOutboxChange(
      id: (row['id'] as num).toInt(),
      tableName: row['table_name'] as String,
      recordId: row['record_id'] as String,
      operation: row['operation'] as String,
      changedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['changed_at'] as num).toInt(), isUtc: true),
      attempts: (row['attempts'] as num).toInt(),
      revision: (row['revision'] as num).toInt(),
      nextAttemptAt: (row['next_attempt_at'] as num).toInt(),
    )).toList();
  }

  bool hasPendingSyncChange(String tableName, String recordId) {
    final rows = db.select(
      'SELECT 1 FROM local_sync_outbox WHERE table_name = ? AND record_id = ? LIMIT 1',
      [tableName, recordId],
    );
    return rows.isNotEmpty;
  }

  Future<void> acknowledgeSyncChange(int id, int revision) async {
    db.execute('DELETE FROM local_sync_outbox WHERE id = ? AND revision = ?', [id, revision]);
    await connection.flush();
  }

  Future<void> discardSyncChange(String tableName, String recordId) async {
    db.execute(
      'DELETE FROM local_sync_outbox WHERE table_name = ? AND record_id = ?',
      [tableName, recordId],
    );
    await connection.flush();
  }

  Future<void> recordSyncFailure(int id, int revision, String error) async {
    final rows = db.select(
      'SELECT attempts FROM local_sync_outbox WHERE id = ? AND revision = ?',
      [id, revision],
    );
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as num).toInt() + 1;
    final delaySeconds = 1 << attempts.clamp(0, 10).toInt();
    final nextAttempt = DateTime.now().millisecondsSinceEpoch +
        delaySeconds * 1000;
    db.execute(
      'UPDATE local_sync_outbox SET attempts = ?, last_error = ?, '
      'next_attempt_at = ? WHERE id = ? AND revision = ?',
      [attempts, error.length > 1000 ? error.substring(0, 1000) : error,
       nextAttempt, id, revision],
    );
    await connection.flush();
  }

  Future<R> withoutOutbox<R>(Future<R> Function() action) async {
    db.execute('UPDATE local_sync_control SET suppress_outbox = 1 WHERE id = 1');
    try {
      return await action();
    } finally {
      db.execute('UPDATE local_sync_control SET suppress_outbox = 0 WHERE id = 1');
      await connection.flush();
    }
  }

  CommonPreparedStatement _statement(String sql) =>
      _statements[sql] ??= db.prepare(sql, persistent: true);

  /// Runs [body] atomically: in the surrounding transaction if there is one,
  /// otherwise in its own.
  void _write(void Function() body) {
    if (_inTransaction) {
      body();
      return;
    }
    db.execute('BEGIN');
    try {
      body();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> _flush() async {
    if (!_inTransaction) await connection.flush();
  }

  Future<R> transaction<R>(Future<R> Function() action) async {
    if (_inTransaction) return action();
    db.execute('BEGIN');
    _inTransaction = true;
    try {
      final result = await action();
      db.execute('COMMIT');
      _inTransaction = false;
      await connection.flush();
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      _inTransaction = false;
      // The in-memory copies saw the rolled-back writes; re-read the tables.
      for (final store in _stores) {
        store._load();
        store._changed();
      }
      rethrow;
    }
  }

  void close() {
    for (final statement in _statements.values) {
      statement.close();
    }
    _statements.clear();
    connection.close();
  }
}

/// A durable local change waiting to be applied to the current shop's cloud data.
class SyncOutboxChange {
  const SyncOutboxChange({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.changedAt,
    required this.attempts,
    required this.revision,
    required this.nextAttemptAt,
  });

  final int id;
  final String tableName;
  final String recordId;
  final String operation;
  final DateTime changedAt;
  final int attempts;
  final int revision;
  final int nextAttemptAt;
}

abstract class _Store {
  _Store(this._owner, this.table);

  final AppDatabase _owner;
  final String table;
  final _StoreNotifier _notifier = _StoreNotifier();
  bool _notifyScheduled = false;

  void _load();

  /// Listeners are told on the next microtask, so a write made while widgets
  /// are building never calls setState during that build.
  void _changed() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      _notifier.notify();
    });
  }
}

class _StoreNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _StoreListenable<S> implements ValueListenable<S> {
  _StoreListenable(this.value, this._notifier);

  @override
  final S value;
  final _StoreNotifier _notifier;

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);
}

/// One table of records keyed by their `id`. Iteration is in `id` order.
abstract class EntityStore<T> extends _Store {
  EntityStore._(super.owner, super.table, this._columns);

  /// Column names after `id`, in the order [_toRow] returns their values.
  final List<String> _columns;
  final SplayTreeMap<String, T> _cache = SplayTreeMap<String, T>();
  late final ValueListenable<EntityStore<T>> _listenable =
      _StoreListenable<EntityStore<T>>(this, _notifier);

  String _idOf(T value);
  List<Object?> _toRow(T value);
  T _fromRow(Row row);

  late final String _upsertSql = 'INSERT INTO $table '
      '(id, ${_columns.join(', ')}) '
      'VALUES (?${', ?' * _columns.length}) '
      'ON CONFLICT (id) DO UPDATE SET '
      '${_columns.map((c) => '$c = excluded.$c').join(', ')}';

  Iterable<T> get values => _cache.values;
  Iterable<String> get keys => _cache.keys;
  int get length => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  bool containsKey(Object? id) => _cache.containsKey(id);
  T? get(Object? id) => id is String ? _cache[id] : null;
  Map<String, T> toMap() => Map<String, T>.of(_cache);

  /// Rebuilds whenever a record in this store is added, changed or removed.
  ValueListenable<EntityStore<T>> listenable() => _listenable;

  Future<void> put(String id, T value) => putAll({id: value});

  Future<void> putAll(Map<String, T> entries) async {
    if (entries.isEmpty) return;
    _owner._write(() {
      entries.forEach(_writeRow);
    });
    _cache.addAll(entries);
    _changed();
    await _owner._flush();
  }

  /// Stores each record under its own `id`.
  Future<void> addAll(Iterable<T> records) =>
      putAll({for (final record in records) _idOf(record): record});

  Future<void> delete(Object? id) async {
    if (id is! String || !_cache.containsKey(id)) return;
    _owner._write(() {
      _owner._statement('DELETE FROM $table WHERE id = ?').execute([id]);
    });
    _cache.remove(id);
    _changed();
    await _owner._flush();
  }

  /// Removes every record and returns how many there were.
  Future<int> clear() async {
    final count = _cache.length;
    _owner._write(() => _owner.db.execute('DELETE FROM $table'));
    _cache.clear();
    _changed();
    await _owner._flush();
    return count;
  }

  void _writeRow(String id, T value) {
    _owner._statement(_upsertSql).execute([id, ..._toRow(value)]);
  }

  @override
  void _load() {
    _cache.clear();
    for (final row in _owner.db.select('SELECT * FROM $table')) {
      _cache[row['id'] as String] = _fromRow(row);
    }
  }
}

/// A table of named values (settings, session). Values may be anything JSON
/// can hold, plus `DateTime` and `Uint8List`.
class KeyValueStore extends _Store {
  KeyValueStore._(super.owner, super.table);

  final SplayTreeMap<String, dynamic> _cache = SplayTreeMap<String, dynamic>();
  late final ValueListenable<KeyValueStore> _listenable =
      _StoreListenable<KeyValueStore>(this, _notifier);

  Iterable<String> get keys => _cache.keys;
  Iterable<dynamic> get values => _cache.values;
  int get length => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  bool containsKey(Object? key) => _cache.containsKey(key);
  Map<String, dynamic> toMap() => Map<String, dynamic>.of(_cache);

  dynamic get(Object? key, {dynamic defaultValue}) {
    if (key is String && _cache.containsKey(key)) return _cache[key];
    return defaultValue;
  }

  /// Rebuilds whenever any value in this store changes.
  ValueListenable<KeyValueStore> listenable() => _listenable;

  Future<void> put(String key, dynamic value) => putAll({key: value});

  Future<void> putAll(Map<String, dynamic> entries) async {
    if (entries.isEmpty) return;
    final encoded = entries.map((k, v) => MapEntry(k, encodeStoredValue(v)));
    _owner._write(() {
      final statement =
          _owner._statement('INSERT INTO $table (key, value) VALUES (?, ?) '
              'ON CONFLICT (key) DO UPDATE SET value = excluded.value');
      encoded.forEach((key, value) => statement.execute([key, value]));
    });
    // Keep what a later start would read back, e.g. maps with string keys.
    encoded.forEach((key, value) {
      final original = entries[key];
      _cache[key] = original == null ||
              original is num ||
              original is String ||
              original is bool
          ? original
          : decodeStoredValue(value);
    });
    _changed();
    await _owner._flush();
  }

  Future<void> delete(Object? key) async {
    if (key is! String || !_cache.containsKey(key)) return;
    _owner._write(() {
      _owner._statement('DELETE FROM $table WHERE key = ?').execute([key]);
    });
    _cache.remove(key);
    _changed();
    await _owner._flush();
  }

  Future<int> clear() async {
    final count = _cache.length;
    _owner._write(() => _owner.db.execute('DELETE FROM $table'));
    _cache.clear();
    _changed();
    await _owner._flush();
    return count;
  }

  @override
  void _load() {
    _cache.clear();
    for (final row in _owner.db.select('SELECT key, value FROM $table')) {
      _cache[row['key'] as String] = decodeStoredValue(row['value'] as String);
    }
  }
}

const String _typeTag = r'$type';

/// Encodes a setting value as JSON text, tagging the types JSON lacks.
///
/// The value is converted before `jsonEncode` sees it: `Uint8List` is a
/// `List<int>`, so `jsonEncode` would write it as a plain number array and
/// never offer it to a `toEncodable` hook.
String encodeStoredValue(dynamic value) => jsonEncode(_toJsonValue(value));

Object? _toJsonValue(Object? v) {
  if (v == null || v is String || v is bool) return v;
  if (v is num) {
    if (v is double && !v.isFinite) {
      return {_typeTag: 'double', 'value': v.toString()};
    }
    return v;
  }
  if (v is DateTime) {
    return {_typeTag: 'DateTime', 'ms': v.millisecondsSinceEpoch};
  }
  if (v is Uint8List) return {_typeTag: 'bytes', 'base64': base64Encode(v)};
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _toJsonValue(e.value)};
  }
  if (v is Iterable) return [for (final e in v) _toJsonValue(e)];
  throw ArgumentError('Cannot store a ${v.runtimeType} in the database');
}

dynamic decodeStoredValue(String text) => jsonDecode(text, reviver: (_, v) {
      if (v is Map && v.length <= 2 && v[_typeTag] is String) {
        switch (v[_typeTag]) {
          case 'DateTime':
            return DateTime.fromMillisecondsSinceEpoch(v['ms'] as int);
          case 'bytes':
            return base64Decode(v['base64'] as String);
          case 'double':
            return double.parse(v['value'] as String);
        }
      }
      return v;
    });
).hasMatch(shopId)) {
      throw ArgumentError.value(shopId, 'shopId', 'Invalid shop identifier');
    }
    final key = 'shop:$shopId';
    if (_instance != null && _activeDatabaseKey == key) return;
    _instance?.close();
    _instance = null;
    _activeDatabaseKey = key;
    try {
      _instance = AppDatabase(
        await openAppDatabase(databaseName: 'billit_shop_$shopId'),
      );
    } catch (_) {
      _activeDatabaseKey = 'local';
      rethrow;
    }
  }

  /// Returns to the pre-cloud local database without copying or deleting data.
  static Future<void> openLocalDatabase() async {
    if (_instance != null && _activeDatabaseKey == 'local') return;
    _instance?.close();
    _instance = null;
    _activeDatabaseKey = 'local';
    _instance = AppDatabase(await openAppDatabase());
  }

  static Future<List<SyncOutboxChange>> pendingSyncChanges({int limit = 100}) =>
      instance.pendingSyncChanges(limit: limit);

  static Future<void> acknowledgeSyncChange(int id) =>
      instance.acknowledgeSyncChange(id);

  static Future<void> recordSyncFailure(int id, String error) =>
      instance.recordSyncFailure(id, error);

  static Future<R> withoutOutbox<R>(Future<R> Function() action) =>
      instance.withoutOutbox(action);

  /// Uses an already opened connection, e.g. an in-memory database in tests.
  static void openWith(SqliteConnection connection) {
    _instance?.close();
    _instance = AppDatabase(connection);
  }

  static void close() {
    _instance?.close();
    _instance = null;
  }

  static EntityStore<User> get users => instance.users;
  static EntityStore<Product> get products => instance.products;
  static EntityStore<Sale> get sales => instance.sales;
  static EntityStore<Expense> get expenses => instance.expenses;
  static EntityStore<Employee> get employees => instance.employees;

  /// Business, invoice, GST, appearance and printer preferences.
  static KeyValueStore get settings => instance.settings;

  /// The signed-in user and backup bookkeeping.
  static KeyValueStore get session => instance.session;

  /// Per-device values: Drive auto-sync and the saved printer address.
  static KeyValueStore get deviceSettings => instance.deviceSettings;

  static KeyValueStore get meta => instance.meta;

  /// Runs [action] in one SQLite transaction. If it throws, every write made
  /// inside it is rolled back.
  static Future<R> transaction<R>(Future<R> Function() action) =>
      instance.transaction(action);
}

class AppDatabase {
  AppDatabase(this.connection) {
    migrateSchema(db);
    users = _UserStore(this);
    products = _ProductStore(this);
    sales = _SaleStore(this);
    expenses = _ExpenseStore(this);
    employees = _EmployeeStore(this);
    settings = KeyValueStore._(this, 'app_settings');
    session = KeyValueStore._(this, 'session');
    deviceSettings = KeyValueStore._(this, 'device_settings');
    meta = KeyValueStore._(this, 'meta');
    _stores = [
      users,
      products,
      sales,
      expenses,
      employees,
      settings,
      session,
      deviceSettings,
      meta,
    ];
    for (final store in _stores) {
      store._load();
    }
  }

  final SqliteConnection connection;
  CommonDatabase get db => connection.db;

  late final EntityStore<User> users;
  late final EntityStore<Product> products;
  late final EntityStore<Sale> sales;
  late final EntityStore<Expense> expenses;
  late final EntityStore<Employee> employees;
  late final KeyValueStore settings;
  late final KeyValueStore session;
  late final KeyValueStore deviceSettings;
  late final KeyValueStore meta;

  late final List<_Store> _stores;
  final Map<String, CommonPreparedStatement> _statements = {};
  bool _inTransaction = false;

  CommonPreparedStatement _statement(String sql) =>
      _statements[sql] ??= db.prepare(sql, persistent: true);

  /// Runs [body] atomically: in the surrounding transaction if there is one,
  /// otherwise in its own.
  void _write(void Function() body) {
    if (_inTransaction) {
      body();
      return;
    }
    db.execute('BEGIN');
    try {
      body();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> _flush() async {
    if (!_inTransaction) await connection.flush();
  }

  Future<R> transaction<R>(Future<R> Function() action) async {
    if (_inTransaction) return action();
    db.execute('BEGIN');
    _inTransaction = true;
    try {
      final result = await action();
      db.execute('COMMIT');
      _inTransaction = false;
      await connection.flush();
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      _inTransaction = false;
      // The in-memory copies saw the rolled-back writes; re-read the tables.
      for (final store in _stores) {
        store._load();
        store._changed();
      }
      rethrow;
    }
  }

  void close() {
    for (final statement in _statements.values) {
      statement.close();
    }
    _statements.clear();
    connection.close();
  }
}

abstract class _Store {
  _Store(this._owner, this.table);

  final AppDatabase _owner;
  final String table;
  final _StoreNotifier _notifier = _StoreNotifier();
  bool _notifyScheduled = false;

  void _load();

  /// Listeners are told on the next microtask, so a write made while widgets
  /// are building never calls setState during that build.
  void _changed() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      _notifier.notify();
    });
  }
}

class _StoreNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _StoreListenable<S> implements ValueListenable<S> {
  _StoreListenable(this.value, this._notifier);

  @override
  final S value;
  final _StoreNotifier _notifier;

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);
}

/// One table of records keyed by their `id`. Iteration is in `id` order.
abstract class EntityStore<T> extends _Store {
  EntityStore._(super.owner, super.table, this._columns);

  /// Column names after `id`, in the order [_toRow] returns their values.
  final List<String> _columns;
  final SplayTreeMap<String, T> _cache = SplayTreeMap<String, T>();
  late final ValueListenable<EntityStore<T>> _listenable =
      _StoreListenable<EntityStore<T>>(this, _notifier);

  String _idOf(T value);
  List<Object?> _toRow(T value);
  T _fromRow(Row row);

  late final String _upsertSql = 'INSERT INTO $table '
      '(id, ${_columns.join(', ')}) '
      'VALUES (?${', ?' * _columns.length}) '
      'ON CONFLICT (id) DO UPDATE SET '
      '${_columns.map((c) => '$c = excluded.$c').join(', ')}';

  Iterable<T> get values => _cache.values;
  Iterable<String> get keys => _cache.keys;
  int get length => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  bool containsKey(Object? id) => _cache.containsKey(id);
  T? get(Object? id) => id is String ? _cache[id] : null;
  Map<String, T> toMap() => Map<String, T>.of(_cache);

  /// Rebuilds whenever a record in this store is added, changed or removed.
  ValueListenable<EntityStore<T>> listenable() => _listenable;

  Future<void> put(String id, T value) => putAll({id: value});

  Future<void> putAll(Map<String, T> entries) async {
    if (entries.isEmpty) return;
    _owner._write(() {
      entries.forEach(_writeRow);
    });
    _cache.addAll(entries);
    _changed();
    await _owner._flush();
  }

  /// Stores each record under its own `id`.
  Future<void> addAll(Iterable<T> records) =>
      putAll({for (final record in records) _idOf(record): record});

  Future<void> delete(Object? id) async {
    if (id is! String || !_cache.containsKey(id)) return;
    _owner._write(() {
      _owner._statement('DELETE FROM $table WHERE id = ?').execute([id]);
    });
    _cache.remove(id);
    _changed();
    await _owner._flush();
  }

  /// Removes every record and returns how many there were.
  Future<int> clear() async {
    final count = _cache.length;
    _owner._write(() => _owner.db.execute('DELETE FROM $table'));
    _cache.clear();
    _changed();
    await _owner._flush();
    return count;
  }

  void _writeRow(String id, T value) {
    _owner._statement(_upsertSql).execute([id, ..._toRow(value)]);
  }

  @override
  void _load() {
    _cache.clear();
    for (final row in _owner.db.select('SELECT * FROM $table')) {
      _cache[row['id'] as String] = _fromRow(row);
    }
  }
}

/// A table of named values (settings, session). Values may be anything JSON
/// can hold, plus `DateTime` and `Uint8List`.
class KeyValueStore extends _Store {
  KeyValueStore._(super.owner, super.table);

  final SplayTreeMap<String, dynamic> _cache = SplayTreeMap<String, dynamic>();
  late final ValueListenable<KeyValueStore> _listenable =
      _StoreListenable<KeyValueStore>(this, _notifier);

  Iterable<String> get keys => _cache.keys;
  Iterable<dynamic> get values => _cache.values;
  int get length => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  bool containsKey(Object? key) => _cache.containsKey(key);
  Map<String, dynamic> toMap() => Map<String, dynamic>.of(_cache);

  dynamic get(Object? key, {dynamic defaultValue}) {
    if (key is String && _cache.containsKey(key)) return _cache[key];
    return defaultValue;
  }

  /// Rebuilds whenever any value in this store changes.
  ValueListenable<KeyValueStore> listenable() => _listenable;

  Future<void> put(String key, dynamic value) => putAll({key: value});

  Future<void> putAll(Map<String, dynamic> entries) async {
    if (entries.isEmpty) return;
    final encoded = entries.map((k, v) => MapEntry(k, encodeStoredValue(v)));
    _owner._write(() {
      final statement =
          _owner._statement('INSERT INTO $table (key, value) VALUES (?, ?) '
              'ON CONFLICT (key) DO UPDATE SET value = excluded.value');
      encoded.forEach((key, value) => statement.execute([key, value]));
    });
    // Keep what a later start would read back, e.g. maps with string keys.
    encoded.forEach((key, value) {
      final original = entries[key];
      _cache[key] = original == null ||
              original is num ||
              original is String ||
              original is bool
          ? original
          : decodeStoredValue(value);
    });
    _changed();
    await _owner._flush();
  }

  Future<void> delete(Object? key) async {
    if (key is! String || !_cache.containsKey(key)) return;
    _owner._write(() {
      _owner._statement('DELETE FROM $table WHERE key = ?').execute([key]);
    });
    _cache.remove(key);
    _changed();
    await _owner._flush();
  }

  Future<int> clear() async {
    final count = _cache.length;
    _owner._write(() => _owner.db.execute('DELETE FROM $table'));
    _cache.clear();
    _changed();
    await _owner._flush();
    return count;
  }

  @override
  void _load() {
    _cache.clear();
    for (final row in _owner.db.select('SELECT key, value FROM $table')) {
      _cache[row['key'] as String] = decodeStoredValue(row['value'] as String);
    }
  }
}

const String _typeTag = r'$type';

/// Encodes a setting value as JSON text, tagging the types JSON lacks.
///
/// The value is converted before `jsonEncode` sees it: `Uint8List` is a
/// `List<int>`, so `jsonEncode` would write it as a plain number array and
/// never offer it to a `toEncodable` hook.
String encodeStoredValue(dynamic value) => jsonEncode(_toJsonValue(value));

Object? _toJsonValue(Object? v) {
  if (v == null || v is String || v is bool) return v;
  if (v is num) {
    if (v is double && !v.isFinite) {
      return {_typeTag: 'double', 'value': v.toString()};
    }
    return v;
  }
  if (v is DateTime) {
    return {_typeTag: 'DateTime', 'ms': v.millisecondsSinceEpoch};
  }
  if (v is Uint8List) return {_typeTag: 'bytes', 'base64': base64Encode(v)};
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _toJsonValue(e.value)};
  }
  if (v is Iterable) return [for (final e in v) _toJsonValue(e)];
  throw ArgumentError('Cannot store a ${v.runtimeType} in the database');
}

dynamic decodeStoredValue(String text) => jsonDecode(text, reviver: (_, v) {
      if (v is Map && v.length <= 2 && v[_typeTag] is String) {
        switch (v[_typeTag]) {
          case 'DateTime':
            return DateTime.fromMillisecondsSinceEpoch(v['ms'] as int);
          case 'bytes':
            return base64Decode(v['base64'] as String);
          case 'double':
            return double.parse(v['value'] as String);
        }
      }
      return v;
    });
