import 'package:sqlite3/common.dart';

export 'sqlite_connection_stub.dart'
    if (dart.library.io) 'sqlite_connection_native.dart'
    if (dart.library.js_interop) 'sqlite_connection_web.dart';

/// An open SQLite database plus the platform hook that makes writes durable.
class SqliteConnection {
  SqliteConnection(this.db, {Future<void> Function()? flush}) : _flush = flush;

  final CommonDatabase db;
  final Future<void> Function()? _flush;

  /// Completes once pending writes have reached persistent storage. Only the
  /// web file system needs this; native SQLite writes are already on disk.
  Future<void> flush() async => _flush?.call();

  void close() => db.close();
}
