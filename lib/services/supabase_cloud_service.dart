import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'boxes.dart';

/// Optional Supabase snapshot backup for Floral Bill.
///
/// Configure at build time:
/// flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
///
/// No service-role or secret key belongs in a client application.
class SupabaseCloudService {
  SupabaseCloudService._();
  static final SupabaseCloudService instance = SupabaseCloudService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _defaultSnapshotId = 'default';

  bool _initialized = false;
  String? _initializationError;

  bool get isConfigured => _url.startsWith('https://') &&
      _publishableKey.isNotEmpty;
  bool get isAvailable => _initialized; 
  bool get hasSignedInUser =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
  bool get isInitialized => _initialized;
  String? get initializationError => _initializationError;

  Future<void> initializeFromBuildConfig() async {
    if (_initialized || !isConfigured) return;
    try {
      await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
      );
      _initialized = true;
    } catch (error) {
      // Do not prevent local/offline use if cloud configuration is invalid.
      _initializationError = error.toString();
    }
  }

  SupabaseClient get _client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY at build time, then restart the app.',
      );
    }
    return Supabase.instance.client;
  }


  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    if (_initialized) await Supabase.instance.client.auth.signOut();
  }

  Box<T> _box<T>(String name) => Hive.box<T>(name);

  Map<String, dynamic> _exportSnapshot() {
    return {
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'products': _box<Product>(Boxes.products).values
          .map((item) => item.toJson()).toList(),
      'sales': _box<Sale>(Boxes.sales).values
          .map((item) => item.toJson()).toList(),
      'expenses': _box<Expense>(Boxes.expenses).values
          .map((item) => item.toJson()).toList(),
      'employees': _box<Employee>(Boxes.employees).values
          .map((item) => item.toJson()).toList(),
      'app_settings': _box<dynamic>('app_settings').toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  /// Uploads a full snapshot into a single row. Manual snapshots intentionally
  /// avoid claiming real-time or conflict-free multi-device synchronization.
  Future<void> uploadCurrentData() async {
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'No Supabase user is signed in. Complete Supabase sign-in first; '
        'your existing local admin/worker login is not a Supabase account.',
      );
    }
    final snapshot = _exportSnapshot();
    await client.from('floral_bill_snapshots').upsert({
      'snapshot_id': _defaultSnapshotId,
      'owner_id': user.id,
      'payload': snapshot,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'snapshot_id');
  }

  /// Restore only after confirmation in the UI. Snapshot belongs to the
  /// currently signed-in Supabase account (enforced by the database RLS).
  Future<void> restoreCurrentData() async {
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in with Supabase before restoring cloud data.');
    }

    final row = await client
        .from('floral_bill_snapshots')
        .select('payload, owner_id')
        .eq('snapshot_id', _defaultSnapshotId)
        .maybeSingle();

    if (row == null) {
      throw StateError('No cloud snapshot exists for this account yet.');
    }
    if (row['owner_id'] != user.id) {
      throw StateError('This cloud snapshot belongs to another account.');
    }
    final rawPayload = row['payload'];
    if (rawPayload is! Map) {
      throw const FormatException('Cloud snapshot has an invalid format.');
    }
    final payload = Map<String, dynamic>.from(rawPayload);
    if (payload['schema_version'] != 1) {
      throw const FormatException('Unsupported cloud snapshot version.');
    }

    // Parse and validate everything before clearing local data.
    final products = _listOfMaps(payload['products'])
        .map(Product.fromJson).toList();
    final sales = _listOfMaps(payload['sales']).map(Sale.fromJson).toList();
    final expenses = _listOfMaps(payload['expenses'])
        .map(Expense.fromJson).toList();
    final employees = _listOfMaps(payload['employees'])
        .map(Employee.fromJson).toList();

    if (products.map((item) => item.id).toSet().length != products.length ||
        sales.map((item) => item.id).toSet().length != sales.length ||
        expenses.map((item) => item.id).toSet().length != expenses.length ||
        employees.map((item) => item.id).toSet().length != employees.length) {
      throw const FormatException('Cloud snapshot contains duplicate record IDs.');
    }
    final settingsRaw = payload['app_settings'];
    final appSettings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};

    await _box<Product>(Boxes.products).clear();
    await _box<Sale>(Boxes.sales).clear();
    await _box<Expense>(Boxes.expenses).clear();
    await _box<Employee>(Boxes.employees).clear();
    await _box<Product>(Boxes.products).putAll({
      for (final item in products) item.id: item,
    });
    await _box<Sale>(Boxes.sales).putAll({
      for (final item in sales) item.id: item,
    });
    await _box<Expense>(Boxes.expenses).putAll({
      for (final item in expenses) item.id: item,
    });
    await _box<Employee>(Boxes.employees).putAll({
      for (final item in employees) item.id: item,
    });
    await Hive.box<dynamic>('app_settings').putAll(appSettings);
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid item in cloud snapshot.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }
}
