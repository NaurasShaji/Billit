import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'database.dart';

/// `meta` key recording that the Hive boxes were looked at, so the import
/// runs once.
const String legacyImportKey = 'legacy_hive_import';

const List<String> _entityBoxes = [
  'users',
  'products',
  'sales',
  'expenses',
  'employees',
];

/// Copies data written by app versions that stored it in Hive into SQLite.
///
/// Runs once, on the first start after the upgrade, before anything else is
/// written. The Hive files are left untouched. Returns the number of records
/// and settings copied. Throws, leaving SQLite unchanged, if a box cannot be
/// read; the next start then tries again.
///
/// [directory] is where the `.hive` files are; it defaults to the documents
/// directory the old versions used and is ignored on the web.
Future<int> importLegacyHiveData({String? directory}) {
  // Hive reports a box that fails to open twice: through the future its caller
  // awaits and again as an unhandled async error. The zone swallows the
  // duplicate so the one failure that matters reaches the caller exactly once.
  final result = Completer<int>();
  runZonedGuarded(() async {
    try {
      result.complete(await _importLegacyHiveData(directory));
    } catch (error, stack) {
      result.completeError(error, stack);
    }
  }, (error, stack) => debugPrint('Ignored duplicate Hive error: $error'));
  return result.future;
}

Future<int> _importLegacyHiveData(String? directory) async {
  if (Db.meta.containsKey(legacyImportKey)) return 0;

  if (!kIsWeb) {
    Hive.init(directory ?? (await getApplicationDocumentsDirectory()).path);
  }
  _registerAdapters();

  var copied = 0;
  try {
    final found = <String>[
      for (final name in [
        ..._entityBoxes,
        'app_settings',
        'session',
        'settings'
      ])
        if (await Hive.boxExists(name)) name,
    ];
    final boxes = {
      for (final name in found) name: await Hive.openBox<dynamic>(name),
    };

    await Db.transaction(() async {
      copied += await _copyRecords<User>(boxes['users'], Db.users, (u) => u.id);
      copied += await _copyRecords<Product>(
          boxes['products'], Db.products, (p) => p.id);
      copied += await _copyRecords<Sale>(boxes['sales'], Db.sales, (s) => s.id);
      copied += await _copyRecords<Expense>(
          boxes['expenses'], Db.expenses, (e) => e.id);
      copied += await _copyRecords<Employee>(
          boxes['employees'], Db.employees, (e) => e.id);
      copied += await _copyValues(boxes['app_settings'], Db.settings);
      copied += await _copyValues(boxes['session'], Db.session);
      copied += await _copyValues(boxes['settings'], Db.deviceSettings);
      await Db.meta.put(legacyImportKey, {
        'at': DateTime.now(),
        'boxes': found,
        'copied': copied,
      });
    });
  } finally {
    await Hive.close();
  }
  return copied;
}

/// Records are stored under their own `id`: boxes refilled by an old restore
/// used auto-increment keys, which broke lookups by id.
Future<int> _copyRecords<T>(
  Box<dynamic>? box,
  EntityStore<T> store,
  String Function(T) idOf,
) async {
  if (box == null) return 0;
  final records = {
    for (final value in box.values.whereType<T>()) idOf(value): value
  };
  await store.putAll(records);
  return records.length;
}

Future<int> _copyValues(Box<dynamic>? box, KeyValueStore store) async {
  if (box == null) return 0;
  final values = {for (final key in box.keys) key.toString(): box.get(key)};
  await store.putAll(values);
  return values.length;
}

void _registerAdapters() {
  void register<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  register(_EnumAdapter<UserType>(1, UserType.values));
  register(_UserAdapter());
  register(_EnumAdapter<UnitType>(3, UnitType.values));
  register(_ProductAdapter());
  register(_EnumAdapter<PaymentMethod>(5, PaymentMethod.values));
  register(_SaleItemAdapter());
  register(_SaleAdapter());
  register(_ExpenseAdapter());
  register(_EmployeeAdapter());
}

/// Registers the legacy adapters so tests can write boxes in the old layout
/// (see `test/support/generate_legacy_hive_fixtures.dart`).
@visibleForTesting
void registerLegacyHiveAdapters() => _registerAdapters();

// The adapters below read (and, for tests, write) the exact binary layout of
// the generated Hive adapters the app used to ship. Type ids and field
// numbers must never change.

Map<int, dynamic> _readFields(BinaryReader reader) {
  final count = reader.readByte();
  return {for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
}

void _writeFields(BinaryWriter writer, List<dynamic> fields) {
  writer.writeByte(fields.length);
  for (var i = 0; i < fields.length; i++) {
    writer
      ..writeByte(i)
      ..write(fields[i]);
  }
}

double _double(dynamic value, [double fallback = 0.0]) =>
    (value as num?)?.toDouble() ?? fallback;

class _EnumAdapter<E extends Enum> extends TypeAdapter<E> {
  _EnumAdapter(this.typeId, this.values);

  @override
  final int typeId;
  final List<E> values;

  @override
  E read(BinaryReader reader) {
    final index = reader.readByte();
    return index < values.length ? values[index] : values.first;
  }

  @override
  void write(BinaryWriter writer, E obj) => writer.writeByte(obj.index);
}

class _UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 2;

  @override
  User read(BinaryReader reader) {
    final f = _readFields(reader);
    return User()
      ..id = f[0] as String
      ..username = f[1] as String
      ..password = f[2] as String
      ..userType = f[3] as UserType
      ..securityAnswer = f[4] as String? ?? 'Buddy'
      ..securityQuestion =
          f[5] as String? ?? 'What is the name of your favourite pet?';
  }

  @override
  void write(BinaryWriter writer, User u) => _writeFields(writer, [
        u.id,
        u.username,
        u.password,
        u.userType,
        u.securityAnswer,
        u.securityQuestion,
      ]);
}

