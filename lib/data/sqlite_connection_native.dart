import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'sqlite_connection.dart';

const String databaseFileName = 'billit.db';

Future<SqliteConnection> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  await Directory(dir.path).create(recursive: true);
  final db = sqlite3.open(p.join(dir.path, databaseFileName));
  db.execute('PRAGMA journal_mode = WAL');
  return SqliteConnection(db);
}
