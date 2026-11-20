import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'sqlite_connection.dart';

const String databaseFileName = 'billit.db';

Future<SqliteConnection> openAppDatabase({String? databaseName}) async {
  final dir = await getApplicationSupportDirectory();
  await Directory(dir.path).create(recursive: true);
  final safeName = (databaseName ?? 'billit')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final db = sqlite3.open(p.join(dir.path, '$safeName.db'));
  db.execute('PRAGMA journal_mode = WAL');
  return SqliteConnection(db);
}
