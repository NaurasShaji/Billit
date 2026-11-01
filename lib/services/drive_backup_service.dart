import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'windows_google_drive_auth.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _GoogleAuthClient(this._headers, [http.Client? client])
      : _client = client ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class DriveFileEntry {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  const DriveFileEntry({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.sizeBytes,
  });
}

class DriveAccount {
  final String? displayName;
  final String? email;

  const DriveAccount({this.displayName, this.email});
}

class DriveBackupService {
  DriveBackupService._internal();
  static final DriveBackupService instance = DriveBackupService._internal();

  static const String _backupFolderName = 'Billit';
  static const String _legacyBackupFolderName = 'FloralBillingBackups';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      drive.DriveApi.driveFileScope,
    ],
  );

  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  DriveAccount? get currentUser {
    if (_isWindows) {
      final account = WindowsGoogleDriveAuth.instance.currentUser;
      return account == null ? null : DriveAccount(email: account.email);
    }
    final account = _googleSignIn.currentUser;
    return account == null
        ? null
        : DriveAccount(displayName: account.displayName, email: account.email);
  }

  Future<DriveAccount?> signIn({bool interactive = true}) async {
    if (_isWindows) {
      final account = await WindowsGoogleDriveAuth.instance
          .signIn(interactive: interactive);
      return account == null ? null : DriveAccount(email: account.email);
    }
    try {
      final user = await _googleSignIn.signInSilently();
      if (user != null) {
        return DriveAccount(
            displayName: user.displayName, email: user.email);
      }
      if (!interactive) return null;
      final signedInUser = await _googleSignIn.signIn();
      return signedInUser == null
          ? null
          : DriveAccount(
              displayName: signedInUser.displayName,
              email: signedInUser.email,
            );
    } catch (e) {
      if (!interactive) return null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_isWindows) {
      await WindowsGoogleDriveAuth.instance.signOut();
      return;
    }
    await _googleSignIn.disconnect();
  }

  Future<bool> isSignedIn() async {
    if (_isWindows) {
      return WindowsGoogleDriveAuth.instance.isSignedIn();
    }
    return _googleSignIn.isSignedIn();
  }

  Future<drive.DriveApi> _getDriveApi({bool interactive = true}) async {
    if (_isWindows) {
      if (WindowsGoogleDriveAuth.instance.currentUser == null) {
        await WindowsGoogleDriveAuth.instance.signIn(
            interactive: interactive);
      }
      final headers =
          await WindowsGoogleDriveAuth.instance.authHeaders;
      return drive.DriveApi(_GoogleAuthClient(headers));
    }

    final user = _googleSignIn.currentUser;
    final signedInUser = user ??
        (await signIn(interactive: interactive)) == null
            ? null
            : _googleSignIn.currentUser;
    if (signedInUser == null) {
      throw StateError('Not signed in to Google Drive');
    }
    final headers = await signedInUser.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<String> _ensureBackupFolderId(drive.DriveApi api) async {
    Future<drive.File?> findFolder(String name) async {
      final result = await api.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
        pageSize: 1,
      );
      return result.files?.isNotEmpty == true ? result.files!.first : null;
    }

    final billitFolder = await findFolder(_backupFolderName);
    if (billitFolder?.id != null) return billitFolder!.id!;

    // Rename the existing Android backup folder instead of creating a new
    // folder, so previously uploaded backups remain available.
    final legacyFolder = await findFolder(_legacyBackupFolderName);
    if (legacyFolder?.id != null) {
      await api.files.update(
        drive.File()..name = _backupFolderName,
        legacyFolder.id!,
      );
      return legacyFolder.id!;
    }

    final created = await api.files.create(
      drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    return created.id!;
  }

  Future<void> uploadJson(
      {required String filename, required Map<String, dynamic> json}) async {
    final api = await _getDriveApi();
    final folderId = await _ensureBackupFolderId(api);

    final mediaBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    final media =
        drive.Media(Stream<List<int>>.value(mediaBytes), mediaBytes.length);

    final fileMetadata = drive.File()
      ..name = filename
      ..parents = <String>[folderId]
      ..mimeType = 'application/json';

    await api.files.create(
      fileMetadata,
      uploadMedia: media,
      $fields: 'id',
    );
  }

  Future<List<DriveFileEntry>> listBackups({int pageSize = 20}) async {
    final api = await _getDriveApi();
    final folderId = await _ensureBackupFolderId(api);
    final res = await api.files.list(
      q: "'${folderId.replaceAll("'", "\\'")}' in parents and mimeType='application/json' and trashed=false",
      orderBy: 'modifiedTime desc',
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime, size)',
      pageSize: pageSize,
    );
    final files = res.files ?? <drive.File>[];
    return files
        .where((f) => f.id != null && f.name != null)
        .map((f) => DriveFileEntry(
              id: f.id!,
              name: f.name!,
              modifiedTime: f.modifiedTime,
              sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
            ))
        .toList();
  }

  Future<Map<String, dynamic>> downloadJson(String fileId) async {
    final api = await _getDriveApi();
    final media = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytesBuilder = BytesBuilder();
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    final content = utf8.decode(bytesBuilder.takeBytes());
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw StateError('Unexpected JSON format');
  }
}
