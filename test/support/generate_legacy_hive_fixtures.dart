// Regenerates the `.hive` files in test/fixtures/legacy_hive that
// legacy_hive_import_test.dart imports. They hold the data the test asserts
// on, written with the old Hive adapter layout. Run it only when the fixture
// data has to change:
//
//   flutter test test/support/generate_legacy_hive_fixtures.dart
//
// The file name does not end in `_test.dart`, so `flutter test` skips it.
import 'dart:io';
import 'dart:typed_data';

import 'package:billit/data/legacy_hive_import.dart';
import 'package:billit/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('write legacy Hive fixtures', () async {
    final dir = Directory('test/fixtures/legacy_hive')
      ..createSync(recursive: true);
    for (final file in dir.listSync().whereType<File>()) {
      file.deleteSync();
    }
    Hive.init(dir.path);
    registerLegacyHiveAdapters();

    final users = await Hive.openBox<User>('users');
    await users.put(
      'u-admin',
      User()
        ..id = 'u-admin'
        ..username = 'owner'
        ..password = User.hash('s3cret')
        ..userType = UserType.admin
        ..securityAnswer = 'Rex'
        ..securityQuestion = 'First pet?',
    );
    await users.put(
      'u-worker',
      User()
        ..id = 'u-worker'
        ..username = 'helper'
        ..password = User.hash('worker1')
        ..userType = UserType.worker,
    );

    final products = await Hive.openBox<Product>('products');
    await products.put(
      'p-rose',
      Product()
        ..id = 'p-rose'
        ..name = 'Rose bunch'
        ..sellingPrice = 120.5
        ..costPrice = 80.0
        ..stock = 14.0
        ..unit = UnitType.pcs
        ..category = 'Flowers'
        ..subCategory = 'Cut'
        ..active = true
        ..barcode = '8901234567890'
        ..hsnCode = '0603'
        ..gstRate = 5.0,
    );
    await products.put(
      'p-turf',
      Product()
        ..id = 'p-turf'
        ..name = 'Turf'
        ..sellingPrice = 35.0
        ..costPrice = 20.0
        ..stock = 250.75
        ..unit = UnitType.sqft
        ..active = false,
    );
    // The old Drive restore refilled boxes with auto-increment keys.
    await products.add(
      Product()
        ..id = 'p-soil'
        ..name = 'Potting soil'
        ..sellingPrice = 60.0
        ..costPrice = 40.0
        ..stock = 3.5
        ..unit = UnitType.kg,
    );

    final sales = await Hive.openBox<Sale>('sales');
    await sales.put(
      'INV-0001',
      Sale()
        ..id = 'INV-0001'
        ..date = DateTime(2025, 3, 14, 10, 30, 15, 250)
        ..items = [
          SaleItem()
            ..productId = 'p-rose'
            ..qty = 2.0
            ..sellingPrice = 120.5
            ..costPrice = 80.0
            ..subtotal = 241.0
            ..unitLabel = 'pcs'
            ..hsnCode = '0603'
            ..gstRate = 5.0
            ..taxableAmount = 229.52
            ..cgstAmount = 5.74
            ..sgstAmount = 5.74
            ..igstAmount = 0.0,
          SaleItem()
            ..productId = 'p-turf'
            ..qty = 12.5
            ..sellingPrice = 35.0
            ..costPrice = 20.0
            ..subtotal = 437.5
            ..unitLabel = 'sqft',
        ]
        ..totalAmount = 796.63
        ..totalCost = 536.25
        ..profit = 260.38
        ..payment = PaymentMethod.upi
        ..customerName = 'Asha'
        ..customerPhone = '9876543210'
        ..userId = 'u-worker'
        ..discount = 10
        ..gstEnabled = true
        ..gstRate = 5
        ..taxableAmount = 229.52
        ..cgstAmount = 5.74
        ..sgstAmount = 5.74
        ..igstAmount = 0
        ..customerGstin = '32ABCDE1234F1Z5'
        ..interstateSale = false
        ..gstInclusive = true,
    );
    await sales.put(
      'INV-0002',
      Sale()
        ..id = 'INV-0002'
        ..date = DateTime(2025, 3, 15, 16, 5)
        ..items = []
        ..payment = PaymentMethod.card
        ..interstateSale = true
        ..igstAmount = 2.86,
    );

    final expenses = await Hive.openBox<Expense>('expenses');
    await expenses.put(
      'e-1',
      Expense(
        id: 'e-1',
        date: DateTime(2025, 3, 1),
        category: 'Rent',
        amount: 15000.0,
        description: 'March rent',
      ),
    );

    final employees = await Hive.openBox<Employee>('employees');
    await employees.put(
      'm-1',
      Employee(
          id: 'm-1',
          name: 'Ravi',
          type: 'daily',
          wage: 750.5,
          attendance: 22),
    );
    await employees.put(
      'm-2',
      Employee(
          id: 'm-2',
          name: 'Meera',
          type: 'monthly',
          wage: 18000.0,
          salaryPaid: true),
    );

    final settings = await Hive.openBox<dynamic>('app_settings');
    await settings.putAll({
      'app_name': 'Asha Flowers',
      'business_name': 'Asha Flowers & Garden',
      'gst_enabled': true,
      'gst_rate': 5.0,
      'corner_radius': 16.0,
      'low_stock_threshold': 10,
      'next_invoice_number': 3,
      'invoice_prefix': 'INV',
      'invoice_templates': {
        '80mm': {
          'columns': ['name', 'qty', 'total'],
          'fontSize': 9.5,
          'showLogo': true,
        },
      },
      'stock_history': [
        {'productId': 'p-rose', 'delta': -2.0, 'at': '2025-03-14T10:30:15.250'},
      ],
      'logo_bytes': Uint8List.fromList([0, 1, 2, 250, 255]),
    });

    final session = await Hive.openBox<dynamic>('session');
    await session.put('user_id', 'u-admin');
    await session.put('last_backup_at', DateTime(2025, 3, 10, 9));

    final device = await Hive.openBox<dynamic>('settings');
    await device.put('drive_auto_sync', false);
    await device.put('printer_mac_address', '00:11:22:33:44:55');

    await Hive.close();
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.hive')) file.deleteSync();
    }
  });
}
