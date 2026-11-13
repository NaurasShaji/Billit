import 'package:billit/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

void openDatabaseFile(String path) {
  Db.openWith(SqliteConnection(sqlite3.open(path)));
}

void openInMemoryDatabase() {
  Db.openWith(SqliteConnection(sqlite3.openInMemory()));
}
