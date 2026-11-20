import '../data/database.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'supabase_service.dart';

/// Two-way, shop-scoped synchronization for the records currently supported
/// by Billit's SQLite model. Every write is protected by Supabase RLS.
class CloudSyncService {
  CloudSyncService._();

  static bool _running = false;
  static const int _pageSize = 500;

  static Future<CloudSyncSummary> syncShop({
    required String shopId,
    required Map<String, dynamic> permissions,
    required bool isAdmin,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    if (Db.activeDatabaseKey != 'shop:$shopId') {
      throw StateError('The selected shop database is not open.');
    }
    if (_running) throw StateError('A sync is already running.');
    _running = true;
    var pushed = 0;
    var pulled = 0;
    try {
      pushed = await _pushPending(shopId);
      pulled = await _pullRemote(shopId, permissions, isAdmin);
      return CloudSyncSummary(pushed: pushed, pulled: pulled);
    } finally {
      _running = false;
    }
  }

  static Future<int> _pushPending(String shopId) async {
    var completed = 0;
    while (true) {
      final batch = await Db.pendingSyncChanges(limit: 50);
      if (batch.isEmpty) break;
      for (final change in batch) {
        try {
          await _pushOne(shopId, change);
          await Db.acknowledgeSyncChange(change.id, change.revision);
          completed++;
        } catch (error) {
          await Db.recordSyncFailure(change.id, change.revision, '$error');
          rethrow;
        }
      }
    }
    return completed;
  }

  static Future<void> _pushOne(String shopId, SyncOutboxChange change) async {
    final client = SupabaseService.client;
    final table = change.tableName;
    if (change.operation == 'DELETE') {
      await client.from(table).update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('shop_id', shopId).eq('id', change.recordId);
      return;
    }

    switch (table) {
      case 'products':
        final product = Db.products.get(change.recordId);
        if (product == null) return;
        await client.from('products').upsert({
          'shop_id': shopId,
          'id': product.id,
          'name': product.name,
          'selling_price': product.sellingPrice,
          'cost_price': product.costPrice,
          'stock': product.stock,
          'unit': product.unit.name,
          'category': product.category,
          'sub_category': product.subCategory,
          'active': product.active,
          'barcode': product.barcode,
          'hsn_code': product.hsnCode,
          'gst_rate': product.gstRate,
          'deleted_at': null,
        }, onConflict: 'shop_id,id');
        break;
      case 'sales':
        final sale = Db.sales.get(change.recordId);
        if (sale == null) return;
        await client.from('sales').upsert({
          'shop_id': shopId,
          'id': sale.id,
          'date': sale.date.toUtc().toIso8601String(),
          'total_amount': sale.totalAmount,
          'total_cost': sale.totalCost,
          'profit': sale.profit,
          'payment': sale.payment.name,
          'customer_name': sale.customerName,
          'customer_phone': sale.customerPhone,
          'discount': sale.discount,
          'gst_enabled': sale.gstEnabled,
          'gst_rate': sale.gstRate,
          'taxable_amount': sale.taxableAmount,
          'cgst_amount': sale.cgstAmount,
          'sgst_amount': sale.sgstAmount,
          'igst_amount': sale.igstAmount,
          'customer_gstin': sale.customerGstin,
          'interstate_sale': sale.interstateSale,
          'gst_inclusive': sale.gstInclusive,
          'deleted_at': null,
        }, onConflict: 'shop_id,id');

        // Sale items are replaced as one logical snapshot after the parent row
        // has been written. The outbox row is acknowledged only after both steps.
        await client.from('sale_items').delete()
            .eq('shop_id', shopId).eq('sale_id', sale.id);
        if (sale.items.isNotEmpty) {
          await client.from('sale_items').insert([
            for (var i = 0; i < sale.items.length; i++)
              _saleItemRow(shopId, sale.id, i, sale.items[i]),
          ]);
        }
        break;
      case 'expenses':
        final expense = Db.expenses.get(change.recordId);
        if (expense == null) return;
        await client.from('expenses').upsert({
          'shop_id': shopId,
          'id': expense.id,
          'date': expense.date.toUtc().toIso8601String(),
          'category': expense.category,
          'amount': expense.amount,
          'description': expense.description,
          'deleted_at': null,
        }, onConflict: 'shop_id,id');
        break;
      case 'employees':
        final employee = Db.employees.get(change.recordId);
        if (employee == null) return;
        await client.from('employees').upsert({
          'shop_id': shopId,
          'id': employee.id,
          'name': employee.name,
          'type': employee.type,
          'wage': employee.wage,
          'attendance': employee.attendance,
          'salary_paid': employee.salaryPaid,
          'deleted_at': null,
        }, onConflict: 'shop_id,id');
        break;
      default:
        throw StateError('Unsupported sync table: $table');
    }
  }

  static Map<String, dynamic> _saleItemRow(
    String shopId,
    String saleId,
    int position,
    SaleItem item,
  ) => {
        'shop_id': shopId,
        'sale_id': saleId,
        'position': position,
        'product_id': item.productId,
        'qty': item.qty,
        'selling_price': item.sellingPrice,
        'cost_price': item.costPrice,
        'subtotal': item.subtotal,
        'unit_label': item.unitLabel,
        'hsn_code': item.hsnCode,
        'gst_rate': item.gstRate,
        'taxable_amount': item.taxableAmount,
        'cgst_amount': item.cgstAmount,
        'sgst_amount': item.sgstAmount,
        'igst_amount': item.igstAmount,
      };

  static bool _canRead(
    String table,
    Map<String, dynamic> permissions,
    bool isAdmin,
  ) {
    if (isAdmin) return true;
    bool has(String key) => permissions[key] == true;
    switch (table) {
      case 'products':
        return has('inventory') || has('billing') || has('reports');
      case 'sales':
        return has('billing') || has('reports');
      case 'expenses':
        return has('expenses') || has('reports');
      case 'employees':
        return has('payroll');
      default:
        return false;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAll(
    String table,
    String shopId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await SupabaseService.client
          .from(table)
          .select()
          .eq('shop_id', shopId)
          .order('updated_at')
          .order('id')
          .range(offset, offset + _pageSize - 1);
      rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return rows;
  }

  static Future<int> _pullRemote(
    String shopId,
    Map<String, dynamic> permissions,
    bool isAdmin,
  ) async {
    final tables = ['products', 'sales', 'expenses', 'employees']
        .where((table) => _canRead(table, permissions, isAdmin))
        .toList();
    final remote = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      remote[table] = await _fetchAll(table, shopId);
    }

    List<Map<String, dynamic>> remoteItems = [];
    if (tables.contains('sales')) {
      remoteItems = await _fetchAll('sale_items', shopId);
    }
    final itemsBySale = <String, List<Map<String, dynamic>>>{};
    for (final item in remoteItems) {
      final saleId = item['sale_id'].toString();
      (itemsBySale[saleId] ??= []).add(item);
    }

    final pending = await Db.pendingSyncChanges(limit: 500);
    final locallyDirty = <String>{
      for (final item in pending) '${item.tableName}:${item.recordId}',
    };
    var applied = 0;

    await Db.withoutOutbox(() async {
      for (final row in remote['products'] ?? const []) {
        final id = row['id'].toString();
        if (locallyDirty.contains('products:$id')) continue;
        if (row['deleted_at'] != null) {
          await Db.products.delete(id);
        } else {
          await Db.products.put(id, Product.fromJson({
            'id': id,
            'name': row['name'],
            'sellingPrice': row['selling_price'] ?? 0,
            'costPrice': row['cost_price'] ?? 0,
            'stock': row['stock'] ?? 0,
            'unit': row['unit'],
            'category': row['category'] ?? 'General',
            'subCategory': row['sub_category'] ?? '',
            'active': row['active'] ?? true,
            'barcode': row['barcode'],
            'hsnCode': row['hsn_code'] ?? '',
            'gstRate': row['gst_rate'],
          }));
        }
        applied++;
      }

      for (final row in remote['sales'] ?? const []) {
        final id = row['id'].toString();
        if (locallyDirty.contains('sales:$id')) continue;
        if (row['deleted_at'] != null) {
          await Db.sales.delete(id);
        } else {
          final lines = (itemsBySale[id] ?? [])
            ..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num));
          await Db.sales.put(id, Sale.fromJson({
            'id': id,
            'date': row['date'],
            'items': [
              for (final item in lines)
                {
                  'productId': item['product_id'],
                  'qty': item['qty'] ?? 0,
                  'sellingPrice': item['selling_price'] ?? 0,
                  'costPrice': item['cost_price'] ?? 0,
                  'subtotal': item['subtotal'] ?? 0,
                  'unitLabel': item['unit_label'] ?? 'pcs',
                  'hsnCode': item['hsn_code'] ?? '',
                  'gstRate': item['gst_rate'],
                  'taxableAmount': item['taxable_amount'] ?? 0,
                  'cgstAmount': item['cgst_amount'] ?? 0,
                  'sgstAmount': item['sgst_amount'] ?? 0,
                  'igstAmount': item['igst_amount'] ?? 0,
                },
            ],
            'totalAmount': row['total_amount'] ?? 0,
            'totalCost': row['total_cost'] ?? 0,
            'profit': row['profit'] ?? 0,
            'payment': row['payment'] ?? 'cash',
            'customerName': row['customer_name'] ?? '',
            'customerPhone': row['customer_phone'] ?? '',
            'userId': '',
            'discount': row['discount'] ?? 0,
            'gstEnabled': row['gst_enabled'] ?? false,
            'gstRate': row['gst_rate'] ?? 0,
            'taxableAmount': row['taxable_amount'] ?? 0,
            'cgstAmount': row['cgst_amount'] ?? 0,
            'sgstAmount': row['sgst_amount'] ?? 0,
            'igstAmount': row['igst_amount'] ?? 0,
            'customerGstin': row['customer_gstin'] ?? '',
            'interstateSale': row['interstate_sale'] ?? false,
            'gstInclusive': row['gst_inclusive'] ?? false,
          }));
        }
        applied++;
      }

      for (final row in remote['expenses'] ?? const []) {
        final id = row['id'].toString();
        if (locallyDirty.contains('expenses:$id')) continue;
        if (row['deleted_at'] != null) {
          await Db.expenses.delete(id);
        } else {
          await Db.expenses.put(id, Expense.fromJson({
            'id': id,
            'date': row['date'],
            'category': row['category'],
            'amount': row['amount'] ?? 0,
            'description': row['description'] ?? '',
          }));
        }
        applied++;
      }

      for (final row in remote['employees'] ?? const []) {
        final id = row['id'].toString();
        if (locallyDirty.contains('employees:$id')) continue;
        if (row['deleted_at'] != null) {
          await Db.employees.delete(id);
        } else {
          await Db.employees.put(id, Employee.fromJson({
            'id': id,
            'name': row['name'],
            'type': row['type'],
            'wage': row['wage'] ?? 0,
            'attendance': row['attendance'] ?? 0,
            'salaryPaid': row['salary_paid'] ?? false,
          }));
        }
        applied++;
      }
    });
    return applied;
  }
}

class CloudSyncSummary {
  const CloudSyncSummary({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
