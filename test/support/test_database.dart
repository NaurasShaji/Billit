import 'package:billit/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens the SQLite file at [path] as the app database, closing any database
/// that is already open. Calling it again with the same path models an app
/// restart.
void openDatabaseFile(String path) {
  Db.openWith(SqliteConnection(sqlite3.open(path)));
}

/// Opens an empty in-memory database as the app database.
void openInMemoryDatabase() {
  Db.openWith(SqliteConnection(sqlite3.openInMemory()));
}
