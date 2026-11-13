part of 'database.dart';

int _int(Object? v) => v is BigInt ? v.toInt() : (v as num).toInt();
bool _bool(Object? v) => _int(v) != 0;
int _flag(bool v) => v ? 1 : 0;
double? _realOrNull(Object? v) => (v as num?)?.toDouble();

/// SQLite stores NaN as NULL, so a NULL in a required REAL column is NaN.
double _real(Object? v) => (v as num?)?.toDouble() ?? double.nan;

DateTime _date(Object? v) => DateTime.fromMillisecondsSinceEpoch(_int(v));

E _enum<E extends Enum>(List<E> values, Object? name, E fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

class _UserStore extends EntityStore<User> {
  _UserStore(AppDatabase owner)
      : super._(owner, 'users', const [
          'username',
          'password',
          'user_type',
          'security_answer',
          'security_question',
        ]);

  @override
  String _idOf(User value) => value.id;

  @override
  List<Object?> _toRow(User u) => [
        u.username,
        u.password,
        u.userType.name,
        u.securityAnswer,
        u.securityQuestion,
      ];

  @override
  User _fromRow(Row row) => User()
    ..id = row['id'] as String
    ..username = row['username'] as String
    ..password = row['password'] as String
    ..userType = _enum(UserType.values, row['user_type'], UserType.worker)
    ..securityAnswer = row['security_answer'] as String
    ..securityQuestion = row['security_question'] as String;
}

class _ProductStore extends EntityStore<Product> {
  _ProductStore(AppDatabase owner)
      : super._(owner, 'products', const [
          'name',
          'selling_price',
          'cost_price',
          'stock',
          'unit',
          'category',
          'sub_category',
          'active',
          'barcode',
          'hsn_code',
          'gst_rate',
        ]);

  @override
  String _idOf(Product value) => value.id;

  @override
  List<Object?> _toRow(Product p) => [
        p.name,
        p.sellingPrice,
        p.costPrice,
        p.stock,
        p.unit.name,
        p.category,
        p.subCategory,
        _flag(p.active),
        p.barcode,
        p.hsnCode,
        p.gstRate,
      ];

  @override
  Product _fromRow(Row row) => Product()
    ..id = row['id'] as String
    ..name = row['name'] as String
    ..sellingPrice = _real(row['selling_price'])
    ..costPrice = _real(row['cost_price'])
    ..stock = _real(row['stock'])
    ..unit = _enum(UnitType.values, row['unit'], UnitType.pcs)
    ..category = row['category'] as String
    ..subCategory = row['sub_category'] as String
    ..active = _bool(row['active'])
    ..barcode = row['barcode'] as String?
    ..hsnCode = row['hsn_code'] as String
    ..gstRate = _realOrNull(row['gst_rate']);
}

class _SaleStore extends EntityStore<Sale> {
  _SaleStore(AppDatabase owner)
      : super._(owner, 'sales', const [
          'date',
          'total_amount',
          'total_cost',
          'profit',
          'payment',
          'customer_name',
          'customer_phone',
          'user_id',
          'discount',
          'gst_enabled',
          'gst_rate',
          'taxable_amount',
          'cgst_amount',
          'sgst_amount',
          'igst_amount',
          'customer_gstin',
          'interstate_sale',
          'gst_inclusive',
        ]);

  static const _insertItem = 'INSERT INTO sale_items (sale_id, position, '
      'product_id, qty, selling_price, cost_price, subtotal, unit_label, '
      'hsn_code, gst_rate, taxable_amount, cgst_amount, sgst_amount, '
      'igst_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  @override
  String _idOf(Sale value) => value.id;

  @override
  List<Object?> _toRow(Sale s) => [
        s.date.millisecondsSinceEpoch,
        s.totalAmount,
        s.totalCost,
        s.profit,
        s.payment.name,
        s.customerName,
        s.customerPhone,
        s.userId,
        s.discount,
        _flag(s.gstEnabled),
        s.gstRate,
        s.taxableAmount,
        s.cgstAmount,
        s.sgstAmount,
        s.igstAmount,
        s.customerGstin,
        _flag(s.interstateSale),
        _flag(s.gstInclusive),
      ];

  /// A sale's line items live in sale_items; they are rewritten with it.
  @override
  void _writeRow(String id, Sale value) {
    super._writeRow(id, value);
    _owner
        ._statement('DELETE FROM sale_items WHERE sale_id = ?')
        .execute([id]);
    final insert = _owner._statement(_insertItem);
    for (var i = 0; i < value.items.length; i++) {
      final item = value.items[i];
      insert.execute([
        id,
        i,
        item.productId,
        item.qty,
        item.sellingPrice,
        item.costPrice,
        item.subtotal,
        item.unitLabel,
        item.hsnCode,
        item.gstRate,
        item.taxableAmount,
        item.cgstAmount,
        item.sgstAmount,
        item.igstAmount,
      ]);
    }
  }

  @override
  Sale _fromRow(Row row) => Sale()
    ..id = row['id'] as String
    ..date = _date(row['date'])
    ..items = <SaleItem>[]
    ..totalAmount = _real(row['total_amount'])
    ..totalCost = _real(row['total_cost'])
    ..profit = _real(row['profit'])
    ..payment = _enum(PaymentMethod.values, row['payment'], PaymentMethod.cash)
    ..customerName = row['customer_name'] as String
    ..customerPhone = row['customer_phone'] as String
    ..userId = row['user_id'] as String
    ..discount = _real(row['discount'])
    ..gstEnabled = _bool(row['gst_enabled'])
    ..gstRate = _real(row['gst_rate'])
    ..taxableAmount = _real(row['taxable_amount'])
    ..cgstAmount = _real(row['cgst_amount'])
    ..sgstAmount = _real(row['sgst_amount'])
    ..igstAmount = _real(row['igst_amount'])
    ..customerGstin = row['customer_gstin'] as String
    ..interstateSale = _bool(row['interstate_sale'])
    ..gstInclusive = _bool(row['gst_inclusive']);

  @override
  void _load() {
    super._load();
    final rows = _owner.db
        .select('SELECT * FROM sale_items ORDER BY sale_id, position');
    for (final row in rows) {
      _cache[row['sale_id'] as String]?.items.add(SaleItem()
        ..productId = row['product_id'] as String
        ..qty = _real(row['qty'])
        ..sellingPrice = _real(row['selling_price'])
        ..costPrice = _real(row['cost_price'])
        ..subtotal = _real(row['subtotal'])
        ..unitLabel = row['unit_label'] as String
        ..hsnCode = row['hsn_code'] as String
        ..gstRate = _realOrNull(row['gst_rate'])
        ..taxableAmount = _real(row['taxable_amount'])
        ..cgstAmount = _real(row['cgst_amount'])
        ..sgstAmount = _real(row['sgst_amount'])
        ..igstAmount = _real(row['igst_amount']));
    }
  }
}

class _ExpenseStore extends EntityStore<Expense> {
  _ExpenseStore(AppDatabase owner)
      : super._(owner, 'expenses',
            const ['date', 'category', 'amount', 'description']);

  @override
  String _idOf(Expense value) => value.id;

  @override
  List<Object?> _toRow(Expense e) =>
      [e.date.millisecondsSinceEpoch, e.category, e.amount, e.description];

  @override
  Expense _fromRow(Row row) => Expense(
        id: row['id'] as String,
        date: _date(row['date']),
        category: row['category'] as String,
        amount: _real(row['amount']),
        description: row['description'] as String,
      );
}

class _EmployeeStore extends EntityStore<Employee> {
  _EmployeeStore(AppDatabase owner)
      : super._(owner, 'employees',
            const ['name', 'type', 'wage', 'attendance', 'salary_paid']);

  @override
  String _idOf(Employee value) => value.id;

  @override
  List<Object?> _toRow(Employee e) =>
      [e.name, e.type, e.wage, e.attendance, _flag(e.salaryPaid)];

  @override
  Employee _fromRow(Row row) => Employee(
        id: row['id'] as String,
        name: row['name'] as String,
        type: row['type'] as String,
        wage: _real(row['wage']),
        attendance: _int(row['attendance']),
        salaryPaid: _bool(row['salary_paid']),
      );
}
