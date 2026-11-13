import 'dart:io';
import 'dart:typed_data';

import 'package:billit/data/database.dart';
import 'package:billit/data/legacy_hive_import.dart';
import 'package:billit/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_database.dart';

/// `test/fixtures/legacy_hive` holds boxes written by the last Hive version of
/// the app, using its generated adapters.
void main() {
  late Directory hiveDir;

  setUp(() {
    hiveDir = Directory.systemTemp.createTempSync('billit_legacy_hive');
    openInMemoryDatabase();
  });

  tearDown(() {
    Db.close();
    hiveDir.deleteSync(recursive: true);
  });

  void copyFixtures({Set<String>? only}) {
    for (final file in Directory('test/fixtures/legacy_hive')
        .listSync()
        .whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (only != null && !only.contains(name)) continue;
      file.copySync('${hiveDir.path}/$name');
    }
  }

  test('copies every box written by the Hive version of the app', () async {
    copyFixtures();

    final copied = await importLegacyHiveData(directory: hiveDir.path);

    expect(Db.users.keys, ['u-admin', 'u-worker']);
    final admin = Db.users.get('u-admin')!;
    expect(admin.username, 'owner');
    expect(admin.password, User.hash('s3cret'));
    expect(admin.userType, UserType.admin);
    expect(admin.securityAnswer, 'Rex');
    expect(admin.securityQuestion, 'First pet?');
    final worker = Db.users.get('u-worker')!;
    expect(worker.userType, UserType.worker);
    expect(worker.securityAnswer, 'Buddy');

    expect(Db.products.keys, ['p-rose', 'p-soil', 'p-turf']);
    expect(Db.products.get('p-rose')!.toJson(), {
      'id': 'p-rose',
      'name': 'Rose bunch',
      'sellingPrice': 120.5,
      'costPrice': 80.0,
      'stock': 14.0,
      'unit': 'pcs',
      'category': 'Flowers',
      'subCategory': 'Cut',
      'active': true,
      'barcode': '8901234567890',
      'hsnCode': '0603',
      'gstRate': 5.0,
    });
    final turf = Db.products.get('p-turf')!;
    expect(turf.unit, UnitType.sqft);
    expect(turf.stock, 250.75);
    expect(turf.active, isFalse);
    expect(turf.barcode, isNull);
    expect(turf.gstRate, isNull);
    // Stored under an integer key by the old Drive restore.
    final soil = Db.products.get('p-soil')!;
    expect(soil.name, 'Potting soil');
    expect(soil.unit, UnitType.kg);
    expect(soil.stock, 3.5);

    expect(Db.sales.keys, ['INV-0001', 'INV-0002']);
    final sale = Db.sales.get('INV-0001')!;
    expect(sale.date, DateTime(2025, 3, 14, 10, 30, 15, 250));
    expect(sale.totalAmount, 796.63);
    expect(sale.totalCost, 536.25);
    expect(sale.profit, 260.38);
    expect(sale.payment, PaymentMethod.upi);
    expect(sale.customerName, 'Asha');
    expect(sale.customerPhone, '9876543210');
    expect(sale.userId, 'u-worker');
    expect(sale.discount, 10);
    expect(sale.gstEnabled, isTrue);
    expect(sale.gstRate, 5);
    expect(sale.taxableAmount, 229.52);
    expect(sale.cgstAmount, 5.74);
    expect(sale.sgstAmount, 5.74);
    expect(sale.igstAmount, 0);
    expect(sale.customerGstin, '32ABCDE1234F1Z5');
    expect(sale.interstateSale, isFalse);
    expect(sale.gstInclusive, isTrue);
    expect(sale.items, hasLength(2));
    expect(sale.items[0].toJson(), {
      'productId': 'p-rose',
      'qty': 2.0,
      'sellingPrice': 120.5,
      'costPrice': 80.0,
      'subtotal': 241.0,
      'unitLabel': 'pcs',
      'hsnCode': '0603',
      'gstRate': 5.0,
      'taxableAmount': 229.52,
      'cgstAmount': 5.74,
      'sgstAmount': 5.74,
      'igstAmount': 0.0,
    });
    expect(sale.items[1].productId, 'p-turf');
    expect(sale.items[1].qty, 12.5);
    expect(sale.items[1].unitLabel, 'sqft');
    expect(sale.items[1].productName, 'Turf');
    final second = Db.sales.get('INV-0002')!;
    expect(second.items, isEmpty);
    expect(second.payment, PaymentMethod.card);
    expect(second.interstateSale, isTrue);
    expect(second.igstAmount, 2.86);

    expect(Db.expenses.get('e-1')!.toJson(), {
      'id': 'e-1',
      'date': DateTime(2025, 3, 1).toIso8601String(),
      'category': 'Rent',
      'amount': 15000.0,
      'description': 'March rent',
    });

    expect(Db.employees.get('m-1')!.toJson(), {
      'id': 'm-1',
      'name': 'Ravi',
      'type': 'daily',
      'wage': 750.5,
      'attendance': 22,
      'salaryPaid': false,
    });
    expect(Db.employees.get('m-2')!.salaryPaid, isTrue);

    expect(Db.session.get('user_id'), 'u-admin');
    expect(Db.session.get('last_backup_at'), DateTime(2025, 3, 10, 9));

    final settings = Db.settings;
    expect(settings.get('app_name'), 'Asha Flowers');
    expect(settings.get('business_name'), 'Asha Flowers & Garden');
    expect(settings.get('gst_enabled'), true);
    expect(settings.get('gst_rate'), isA<double>());
    expect(settings.get('gst_rate'), 5.0);
    expect(settings.get('corner_radius'), 16.0);
    expect(settings.get('low_stock_threshold'), isA<int>());
    expect(settings.get('next_invoice_number'), 3);
    expect(settings.get('invoice_templates'), {
      '80mm': {
        'columns': ['name', 'qty', 'total'],
        'fontSize': 9.5,
        'showLogo': true,
      },
    });
    expect(settings.get('stock_history'), [
      {'productId': 'p-rose', 'delta': -2.0, 'at': '2025-03-14T10:30:15.250'},
    ]);
    expect(settings.get('logo_bytes'), isA<Uint8List>());
    expect(settings.get('logo_bytes'), [0, 1, 2, 250, 255]);
    expect(settings.length, 11);

    expect(Db.deviceSettings.get('drive_auto_sync'), false);
    expect(Db.deviceSettings.get('printer_mac_address'), '00:11:22:33:44:55');

    // 2 users + 3 products + 2 sales + 1 expense + 2 employees
    // + 11 settings + 2 session values + 2 device settings.
    expect(copied, 25);
    expect(Db.meta.get(legacyImportKey)['copied'], 25);
  });

  test('runs once: later starts do not copy the old data again', () async {
    copyFixtures();
    await importLegacyHiveData(directory: hiveDir.path);

    await Db.products.delete('p-rose');
    await Db.settings.put('next_invoice_number', 42);

    expect(await importLegacyHiveData(directory: hiveDir.path), 0);
    expect(Db.products.containsKey('p-rose'), isFalse);
    expect(Db.settings.get('next_invoice_number'), 42);
  });

  test('leaves the Hive files as they were', () async {
    copyFixtures();
    Map<String, List<int>> contents() => {
          for (final f in hiveDir.listSync().whereType<File>())
            if (f.path.endsWith('.hive')) f.path: f.readAsBytesSync(),
        };
    final before = contents();

    await importLegacyHiveData(directory: hiveDir.path);

    expect(contents(), before);
  });

  test('a fresh install has nothing to copy and creates no Hive files',
      () async {
    expect(await importLegacyHiveData(directory: hiveDir.path), 0);

    expect(Db.meta.containsKey(legacyImportKey), isTrue);
    expect(Db.users.isEmpty, isTrue);
    expect(hiveDir.listSync(), isEmpty);
  });

  test('copies the boxes that exist when others are missing', () async {
    copyFixtures(only: {'products.hive', 'app_settings.hive'});

    await importLegacyHiveData(directory: hiveDir.path);

    expect(Db.products.length, 3);
    expect(Db.settings.get('app_name'), 'Asha Flowers');
    expect(Db.sales.isEmpty, isTrue);
    expect(Db.users.isEmpty, isTrue);
  });

  test('an unreadable box changes nothing, and the next start tries again',
      () async {
    copyFixtures();
    final good = File('${hiveDir.path}/sales.hive').readAsBytesSync();
    // A frame whose type id no adapter knows: Hive cannot decode the value.
    File('${hiveDir.path}/sales.hive')
        .writeAsBytesSync(_frameWithUnknownType());

    await expectLater(
        importLegacyHiveData(directory: hiveDir.path), throwsA(anything));

    expect(Db.meta.containsKey(legacyImportKey), isFalse);
    expect(Db.users.isEmpty, isTrue);
    expect(Db.products.isEmpty, isTrue);
    expect(Db.settings.isEmpty, isTrue);

    File('${hiveDir.path}/sales.hive').writeAsBytesSync(good);
    expect(await importLegacyHiveData(directory: hiveDir.path), 25);
    expect(Db.sales.length, 2);
  });
}

/// One valid Hive frame (length, key, value, CRC) whose value has type id 99.
List<int> _frameWithUnknownType() {
  final body = <int>[
    1, 1, 0x6B, // string key 'k'
    99 + 32, 0, // custom type id 99 (custom ids are offset by 32)
  ];
  final length = 4 + body.length + 4;
  final frame = BytesBuilder()
    ..add(
        (ByteData(4)..setUint32(0, length, Endian.little)).buffer.asUint8List())
    ..add(body);
  final crc = _crc32(frame.toBytes());
  frame.add(
      (ByteData(4)..setUint32(0, crc, Endian.little)).buffer.asUint8List());
  return frame.toBytes();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
