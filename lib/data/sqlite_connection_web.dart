import 'package:sqlite3/wasm.dart';

import 'sqlite_connection.dart';

const String databaseFileName = 'billit.db';

/// Loads `web/sqlite3.wasm` and keeps the database file in IndexedDB.
Future<SqliteConnection> openAppDatabase({String? databaseName}) async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final safeName = (databaseName ?? 'billit')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final fileSystem = await IndexedDbFileSystem.open(dbName: '${safeName}_sqlite');
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  final db = sqlite.open('/$safeName.db');
  return SqliteConnection(db, flush: fileSystem.flush);
}
