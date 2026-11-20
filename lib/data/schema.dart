import 'package:sqlite3/common.dart';

const int schemaVersion = 2;

/// Key/value tables. Values are stored as JSON text.
const List<String> keyValueTables = [
  'app_settings',
  'session',
  'device_settings',
  'meta',
];

final List<String> _schemaV1 = [
  '''
  CREATE TABLE users (
    id TEXT NOT NULL PRIMARY KEY,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    user_type TEXT NOT NULL,
    security_answer TEXT NOT NULL,
    security_question TEXT NOT NULL
  )''',
  '''
  CREATE TABLE products (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    selling_price REAL,
    cost_price REAL,
    stock REAL,
    unit TEXT NOT NULL,
    category TEXT NOT NULL,
    sub_category TEXT NOT NULL,
    active INTEGER NOT NULL,
    barcode TEXT,
    hsn_code TEXT NOT NULL,
    gst_rate REAL
  )''',
  'CREATE INDEX products_barcode ON products (barcode)',
  '''
  CREATE TABLE sales (
    id TEXT NOT NULL PRIMARY KEY,
    date INTEGER NOT NULL,
    total_amount REAL,
    total_cost REAL,
    profit REAL,
    payment TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    user_id TEXT NOT NULL,
    discount REAL,
    gst_enabled INTEGER NOT NULL,
    gst_rate REAL,
    taxable_amount REAL,
    cgst_amount REAL,
    sgst_amount REAL,
    igst_amount REAL,
    customer_gstin TEXT NOT NULL,
    interstate_sale INTEGER NOT NULL,
    gst_inclusive INTEGER NOT NULL
  )''',
  'CREATE INDEX sales_date ON sales (date)',
  '''
  CREATE TABLE sale_items (
    sale_id TEXT NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    product_id TEXT NOT NULL,
    qty REAL,
    selling_price REAL,
    cost_price REAL,
    subtotal REAL,
    unit_label TEXT NOT NULL,
    hsn_code TEXT NOT NULL,
    gst_rate REAL,
    taxable_amount REAL,
    cgst_amount REAL,
    sgst_amount REAL,
    igst_amount REAL,
    PRIMARY KEY (sale_id, position)
  )''',
  'CREATE INDEX sale_items_product ON sale_items (product_id)',
  '''
  CREATE TABLE expenses (
    id TEXT NOT NULL PRIMARY KEY,
    date INTEGER NOT NULL,
    category TEXT NOT NULL,
    amount REAL,
    description TEXT NOT NULL
  )''',
  'CREATE INDEX expenses_date ON expenses (date)',
  '''
  CREATE TABLE employees (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    wage REAL,
    attendance INTEGER NOT NULL,
    salary_paid INTEGER NOT NULL
  )''',
  for (final table in keyValueTables)
    'CREATE TABLE $table (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
];


final List<String> _schemaV2 = [
  '''CREATE TABLE local_sync_control (
    id INTEGER NOT NULL PRIMARY KEY CHECK (id = 1),
    suppress_outbox INTEGER NOT NULL DEFAULT 0 CHECK (suppress_outbox IN (0, 1))
  )''',
  'INSERT INTO local_sync_control (id, suppress_outbox) VALUES (1, 0)',
  '''CREATE TABLE local_sync_outbox (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL CHECK (table_name IN ('products', 'sales', 'expenses', 'employees')),
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('UPSERT', 'DELETE')),
    changed_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    revision INTEGER NOT NULL DEFAULT 1,
    last_error TEXT,
    UNIQUE (table_name, record_id)
  )''',
  'CREATE INDEX local_sync_outbox_order ON local_sync_outbox (id)',
  for (final table in ['products', 'sales', 'expenses', 'employees']) ...[
    '''CREATE TRIGGER sync_${table}_insert AFTER INSERT ON $table
    WHEN (SELECT suppress_outbox FROM local_sync_control WHERE id = 1) = 0
    BEGIN
      INSERT INTO local_sync_outbox (table_name, record_id, operation, changed_at)
      VALUES ('$table', NEW.id, 'UPSERT', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))
      ON CONFLICT (table_name, record_id) DO UPDATE SET
        operation = 'UPSERT', changed_at = excluded.changed_at, attempts = 0, revision = local_sync_outbox.revision + 1, last_error = NULL;
    END''',
    '''CREATE TRIGGER sync_${table}_update AFTER UPDATE ON $table
    WHEN (SELECT suppress_outbox FROM local_sync_control WHERE id = 1) = 0
    BEGIN
      INSERT INTO local_sync_outbox (table_name, record_id, operation, changed_at)
      VALUES ('$table', NEW.id, 'UPSERT', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))
      ON CONFLICT (table_name, record_id) DO UPDATE SET
        operation = 'UPSERT', changed_at = excluded.changed_at, attempts = 0, revision = local_sync_outbox.revision + 1, last_error = NULL;
    END''',
    '''CREATE TRIGGER sync_${table}_delete AFTER DELETE ON $table
    WHEN (SELECT suppress_outbox FROM local_sync_control WHERE id = 1) = 0
    BEGIN
      INSERT INTO local_sync_outbox (table_name, record_id, operation, changed_at)
      VALUES ('$table', OLD.id, 'DELETE', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))
      ON CONFLICT (table_name, record_id) DO UPDATE SET
        operation = 'DELETE', changed_at = excluded.changed_at, attempts = 0, revision = local_sync_outbox.revision + 1, last_error = NULL;
    END''',
  ],
];

/// Creates or upgrades the schema. `PRAGMA user_version` tracks the version.
void migrateSchema(CommonDatabase db) {
  db.execute('PRAGMA foreign_keys = ON');
  final current = db.select('PRAGMA user_version').first.values.first as int;
  if (current >= schemaVersion) return;
  db.execute('BEGIN');
  try {
    if (current < 1) {
      for (final statement in _schemaV1) {
        db.execute(statement);
      }
    }
    if (current < 2) {
      for (final statement in _schemaV2) {
        db.execute(statement);
      }
    }
    db.execute('PRAGMA user_version = $schemaVersion');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
