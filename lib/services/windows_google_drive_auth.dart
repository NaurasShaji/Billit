import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WindowsDriveAccount {
  final String email;
  const WindowsDriveAccount(this.email);
}

/// OAuth 2.0 authorization-code + PKCE flow for the Windows desktop app.
/// Configure GOOGLE_DESKTOP_CLIENT_ID with a Google OAuth Desktop client ID.
class WindowsGoogleDriveAuth {
  WindowsGoogleDriveAuth._();
  static final WindowsGoogleDriveAuth instance = WindowsGoogleDriveAuth._();

  static const _clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const _clientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');
  static const _scope =
      'https://www.googleapis.com/auth/drive.file openid email';
  static const _storage = FlutterSecureStorage();

  static const _refreshTokenKey = 'billit_drive_refresh_token';
  static const _accessTokenKey = 'billit_drive_access_token';
  static const _expiresAtKey = 'billit_drive_access_expires_at';
  static const _emailKey = 'billit_drive_account_email';

  String? _accessToken;
  DateTime? _expiresAt;
  WindowsDriveAccount? _account;

  WindowsDriveAccount? get currentUser => _account;

  Future<WindowsDriveAccount?> signIn({bool interactive = true}) async {
    if (await _restoreSession()) return _account;
    if (!interactive) return null;
    if (_clientId.isEmpty) {
      throw StateError(
        'Windows Google Drive is not configured. Build with '
        '--dart-define=GOOGLE_DESKTOP_CLIENT_ID=your-desktop-client-id.',
      );
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/oauth2callback';
    final state = _randomUrlSafe(32);
    final verifier = _randomUrlSafe(64);
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final callback = Completer<Map<String, String>>();

    final subscription = server.listen((request) async {
      final params = request.uri.queryParameters;
      if (!callback.isCompleted) {
        if (params['state'] != state) {
          callback.completeError(StateError('Google sign-in state mismatch.'));
        } else if (params['error'] != null) {
          callback.completeError(StateError(
              'Google sign-in failed: ${params['error']}'));
        } else if (params['code'] != null) {
          callback.complete(params);
        } else {
          callback.completeError(
              StateError('Google did not return an authorization code.'));
        }
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<html><body><h2>Billit connected</h2>'
            '<p>You can close this browser window and return to Billit.</p>'
            '</body></html>');
      await request.response.close();
    });

    try {
      final authorizationUri = Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
        {
          'client_id': _clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': _scope,
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );
      final launched = await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Could not open the default browser for Google sign-in.');
      }

      final result = await callback.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Google sign-in timed out.'),
      );
      final response = await http.post(
        Uri.https('oauth2.googleapis.com', '/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': result['code']!,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
          if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
        },
      );
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Google token exchange failed: ${response.body}');
      }
      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
      final refreshToken = tokenData['refresh_token'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
      await _saveAccessToken(tokenData);
      await _loadAccountEmail();
      return _account;
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<bool> _restoreSession() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      await _refreshAccessToken(refreshToken);
      await _loadAccountEmail();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshAccessToken(String refreshToken) async {
    final response = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
        if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Google Drive session expired. Please reconnect.');
    }
    await _saveAccessToken(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> _saveAccessToken(Map<String, dynamic> tokenData) async {
    final token = tokenData['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not return an access token.');
    }
    final expiresIn = (tokenData['expires_in'] as num?)?.toInt() ?? 3600;
    _accessToken = token;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(
      key: _expiresAtKey,
      value: _expiresAt!.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> _loadAccountEmail() async {
    final token = _accessToken;
    if (token == null) return;
    final response = await http.get(
      Uri.https('www.googleapis.com', '/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final email = data['email'] as String?;
      if (email != null && email.isNotEmpty) {
        _account = WindowsDriveAccount(email);
        await _storage.write(key: _emailKey, value: email);
      }
    }
    if (_account == null) {
      final savedEmail = await _storage.read(key: _emailKey);
      _account = WindowsDriveAccount(savedEmail ?? 'Google account');
    }
  }

  Future<Map<String, String>> get authHeaders async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Not signed in to Google Drive.');
    }
    if (_accessToken == null ||
        _expiresAt == null ||
        DateTime.now().isAfter(
            _expiresAt!.subtract(const Duration(minutes: 2)))) {
      await _refreshAccessToken(refreshToken);
    }
    return {'Authorization': 'Bearer $_accessToken'};
  }

  Future<bool> isSignedIn() async {
    if (_accessToken != null &&
        _expiresAt != null &&
        DateTime.now().isBefore(_expiresAt!)) {
      return true;
    }
    return _restoreSession();
  }

  Future<void> signOut() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.https('oauth2.googleapis.com', '/revoke'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'token': refreshToken},
        );
      } catch (_) {
        // Local credentials are cleared even if revocation cannot reach Google.
      }
    }
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _emailKey);
    _accessToken = null;
    _expiresAt = null;
    _account = null;
  }

  String _randomUrlSafe(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
