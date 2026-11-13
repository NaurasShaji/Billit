import 'dart:io';
import 'dart:typed_data';

import 'package:billit/data/database.dart';
import 'package:billit/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_database.dart';

Product _product(String id, {String name = 'Item', double stock = 1}) =>
    Product()
      ..id = id
      ..name = name
      ..stock = stock;

Sale _sale(String id) => Sale()
  ..id = id
  ..date = DateTime(2025, 6, 1, 9, 15, 30, 120)
  ..items = [
    SaleItem()
      ..productId = 'p2'
      ..qty = 2.5
      ..sellingPrice = 40.4
      ..costPrice = 30.3
      ..subtotal = 101
      ..unitLabel = 'sqft'
      ..hsnCode = '0603'
      ..gstRate = 5
      ..taxableAmount = 96.19
      ..cgstAmount = 2.4
      ..sgstAmount = 2.41
      ..igstAmount = 0,
    SaleItem()
      ..productId = 'p1'
      ..qty = 1
      ..sellingPrice = 10
      ..costPrice = 7
      ..subtotal = 10
      ..unitLabel = 'pcs',
  ]
  ..totalAmount = 111
  ..totalCost = 82.75
  ..profit = 28.25
  ..payment = PaymentMethod.upi
  ..customerName = "O'Brien"
  ..customerPhone = '9876543210'
  ..userId = 'worker'
  ..discount = 1.5
  ..gstEnabled = true
  ..gstRate = 5
  ..taxableAmount = 96.19
  ..cgstAmount = 2.4
  ..sgstAmount = 2.41
  ..customerGstin = '32ABCDE1234F1Z5'
  ..interstateSale = true
  ..gstInclusive = true;

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('billit_db_test');
    path = '${dir.path}/billit.db';
    openDatabaseFile(path);
  });

  tearDown(() {
    Db.close();
    dir.deleteSync(recursive: true);
  });

  void reopen() {
    Db.close();
    openDatabaseFile(path);
  }

  test('every record type survives closing and reopening the database',
      () async {
    final user = User()
      ..id = 'u1'
      ..username = 'owner'
      ..password = User.hash('pw')
      ..userType = UserType.admin
      ..securityAnswer = 'Rex'
      ..securityQuestion = 'First pet?';
    final product = Product()
      ..id = 'p1'
      ..name = 'Rose'
      ..sellingPrice = 120.5
      ..costPrice = 80.25
      ..stock = 14.75
      ..unit = UnitType.sqft
      ..category = 'Flowers'
      ..subCategory = 'Cut'
      ..active = false
      ..barcode = '8901234567890'
      ..hsnCode = '0603'
      ..gstRate = 12;
    final expense = Expense(
        id: 'e1',
        date: DateTime(2025, 6, 2, 8),
        category: 'Rent',
        amount: 15000.5,
        description: 'June');
    final employee = Employee(
        id: 'm1',
        name: 'Ravi',
        type: 'daily',
        wage: 750.5,
        attendance: 22,
        salaryPaid: true);

    await Db.users.put(user.id, user);
    await Db.products.put(product.id, product);
    await Db.products.put('p0', _product('p0'));
    await Db.sales.put('s1', _sale('s1'));
    await Db.expenses.put(expense.id, expense);
    await Db.employees.put(employee.id, employee);

    reopen();

    final u = Db.users.get('u1')!;
    expect([
      u.username,
      u.password,
      u.userType,
      u.securityAnswer,
      u.securityQuestion
    ], [
      'owner',
      User.hash('pw'),
      UserType.admin,
      'Rex',
      'First pet?'
    ]);

    expect(Db.products.get('p1')!.toJson(), product.toJson());
    final defaults = Db.products.get('p0')!;
    expect(defaults.barcode, isNull);
    expect(defaults.gstRate, isNull);
    expect(defaults.active, isTrue);

    final s = Db.sales.get('s1')!;
    expect(s.toJson(), _sale('s1').toJson());
    expect(s.items.map((i) => i.productId), ['p2', 'p1']);
    expect(s.items[1].gstRate, isNull);

    expect(Db.expenses.get('e1')!.toJson(), expense.toJson());
    expect(Db.employees.get('m1')!.toJson(), employee.toJson());
  });

  test('records iterate in id order and are the same objects on each read',
      () async {
    await Db.products.put('b', _product('b'));
    await Db.products.put('c', _product('c'));
    await Db.products.put('a', _product('a'));

    expect(Db.products.keys, ['a', 'b', 'c']);
    expect(Db.products.values.map((p) => p.id), ['a', 'b', 'c']);
    expect(Db.products.length, 3);
    expect(identical(Db.products.get('a'), Db.products.get('a')), isTrue);
    expect(Db.products.get('missing'), isNull);
    expect(Db.products.containsKey('b'), isTrue);
  });

  test('save() writes a changed record and delete() removes it', () async {
    await Db.products.put('p1', _product('p1', stock: 5));
    await Db.sales.put('s1', _sale('s1'));

    final product = Db.products.get('p1')!..stock = 2.5;
    await product.save();
    final sale = Db.sales.get('s1')!;
    sale.items.removeAt(0);
    sale.totalAmount = 10;
    await sale.save();
    reopen();

    expect(Db.products.get('p1')!.stock, 2.5);
    expect(Db.sales.get('s1')!.items.map((i) => i.productId), ['p1']);
    expect(Db.sales.get('s1')!.totalAmount, 10);

    await Db.sales.get('s1')!.delete();
    await Db.products.delete('p1');
    reopen();

    expect(Db.sales.isEmpty, isTrue);
    expect(Db.products.isEmpty, isTrue);
    expect(
        Db.instance.db
            .select('SELECT count(*) AS n FROM sale_items')
            .first['n'],
        0);
  });

  test('addAll stores each record under its own id; clear empties the table',
      () async {
    await Db.expenses.addAll([
      for (final id in ['e2', 'e1'])
        Expense(
            id: id,
            date: DateTime(2025),
            category: 'Misc',
            amount: 1,
            description: ''),
    ]);
    reopen();
    expect(Db.expenses.keys, ['e1', 'e2']);

    expect(await Db.expenses.clear(), 2);
    reopen();
    expect(Db.expenses.isEmpty, isTrue);
  });

  test('settings keep their types across a reopen', () async {
    final values = <String, dynamic>{
      'text': 'Thank you',
      'int': 10,
      'double': 16.0,
      'fraction': 1.25,
      'bool': true,
      'null': null,
      'list': ['a', 2, 3.5, false],
      'map': {
        'name': 'thermal',
        'columns': ['name', 'qty'],
        'size': 9.5,
      },
      'date': DateTime(2025, 3, 10, 9, 30),
      'bytes': Uint8List.fromList([0, 1, 254, 255]),
    };
    await Db.settings.putAll(values);

    for (final pass in ['before', 'after']) {
      final s = Db.settings;
      expect(s.get('text'), 'Thank you', reason: pass);
      expect(s.get('int'), isA<int>(), reason: pass);
      expect(s.get('int'), 10, reason: pass);
      expect(s.get('double'), isA<double>(), reason: pass);
      expect(s.get('fraction'), 1.25, reason: pass);
      expect(s.get('bool'), true, reason: pass);
      expect(s.containsKey('null'), isTrue, reason: pass);
      expect(s.get('null', defaultValue: 'x'), isNull, reason: pass);
      expect(s.get('list'), ['a', 2, 3.5, false], reason: pass);
      expect(s.get('map'), values['map'], reason: pass);
      expect(s.get('date'), DateTime(2025, 3, 10, 9, 30), reason: pass);
      expect(s.get('bytes'), isA<Uint8List>(), reason: pass);
      expect(s.get('bytes'), [0, 1, 254, 255], reason: pass);
      expect(s.get('absent'), isNull, reason: pass);
      expect(s.get('absent', defaultValue: 7), 7, reason: pass);
      reopen();
    }
  });

  test('the key/value stores are separate tables', () async {
    await Db.settings.put('k', 'settings');
    await Db.session.put('k', 'session');
    await Db.deviceSettings.put('k', 'device');
    await Db.session.delete('k');
    reopen();

    expect(Db.settings.get('k'), 'settings');
    expect(Db.session.containsKey('k'), isFalse);
    expect(Db.deviceSettings.get('k'), 'device');
  });

  test('listeners hear about every kind of write, and only on their store',
      () async {
    var products = 0;
    var settings = 0;
    Db.products.listenable().addListener(() => products++);
    Db.settings.listenable().addListener(() => settings++);

    await Db.products.put('p1', _product('p1'));
    await pumpEventQueue();
    expect([products, settings], [1, 0]);

    await Db.products.get('p1')!.save();
    await pumpEventQueue();
    await Db.products.delete('p1');
    await pumpEventQueue();
    await Db.products.clear();
    await pumpEventQueue();
    expect([products, settings], [4, 0]);

    await Db.settings.put('k', 1);
    await pumpEventQueue();
    expect([products, settings], [4, 1]);
  });

  test('a failed transaction leaves both the file and memory unchanged',
      () async {
    await Db.products.put('keep', _product('keep', stock: 5));
    await Db.settings.put('next_invoice_number', 7);

    await expectLater(
      Db.transaction(() async {
        await Db.products.clear();
        await Db.products.put('new', _product('new'));
        Db.products.get('new')!.stock = 99;
        await Db.settings.put('next_invoice_number', 8);
        throw const FormatException('bad backup');
      }),
      throwsFormatException,
    );

    for (final pass in ['memory', 'file']) {
      expect(Db.products.keys, ['keep'], reason: pass);
      expect(Db.products.get('keep')!.stock, 5, reason: pass);
      expect(Db.settings.get('next_invoice_number'), 7, reason: pass);
      reopen();
    }
  });

  test('a successful transaction commits every write', () async {
    await Db.transaction(() async {
      await Db.products.put('p1', _product('p1'));
      await Db.sales.put('s1', _sale('s1'));
    });
    reopen();

    expect(Db.products.keys, ['p1']);
    expect(Db.sales.get('s1')!.items, hasLength(2));
  });

  test('a write that SQLite rejects does not reach memory', () async {
    await Db.products.put('p1', _product('p1', name: 'Good'));
    final broken = Product()..id = 'p2'; // name was never set

    await expectLater(Db.products.put('p2', broken), throwsA(anything));

    expect(Db.products.keys, ['p1']);
    reopen();
    expect(Db.products.keys, ['p1']);
  });
}
