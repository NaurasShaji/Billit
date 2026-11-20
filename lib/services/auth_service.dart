import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/models.dart';
import '../data/database.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  User? currentUser;

  /// Selected tenant for the current cloud session.
  String? currentShopId;
  String? currentShopName;
  List<Map<String, String>> availableShops = const [];
  Map<String, dynamic> _permissions = const {};

  static const String _sessionUserIdKey = 'user_id';

  bool get isCloudAuth => SupabaseService.isConfigured;
  bool get isPlatformOwner => _isPlatformOwner;
  bool _isPlatformOwner = false;

  /// Local demo accounts are retained only for builds without Supabase
  /// configuration. Cloud deployments must never create shared default users.
  Future<void> ensureSeedUsers() async {
    if (SupabaseService.isConfigured) return;

    final usersBox = Db.users;
    if (usersBox.values.where((u) => u.userType == UserType.admin).isEmpty) {
      final admin = User()
        ..id = 'admin'
        ..username = 'admin'
        ..password = User.hash('admin123')
        ..userType = UserType.admin
        ..securityAnswer = 'Buddy';
      await usersBox.put(admin.id, admin);
    }

    if (usersBox.values.where((u) => u.userType == UserType.worker).isEmpty) {
      final worker = User()
        ..id = 'worker'
        ..username = 'worker'
        ..password = User.hash('worker123')
        ..userType = UserType.worker;
      await usersBox.put(worker.id, worker);
    }
  }

  Future<void> restoreSessionIfAny() async {
    if (SupabaseService.isConfigured) {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) return;
      try {
        await _loadCloudIdentity(session.user.id);
      } catch (error) {
        debugPrint('Could not restore Billit cloud session: $error');
        await SupabaseService.client.auth.signOut();
        _clearIdentity();
      }
      return;
    }

    final userId = Db.session.get(_sessionUserIdKey) as String?;
    if (userId == null) return;
    final user = Db.users.get(userId);
    if (user != null) {
      currentUser = user;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password,
      {UserType? userType}) async {
    if (SupabaseService.isConfigured) {
      try {
        final response = await SupabaseService.client.auth.signInWithPassword(
          email: username.trim(),
          password: password,
        );
        final user = response.user;
        if (user == null) return false;
        await _loadCloudIdentity(user.id);
        return true;
      } on AuthException catch (error) {
        debugPrint('Supabase sign-in failed: ${error.message}');
        return false;
      } catch (error) {
        debugPrint('Billit cloud identity loading failed: $error');
        await SupabaseService.client.auth.signOut();
        _clearIdentity();
        rethrow;
      }
    }

    final usersBox = Db.users;
    try {
      final user = usersBox.values.firstWhere(
        (u) =>
            u.username == username &&
            (userType == null || u.userType == userType),
      );
      if (user.password == User.hash(password)) {
        currentUser = user;
        currentShopId = null;
        currentShopName = null;
        _permissions = const {};
        _isPlatformOwner = false;
        await Db.session.put(_sessionUserIdKey, user.id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadCloudIdentity(String authUserId, {String? preferredShopId}) async {
    final client = SupabaseService.client;

    final profile = await client
        .from('profiles')
        .select('display_name, is_platform_owner')
        .eq('id', authUserId)
        .maybeSingle();

    if (profile == null) {
      throw StateError('Your account profile is missing. Contact the platform administrator.');
    }

    _isPlatformOwner = profile['is_platform_owner'] == true;

    String? shopId;
    String? shopName;
    String role = 'worker';
    Map<String, dynamic> permissions = const {};

    List<Map<String, String>> shopChoices = [];
    if (_isPlatformOwner) {
      final shops = await client
          .from('shops')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      shopChoices = shops.map((shop) => {
        'id': shop['id'].toString(),
        'name': shop['name'].toString(),
      }).toList();
      final selected = shopChoices.where((shop) => shop['id'] == preferredShopId).firstOrNull
          ?? (shopChoices.isEmpty ? null : shopChoices.first);
      if (selected != null) {
        shopId = selected['id'];
        shopName = selected['name'];
        role = 'shop_admin';
      }
    } else {
      final memberships = await client
          .from('shop_memberships')
          .select('shop_id, role, permissions, shops(name, is_active)')
          .eq('user_id', authUserId)
          .eq('is_active', true);

      final activeMemberships = memberships.where((membership) {
        final shop = membership['shops'];
        return shop is Map && shop['is_active'] == true;
      }).toList();

      shopChoices = activeMemberships.map((membership) {
        final shop = membership['shops'] as Map;
        return {
          'id': membership['shop_id'].toString(),
          'name': shop['name']?.toString() ?? 'Shop',
        };
      }).toList();
      final selectedShop = shopChoices.where((shop) => shop['id'] == preferredShopId).firstOrNull
          ?? (shopChoices.isEmpty ? null : shopChoices.first);
      if (selectedShop != null) {
        final membership = activeMemberships.firstWhere(
          (item) => item['shop_id'].toString() == selectedShop['id'],
        );
        final shop = membership['shops'] as Map;
        shopId = membership['shop_id'] as String;
        shopName = shop['name']?.toString();
        role = membership['role']?.toString() ?? 'worker';
        final rawPermissions = membership['permissions'];
        if (rawPermissions is Map) {
          permissions = Map<String, dynamic>.from(rawPermissions);
        }
      }
    }

    if (shopId == null && !_isPlatformOwner) {
      throw StateError('Your account is not assigned to an active shop. Contact your shop administrator.');
    }

    final authUser = client.auth.currentUser;
    final displayName = profile['display_name']?.toString().trim();
    final email = authUser?.email ?? '';
    final localUser = User()
      ..id = authUserId
      ..username = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : email
      ..password = ''
      ..userType = role == 'shop_admin' ? UserType.admin : UserType.worker;

    currentUser = localUser;
    currentShopId = shopId;
    currentShopName = shopName;
    availableShops = shopChoices;
    _permissions = permissions;
    await Db.session.delete(_sessionUserIdKey);
    notifyListeners();
  }

  void _clearIdentity() {
    currentUser = null;
    currentShopId = null;
    currentShopName = null;
    availableShops = const [];
    _permissions = const {};
    _isPlatformOwner = false;
    notifyListeners();
  }

  Future<void> switchShop(String shopId) async {
    if (!SupabaseService.isConfigured || SupabaseService.client.auth.currentUser == null) {
      throw StateError('No cloud session is active.');
    }
    await _loadCloudIdentity(
      SupabaseService.client.auth.currentUser!.id,
      preferredShopId: shopId,
    );
  }

  Future<void> logout() async {
    if (SupabaseService.isConfigured) {
      await SupabaseService.client.auth.signOut();
    } else {
      await Db.session.delete(_sessionUserIdKey);
    }
    _clearIdentity();
  }

  bool get isAdmin => _isPlatformOwner || currentUser?.userType == UserType.admin;
  bool get isWorker => currentUser?.userType == UserType.worker;
  bool get isLoggedIn => currentUser != null;

  bool hasPermission(String key) {
    if (isAdmin) return true;
    if (!isCloudAuth) {
      // Preserve the existing local worker experience in local-only builds.
      return key == 'billing' || key == 'inventory' || key == 'reports';
    }
    return _permissions[key] == true;
  }

  /// Password changes in cloud mode must be handled by Supabase Auth.
  Future<void> changePassword(String newPassword,
      {String? targetUserId, String? currentPassword}) async {
    if (currentUser == null) throw Exception('User not logged in');
    if (!isAdmin) throw Exception('Permission denied: administrator access required');
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }

    if (isCloudAuth) {
      if (targetUserId != null && targetUserId != currentUser!.id) {
        throw Exception('Changing another cloud user password requires the secure account-management function.');
      }
      await SupabaseService.client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(newPassword)) {
      throw Exception('Password can only contain letters and numbers (no special characters)');
    }

    final userToChangeId = targetUserId ?? currentUser!.id;
    final user = Db.users.get(userToChangeId);
    if (user == null) throw Exception('User not found');

    if (targetUserId == null || targetUserId == currentUser!.id) {
      if (currentPassword == null) {
        throw Exception('Current password is required when changing your own password');
      }
      if (user.password != User.hash(currentPassword)) {
        throw Exception('Incorrect current password');
      }
    }

    user.password = User.hash(newPassword);
    await user.save();
    if (userToChangeId == currentUser!.id) currentUser = user;
    notifyListeners();
  }

  List<User> getAllUsers() {
    if (!isAdmin || isCloudAuth) return [];
    return Db.users.values.toList();
  }

  String getAdminSecurityQuestion() {
    if (isCloudAuth) {
      throw Exception('Cloud accounts use email password recovery.');
    }
    final admin = Db.users.values.firstWhere(
      (user) => user.userType == UserType.admin,
      orElse: () => throw Exception('Admin account not found'),
    );
    return admin.securityQuestion;
  }

  Future<void> sendPasswordReset(String email) async {
    if (!isCloudAuth) {
      throw Exception('Use the local security-question recovery for this installation.');
    }
    await SupabaseService.client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> updateAdminSecurityQuestion({
    required String currentPassword,
    required String question,
    required String answer,
  }) async {
    if (isCloudAuth) {
      throw Exception('Security questions are not used for cloud accounts. Use email password recovery.');
    }
    if (!isAdmin || currentUser == null) {
      throw Exception('Only the signed-in administrator can update this setting');
    }
    if (currentUser!.password != User.hash(currentPassword)) {
      throw Exception('Current password is incorrect');
    }
    if (question.trim().isEmpty || answer.trim().isEmpty) {
      throw Exception('Choose a question and enter its answer');
    }
    currentUser!
      ..securityQuestion = question.trim()
      ..securityAnswer = answer.trim();
    await currentUser!.save();
    notifyListeners();
  }

  Future<void> resetAdminPassword(String securityAnswer, String newPassword) async {
    if (isCloudAuth) {
      throw Exception('Cloud accounts must use the email password recovery link.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }

    final adminUser = Db.users.values.firstWhere(
      (u) =>
          u.userType == UserType.admin &&
          u.securityAnswer.toLowerCase() == securityAnswer.toLowerCase(),
      orElse: () => throw Exception('Incorrect answer to security question'),
    );
    adminUser.password = User.hash(newPassword);
    await adminUser.save();
    if (currentUser?.id == adminUser.id) {
      currentUser = adminUser;
      notifyListeners();
    }
  }
}
