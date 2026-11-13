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

  static AppDatabase get instance =>
      _instance ?? (throw StateError('Db.open() has not been called'));

  static bool get isOpen => _instance != null;

  /// Opens the on-device database file (IndexedDB-backed on the web).
  static Future<void> open() async {
    if (_instance != null) return;
    _instance = AppDatabase(await openAppDatabase());
  }

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
