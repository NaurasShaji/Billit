import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional Supabase bootstrap.
///
/// Configure with:
/// --dart-define=SUPABASE_URL=https://<project>.supabase.co
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
///
/// The publishable key is safe to include in a client app when Row Level
/// Security is enabled. Never put a service-role/secret key here.
class SupabaseService {
  SupabaseService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      _url.startsWith('https://') && _publishableKey.isNotEmpty;

  static bool get isInitialized => isConfigured;

  static SupabaseClient get client {
    if (!isConfigured) {
      throw StateError('Supabase is not configured for this build.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        'Supabase is not configured. Billit will continue in local mode.',
      );
      return;
    }

    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
    );
  }
}