class _ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 4;

  @override
  Product read(BinaryReader reader) {
    final f = _readFields(reader);
    return Product()
      ..id = f[0] as String
      ..name = f[1] as String
      ..sellingPrice = _double(f[2])
      ..costPrice = _double(f[3])
      ..stock = _double(f[4])
      ..unit = f[5] as UnitType
      ..category = f[6] as String
      ..subCategory = f[7] as String
      ..active = f[8] as bool? ?? true
      ..barcode = f[9] as String?
      ..hsnCode = f[10] as String? ?? ''
      ..gstRate = (f[11] as num?)?.toDouble();
  }

  @override
  void write(BinaryWriter writer, Product p) => _writeFields(writer, [
        p.id,
        p.name,
        p.sellingPrice,
        p.costPrice,
        p.stock,
        p.unit,
        p.category,
        p.subCategory,
        p.active,
        p.barcode,
        p.hsnCode,
        p.gstRate,
      ]);
}

class _SaleItemAdapter extends TypeAdapter<SaleItem> {
  @override
  final int typeId = 6;

  @override
  SaleItem read(BinaryReader reader) {
    final f = _readFields(reader);
    return SaleItem()
      ..productId = f[0] as String
      ..qty = _double(f[1])
      ..sellingPrice = _double(f[2])
      ..costPrice = _double(f[3])
      ..subtotal = _double(f[4])
      ..unitLabel = f[5] as String
      ..hsnCode = f[6] as String? ?? ''
      ..gstRate = _double(f[7])
      ..taxableAmount = _double(f[8])
      ..cgstAmount = _double(f[9])
      ..sgstAmount = _double(f[10])
      ..igstAmount = _double(f[11]);
  }

  @override
  void write(BinaryWriter writer, SaleItem i) => _writeFields(writer, [
        i.productId,
        i.qty,
        i.sellingPrice,
        i.costPrice,
        i.subtotal,
        i.unitLabel,
        i.hsnCode,
        i.gstRate,
        i.taxableAmount,
        i.cgstAmount,
        i.sgstAmount,
        i.igstAmount,
      ]);
}

class _SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 7;

  @override
  Sale read(BinaryReader reader) {
    final f = _readFields(reader);
    return Sale()
      ..id = f[0] as String
      ..date = f[1] as DateTime
      ..items = (f[2] as List).cast<SaleItem>().toList()
      ..totalAmount = _double(f[3])
      ..totalCost = _double(f[4])
      ..profit = _double(f[5])
      ..payment = f[6] as PaymentMethod
      ..customerName = f[7] as String
      ..customerPhone = f[8] as String
      ..userId = f[9] as String
      ..discount = _double(f[10])
      ..gstEnabled = f[11] as bool? ?? false
      ..gstRate = _double(f[12])
      ..taxableAmount = _double(f[13])
      ..cgstAmount = _double(f[14])
      ..sgstAmount = _double(f[15])
      ..igstAmount = _double(f[16])
      ..customerGstin = f[17] as String? ?? ''
      ..interstateSale = f[18] as bool? ?? false
      ..gstInclusive = f[19] as bool? ?? false;
  }

  @override
  void write(BinaryWriter writer, Sale s) => _writeFields(writer, [
        s.id,
        s.date,
        s.items,
        s.totalAmount,
        s.totalCost,
        s.profit,
        s.payment,
        s.customerName,
        s.customerPhone,
        s.userId,
        s.discount,
        s.gstEnabled,
        s.gstRate,
        s.taxableAmount,
        s.cgstAmount,
        s.sgstAmount,
        s.igstAmount,
        s.customerGstin,
        s.interstateSale,
        s.gstInclusive,
      ]);
}

class _ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 8;

  @override
  Expense read(BinaryReader reader) {
    final f = _readFields(reader);
    return Expense(
      id: f[0] as String,
      date: f[1] as DateTime,
      category: f[2] as String,
      amount: _double(f[3]),
      description: f[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Expense e) =>
      _writeFields(writer, [e.id, e.date, e.category, e.amount, e.description]);
}

class _EmployeeAdapter extends TypeAdapter<Employee> {
  @override
  final int typeId = 9;

  @override
  Employee read(BinaryReader reader) {
    final f = _readFields(reader);
    return Employee(
      id: f[0] as String,
      name: f[1] as String,
      type: f[2] as String,
      wage: _double(f[3]),
      attendance: (f[4] as num?)?.toInt() ?? 0,
      salaryPaid: f[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Employee e) => _writeFields(
      writer, [e.id, e.name, e.type, e.wage, e.attendance, e.salaryPaid]);
}
