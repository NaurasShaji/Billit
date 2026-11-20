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

  static Map<String, dynamic>? get pendingConflict {
    final value = Db.meta.get('sync_conflict_pending');
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// Resolve a detected concurrent edit explicitly. Keeping local refreshes
  /// the compare-and-swap baseline; using cloud discards only the conflicting
  /// outbox entry and resets that table's cursor so the next pull reapplies it.
  static Future<void> resolvePendingConflict({required bool keepLocal}) async {
    final conflict = pendingConflict;
    if (conflict == null) return;
    final table = conflict['table'].toString();
    final id = conflict['id'].toString();

    if (keepLocal) {
      if (table == 'shop_settings') {
        final row = await SupabaseService.client
            .from('shop_settings')
            .select('updated_at')
            .eq('shop_id', Db.meta.get('active_shop_id').toString())
            .maybeSingle();
        if (row == null) {
          await Db.meta.delete(_baselineKey(table, id));
        } else {
          await _saveBaseline(table, id, row['updated_at']);
        }
      } else {
        final shopId = Db.meta.get('active_shop_id').toString();
        final row = await _readCloudVersion(table, shopId, id);
        if (row == null) {
          await Db.meta.delete(_baselineKey(table, id));
        } else {
          await _saveBaseline(table, id, row['updated_at']);
        }
      }
    } else {
      await Db.discardSyncChange(table, id);
      await Db.meta.delete(_baselineKey(table, id));
      if (table != 'shop_settings') {
        await Db.meta.delete('sync_cursor_$table');
      }
    }
    await Db.meta.delete('sync_conflict_pending');
  }

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
      pushed = await _pushPending(shopId, permissions: permissions, isAdmin: isAdmin);
      pulled = await _pullRemote(shopId, permissions, isAdmin);
      return CloudSyncSummary(pushed: pushed, pulled: pulled);
    } finally {
      _running = false;
    }
  }

  static bool _canWrite(
    SyncOutboxChange change,
    Map<String, dynamic> permissions,
    bool isAdmin,
  ) {
    if (isAdmin) return true;
    bool has(String key) => permissions[key] == true;
    switch (change.tableName) {
      case 'products':
        return has('inventory') ||
            (has('billing') && change.operation == 'UPSERT');
      case 'sales':
        return has('billing');
      case 'expenses':
        return has('expenses');
      case 'employees':
        return has('payroll') && change.operation != 'DELETE';
      case 'shop_settings':
        return isAdmin;
      default:
        return false;
    }
  }

  static Future<int> _pushPending(String shopId, {required Map<String, dynamic> permissions, required bool isAdmin}) async {
    var completed = 0;
    var afterId = 0;
    while (true) {
      final batch = await Db.pendingSyncChanges(limit: 50, afterId: afterId);
      if (batch.isEmpty) break;
      for (final change in batch) {
        afterId = change.id;
        // A shop-local database may contain pending edits made by another
        // account on this device. Leave changes outside this user's grants
        // queued for an administrator/authorized worker instead of failing
        // the entire sync or retrying the same first page forever.
        if (!_canWrite(change, permissions, isAdmin)) continue;
        try {
          await _pushOne(shopId, change, permissions: permissions, isAdmin: isAdmin);
          await Db.acknowledgeSyncChange(change.id, change.revision);
          completed++;
        } catch (error) {
          if (error.toString().contains('SYNC_CONFLICT')) {
            await Db.meta.put('sync_conflict_pending', {
              'table': change.tableName,
              'id': change.recordId,
              'message': error.toString(),
            });
          } else {
            await Db.recordSyncFailure(change.id, change.revision, '$error');
          }
          rethrow;
        }
      }
    }
    return completed;
  }

  static double? _finite(double value) => value.isFinite ? value : null;

  static String _baselineKey(String table, String id) =>
      'sync_baseline_${table}_${id}';

  static Future<void> _saveBaseline(
    String table,
    String id,
    Object? updatedAt,
  ) async {
    if (updatedAt == null) {
      throw StateError('Cloud did not return updated_at for $table/$id.');
    }
    await Db.meta.put(_baselineKey(table, id), updatedAt.toString());
  }

  static Future<Map<String, dynamic>?> _readCloudVersion(
    String table,
    String shopId,
    String id,
  ) async {
    final row = await SupabaseService.client
        .from(table)
        .select('updated_at,deleted_at')
        .eq('shop_id', shopId)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Insert new rows or compare-and-swap existing rows. The updated_at
  /// predicate makes the final write conditional, closing the race between
  /// checking a version and writing it.
  static Future<void> _writeVersionedRow(
    String table,
    String shopId,
    String id,
    Map<String, dynamic> payload, {
    bool allowInsert = true,
  }) async {
    final client = SupabaseService.client;
    final current = await _readCloudVersion(table, shopId, id);
    final baseline = Db.meta.get(_baselineKey(table, id))?.toString();

    if (current == null) {
      if (baseline != null) {
        throw StateError('SYNC_CONFLICT: $table/$id was removed from cloud.');
      }
      if (!allowInsert) {
        throw StateError('Cloud record $table/$id is missing; an administrator must sync it first.');
      }
      final inserted = await client
          .from(table)
          .insert(payload)
          .select('updated_at')
          .single();
      await _saveBaseline(table, id, inserted['updated_at']);
      return;
    }

    if (baseline == null ||
        baseline != current['updated_at']?.toString() ||
        false) {
      throw StateError(
        'SYNC_CONFLICT: $table/$id changed in cloud since this device last synchronized. Local changes were kept; cloud data was not overwritten.',
      );
    }

    final updatePayload = Map<String, dynamic>.from(payload)
      ..remove('shop_id')
      ..remove('id');
    final rows = await client
        .from(table)
        .update(updatePayload)
        .eq('shop_id', shopId)
        .eq('id', id)
        .eq('updated_at', current['updated_at'])
        .select('updated_at');
    if (rows.isEmpty) {
      throw StateError(
        'SYNC_CONFLICT: $table/$id changed during upload. Local changes were kept.',
      );
    }
    await _saveBaseline(table, id, rows.first['updated_at']);
  }

  static Future<void> _deleteVersionedRow(
    String table,
    String shopId,
    String id,
  ) async {
    final current = await _readCloudVersion(table, shopId, id);
    final baseline = Db.meta.get(_baselineKey(table, id))?.toString();
    if (current == null) {
      if (baseline == null) return; // A local create/delete never reached cloud.
      throw StateError('SYNC_CONFLICT: cloud record $table/$id no longer exists.');
    }
    if (baseline == null || baseline != current['updated_at']?.toString()) {
      throw StateError(
        'SYNC_CONFLICT: $table/$id changed in cloud; refusing to delete the newer version.',
      );
    }
    if (current['deleted_at'] != null) {
      await _saveBaseline(table, id, current['updated_at']);
      return;
    }
    final rows = await SupabaseService.client
        .from(table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('shop_id', shopId)
        .eq('id', id)
        .eq('updated_at', current['updated_at'])
        .select('updated_at');
    if (rows.isEmpty) {
      throw StateError('SYNC_CONFLICT: $table/$id changed during delete.');
    }
    await _saveBaseline(table, id, rows.first['updated_at']);
  }

  static Future<void> _writeShopSettings(String shopId) async {
    final client = SupabaseService.client;
    final current = await client
        .from('shop_settings')
        .select('updated_at')
        .eq('shop_id', shopId)
        .maybeSingle();
    const id = 'shop';
    final baseline = Db.meta.get(_baselineKey('shop_settings', id))?.toString();
    if (current == null) {
      if (baseline != null) {
        throw StateError('SYNC_CONFLICT: cloud shop settings were removed.');
      }
      final inserted = await client
          .from('shop_settings')
          .insert({'shop_id': shopId, 'settings': Db.settings.toMap()})
          .select('updated_at')
          .single();
      await _saveBaseline('shop_settings', id, inserted['updated_at']);
      return;
    }
    if (baseline == null || baseline != current['updated_at']?.toString()) {
      throw StateError(
        'SYNC_CONFLICT: shop settings changed in cloud. Local settings were kept.',
      );
    }
    final rows = await client
        .from('shop_settings')
        .update({'settings': Db.settings.toMap()})
        .eq('shop_id', shopId)
        .eq('updated_at', current['updated_at'])
        .select('updated_at');
    if (rows.isEmpty) {
      throw StateError('SYNC_CONFLICT: shop settings changed during upload.');
    }
    await _saveBaseline('shop_settings', id, rows.first['updated_at']);
  }

  static Future<void> _pushOne(
    String shopId,
    SyncOutboxChange change, {
    required Map<String, dynamic> permissions,
    required bool isAdmin,
  }) async {
    final client = SupabaseService.client;
    final table = change.tableName;
    if (table == 'shop_settings') {
      if (!isAdmin) {
        throw StateError('Only a shop administrator can sync shop settings.');
      }
      await _writeShopSettings(shopId);
      return;
    }
    if (change.operation == 'DELETE') {
      await _deleteVersionedRow(table, shopId, change.recordId);
      return;
    }

    switch (table) {
      case 'products':
        final product = Db.products.get(change.recordId);
        if (product == null) {
          throw StateError('Queued products record ${change.recordId} is missing locally.');
        }
        if (!isAdmin && permissions['inventory'] != true) {
          // Billing-only workers may synchronize stock changes, but only
          // against the exact cloud version previously pulled to this device.
          await _writeVersionedRow(
            'products',
            shopId,
            product.id,
            {'stock': _finite(product.stock)},
            allowInsert: false,
          );
        } else {
          await _writeVersionedRow('products', shopId, product.id, {
            'shop_id': shopId,
            'id': product.id,
            'name': product.name,
            'selling_price': _finite(product.sellingPrice),
            'cost_price': _finite(product.costPrice),
            'stock': _finite(product.stock),
            'unit': product.unit.name,
            'category': product.category,
            'sub_category': product.subCategory,
            'active': product.active,
            'barcode': product.barcode,
            'hsn_code': product.hsnCode,
            'gst_rate': product.gstRate == null ? null : _finite(product.gstRate!),
            'deleted_at': null,
          });
        }
        break;
      case 'sales':
        final sale = Db.sales.get(change.recordId);
        if (sale == null) {
          throw StateError('Queued sales record ${change.recordId} is missing locally.');
        }
        final expected = Db.meta.get(_baselineKey('sales', sale.id))?.toString();
        final updatedAt = await client.rpc('sync_sale_snapshot', params: {
          'p_shop_id': shopId,
          'p_expected_updated_at': expected,
          'p_sale': {
            'id': sale.id,
            'date': sale.date.toUtc().toIso8601String(),
            'total_amount': _finite(sale.totalAmount),
            'total_cost': _finite(sale.totalCost),
            'profit': _finite(sale.profit),
            'payment': sale.payment.name,
            'customer_name': sale.customerName,
            'customer_phone': sale.customerPhone,
            'discount': _finite(sale.discount),
            'gst_enabled': sale.gstEnabled,
            'gst_rate': _finite(sale.gstRate),
            'taxable_amount': _finite(sale.taxableAmount),
            'cgst_amount': _finite(sale.cgstAmount),
            'sgst_amount': _finite(sale.sgstAmount),
            'igst_amount': _finite(sale.igstAmount),
            'customer_gstin': sale.customerGstin,
            'interstate_sale': sale.interstateSale,
            'gst_inclusive': sale.gstInclusive,
          },
          'p_items': [
            for (var i = 0; i < sale.items.length; i++)
              _saleItemRow(i, sale.items[i]),
          ],
        });
        await _saveBaseline('sales', sale.id, updatedAt);
        break;
      case 'expenses':
        final expense = Db.expenses.get(change.recordId);
        if (expense == null) {
          throw StateError('Queued expenses record ${change.recordId} is missing locally.');
        }
        await _writeVersionedRow('expenses', shopId, expense.id, {
          'shop_id': shopId,
          'id': expense.id,
          'date': expense.date.toUtc().toIso8601String(),
          'category': expense.category,
          'amount': _finite(expense.amount),
          'description': expense.description,
          'deleted_at': null,
        });
        break;
      case 'employees':
        final employee = Db.employees.get(change.recordId);
        if (employee == null) {
          throw StateError('Queued employees record ${change.recordId} is missing locally.');
        }
        await _writeVersionedRow('employees', shopId, employee.id, {
          'shop_id': shopId,
          'id': employee.id,
          'name': employee.name,
          'type': employee.type,
          'wage': _finite(employee.wage),
          'attendance': employee.attendance,
          'salary_paid': employee.salaryPaid,
          'deleted_at': null,
        });
        break;
      default:
        throw StateError('Unsupported sync table: $table');
    }
  }

  static Map<String, dynamic> _saleItemRow(
    int position,
    SaleItem item,
  ) => {
        'position': position,
        'product_id': item.productId,
        'qty': _finite(item.qty),
        'selling_price': _finite(item.sellingPrice),
        'cost_price': _finite(item.costPrice),
        'subtotal': _finite(item.subtotal),
        'unit_label': item.unitLabel,
        'hsn_code': item.hsnCode,
        'gst_rate': item.gstRate == null ? null : _finite(item.gstRate!),
        'taxable_amount': _finite(item.taxableAmount),
        'cgst_amount': _finite(item.cgstAmount),
        'sgst_amount': _finite(item.sgstAmount),
        'igst_amount': _finite(item.igstAmount),
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

  /// Fetches only records changed since the persisted cursor. The server
  /// watermark bounds this pull: concurrent writes receive a later
  /// updated_at and are intentionally deferred to the next sync. A small
  /// overlap protects against timestamp precision/transport edge cases;
  /// applying duplicate rows is idempotent.
  static Future<List<Map<String, dynamic>>> _fetchChanged(
    String table,
    String shopId,
    DateTime highWater,
  ) async {
    final rows = <Map<String, dynamic>>[];
    final saved = Db.meta.get('sync_cursor_$table');
    DateTime? afterAt;
    var afterId = '';
    if (saved is Map && saved['updated_at'] is String) {
      afterAt = DateTime.parse(saved['updated_at'] as String)
          .toUtc()
          .subtract(const Duration(seconds: 5));
    }

    while (true) {
      final timestamp = afterAt?.toIso8601String();
      final base = SupabaseService.client
          .from(table)
          .select()
          .eq('shop_id', shopId)
          .lte('updated_at', highWater.toUtc().toIso8601String());
      final filtered = timestamp == null
          ? base
          : base.or(
              'updated_at.gt.$timestamp,and(updated_at.eq.$timestamp,id.gt.$afterId)',
            );
      final page = await filtered
          .order('updated_at')
          .order('id')
          .limit(_pageSize);
      final mapped = page
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      rows.addAll(mapped);
      if (mapped.length < _pageSize) break;
      final last = mapped.last;
      afterAt = DateTime.parse(last['updated_at'].toString()).toUtc();
      afterId = last['id'].toString();
    }
    return rows;
  }

  /// A sale row is the versioned parent for its complete line-item snapshot.
  /// Fetch all items for changed sales (not just changed item rows), because
  /// the local Sale model stores the whole snapshot as one object.
  static Future<List<Map<String, dynamic>>> _fetchItemsForSales(
    String shopId,
    List<String> saleIds,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; offset < saleIds.length; offset += 100) {
      final ids = saleIds.skip(offset).take(100).toList();
      final page = await SupabaseService.client
          .from('sale_items')
          .select()
          .eq('shop_id', shopId)
          .inFilter('sale_id', ids)
          .order('sale_id')
          .order('position');
      rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
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
    // Obtain one database-server watermark for the complete pull cycle.
    final rawWatermark = await SupabaseService.client.rpc('sync_pull_watermark');
    final highWater = DateTime.parse(rawWatermark.toString()).toUtc();
    final remote = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      remote[table] = await _fetchChanged(table, shopId, highWater);
    }

    final changedSaleIds = (remote['sales'] ?? const <Map<String, dynamic>>[])
        .where((row) => row['deleted_at'] == null)
        .map((row) => row['id'].toString())
        .toSet()
        .toList();
    final remoteItems = tables.contains('sales') && changedSaleIds.isNotEmpty
        ? await _fetchItemsForSales(shopId, changedSaleIds)
        : <Map<String, dynamic>>[];
    final itemsBySale = <String, List<Map<String, dynamic>>>{};
    for (final item in remoteItems) {
      final saleId = item['sale_id'].toString();
      (itemsBySale[saleId] ??= []).add(item);
    }

    Map<String, dynamic>? remoteSettings;
    Object? remoteSettingsUpdatedAt;
    if (isAdmin) {
      final settingsRows = await SupabaseService.client
          .from('shop_settings')
          .select('settings,updated_at')
          .eq('shop_id', shopId)
          .limit(1);
      if (settingsRows.isNotEmpty) {
        final raw = settingsRows.first['settings'];
        remoteSettingsUpdatedAt = settingsRows.first['updated_at'];
        if (raw is Map) remoteSettings = Map<String, dynamic>.from(raw);
      }
    }

    // Check the outbox per record rather than using a capped snapshot:
    // a large offline backlog must never be overwritten by a cloud pull.
    bool isLocallyDirty(String table, String id) =>
        Db.hasPendingSyncChange(table, id);
    var applied = 0;

    await Db.withoutOutbox(() async {
      for (final row in remote['products'] ?? const []) {
        final id = row['id'].toString();
        if (isLocallyDirty('products', id)) continue;
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
        if (isLocallyDirty('sales', id)) continue;
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
        if (isLocallyDirty('expenses', id)) continue;
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

      if (remoteSettings != null &&
          !Db.hasPendingSyncChange('shop_settings', 'shop')) {
        await Db.settings.clear();
        await Db.settings.putAll(remoteSettings);
        applied++;
      }

      for (final row in remote['employees'] ?? const []) {
        final id = row['id'].toString();
        if (isLocallyDirty('employees', id)) continue;
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

    // Persist the exact cloud version associated with each clean local row.
    // Dirty rows deliberately keep their older baseline so the next upload
    // detects a concurrent cloud edit instead of overwriting it.
    for (final table in tables) {
      for (final row in remote[table] ?? const <Map<String, dynamic>>[]) {
        final id = row['id'].toString();
        if (!Db.hasPendingSyncChange(table, id)) {
          await _saveBaseline(table, id, row['updated_at']);
        }
      }
    }
    if (remoteSettingsUpdatedAt != null &&
        !Db.hasPendingSyncChange('shop_settings', 'shop')) {
      await _saveBaseline(
        'shop_settings',
        'shop',
        remoteSettingsUpdatedAt,
      );
    }

    // Commit cursors only after every fetched row has been applied. If the app
    // exits earlier, the same bounded window is replayed safely next time.
    for (final table in tables) {
      await Db.meta.put('sync_cursor_$table', {
        'updated_at': highWater.toIso8601String(),
      });
    }
    return applied;
  }
}

class CloudSyncSummary {
  const CloudSyncSummary({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
