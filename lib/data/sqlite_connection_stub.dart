import 'sqlite_connection.dart';

const String databaseFileName = 'billit.db';

Future<SqliteConnection> openAppDatabase() =>
    throw UnsupportedError('SQLite is not available on this platform');
