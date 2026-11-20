import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CloudAccountService {
  CloudAccountService._();

  static Future<Map<String, dynamic>> createShop({
    required String shopName,
    required String adminEmail,
    required String adminPassword,
    String adminName = '',
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'manage-account',
      body: {
        'action': 'create_shop',
        'shop_name': shopName,
        'admin_email': adminEmail,
        'admin_password': adminPassword,
        'admin_name': adminName,
      },
    );
    return _readResponse(response);
  }

  static Future<Map<String, dynamic>> createWorker({
    required String shopId,
    required String email,
    required String password,
    required String displayName,
    required Map<String, bool> permissions,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'manage-account',
      body: {
        'action': 'create_worker',
        'shop_id': shopId,
        'email': email,
        'password': password,
        'display_name': displayName,
        'permissions': permissions,
      },
    );
    return _readResponse(response);
  }

  static Future<List<Map<String, dynamic>>> listMembers(String shopId) async {
    final response = await SupabaseService.client.functions.invoke(
      'manage-account',
      body: {'action': 'list_members', 'shop_id': shopId},
    );
    final data = _readResponse(response);
    final members = data['members'];
    if (members is! List) return [];
    return members
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
  }

  static Future<void> updateWorkerPermissions({
    required String shopId,
    required String userId,
    required Map<String, bool> permissions,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'manage-account',
      body: {
        'action': 'update_worker_permissions',
        'shop_id': shopId,
        'user_id': userId,
        'permissions': permissions,
      },
    );
    _readResponse(response);
  }

  static Future<void> disableWorker({
    required String shopId,
    required String userId,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'manage-account',
      body: {
        'action': 'disable_worker',
        'shop_id': shopId,
        'user_id': userId,
      },
    );
    _readResponse(response);
  }

  static Map<String, dynamic> _readResponse(FunctionResponse response) {
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'Account operation failed.');
    }
    if (data is Map) {
      if (data['error'] != null) throw Exception(data['error'].toString());
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Unexpected response from account service.');
  }
}
