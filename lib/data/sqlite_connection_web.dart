import 'package:sqlite3/wasm.dart';

import 'sqlite_connection.dart';

const String databaseFileName = 'billit.db';

/// Loads web/sqlite3.wasm and keeps the database file in IndexedDB.
Future<SqliteConnection> openAppDatabase() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: 'billit_sqlite');
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  final db = sqlite.open('/$databaseFileName');
  return SqliteConnection(db, flush: fileSystem.flush);
}
