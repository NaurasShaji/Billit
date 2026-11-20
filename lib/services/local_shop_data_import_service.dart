import '../data/database.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'supabase_service.dart';

/// One-time, explicit copy from the original on-device database into a shop's
/// isolated local database. The original database is never deleted or changed.
class LocalShopDataImportService {
  LocalShopDataImportService._();

  static Future<LocalShopDataImportPreview> preview() async {
    await Db.openLocalDatabase();
    try {
      return LocalShopDataImportPreview(
        products: Db.products.length,
        sales: Db.sales.length,
        expenses: Db.expenses.length,
        employees: Db.employees.length,
      );
    } finally {
      // The caller must pass the shop id to import; preview is read-only and
      // intentionally leaves the original database open.
    }
  }

  static Future<LocalShopDataImportPreview> importIntoShop({
    required String shopId,
    required bool isAdmin,
  }) async {
    if (!isAdmin) throw StateError('Only a shop administrator can import data.');
    if (!SupabaseService.isConfigured) throw StateError('Supabase is not configured.');

    // Never merge a device snapshot into a shop that already has cloud data.
    for (final table in ['products', 'sales', 'expenses', 'employees']) {
      final existing = await SupabaseService.client
          .from(table)
          .select('id')
          .eq('shop_id', shopId)
          .limit(1);
      if (existing.isNotEmpty) {
        throw StateError(
          'This shop already contains cloud $table. Import is blocked to prevent duplicate or overwritten records.',
        );
      }
    }

    final previousKey = Db.activeDatabaseKey;
    if (previousKey != 'shop:$shopId') {
      throw StateError('The selected shop database is not active.');
    }

    List<Product> products = [];
    List<Sale> sales = [];
    List<Expense> expenses = [];
    List<Employee> employees = [];
    Map<String, dynamic> settings = {};

    try {
      await Db.openLocalDatabase();
      products = Db.products.values
          .map((item) => Product.fromJson(item.toJson()))
          .toList();
      sales = Db.sales.values
          .map((item) => Sale.fromJson(item.toJson()))
          .toList();
      expenses = Db.expenses.values
          .map((item) => Expense.fromJson(item.toJson()))
          .toList();
      employees = Db.employees.values
          .map((item) => Employee.fromJson(item.toJson()))
          .toList();
      settings = Db.settings.toMap();
    } finally {
      await Db.openTenantDatabase(shopId);
    }

    if (products.isEmpty && sales.isEmpty && expenses.isEmpty && employees.isEmpty) {
      throw StateError('No products, sales, expenses or employees were found in the original local database.');
    }

    final productIds = products.map((item) => item.id).toSet();
    final missingProductIds = <String>{
      for (final sale in sales)
        for (final item in sale.items)
          if (!productIds.contains(item.productId)) item.productId,
    };
    if (missingProductIds.isNotEmpty) {
      throw StateError(
        'Some historical sales refer to products missing from the local product list. Import stopped to preserve sale integrity.',
      );
    }

    if (Db.meta.containsKey('legacy_local_import')) {
      throw StateError('This shop has already received a local-data import.');
    }
    if (Db.products.isNotEmpty || Db.sales.isNotEmpty ||
        Db.expenses.isNotEmpty || Db.employees.isNotEmpty) {
      throw StateError('This shop already has local records. Import is blocked.');
    }

    await Db.transaction(() async {
      await Db.products.addAll(products);
      // Local user IDs do not exist in Supabase Auth. Keep the sale history but
      // clear the device-specific cashier reference during the migration.
      for (final sale in sales) {
        sale.userId = '';
      }
      await Db.sales.addAll(sales);
      await Db.expenses.addAll(expenses);
      await Db.employees.addAll(employees);
      await Db.settings.putAll(settings);
      await Db.meta.put('legacy_local_import', {
        'at': DateTime.now().toUtc().toIso8601String(),
        'source': 'billit.db',
        'products': products.length,
        'sales': sales.length,
        'expenses': expenses.length,
        'employees': employees.length,
      });
    });

    return LocalShopDataImportPreview(
      products: products.length,
      sales: sales.length,
      expenses: expenses.length,
      employees: employees.length,
    );
  }
}

class LocalShopDataImportPreview {
  const LocalShopDataImportPreview({
    required this.products,
    required this.sales,
    required this.expenses,
    required this.employees,
  });

  final int products;
  final int sales;
  final int expenses;
  final int employees;

  int get total => products + sales + expenses + employees;
}
