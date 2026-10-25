import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _GoogleAuthClient(this._headers, [http.Client? client]) : _client = client ?? http.Client();

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

class DriveBackupService {
  DriveBackupService._internal();
  static final DriveBackupService instance = DriveBackupService._internal();

  static const String _backupFolderName = 'FloralBillingBackups';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn({bool interactive = true}) async {
    try {
      final user = await _googleSignIn.signInSilently();
      if (user != null) return user;
      if (!interactive) return null;
      return _googleSignIn.signIn();
    } catch (e) {
      if (!interactive) return null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<drive.DriveApi> _getDriveApi({bool interactive = true}) async {
    final user = _googleSignIn.currentUser ?? await signIn(interactive: interactive);
    if (user == null) {
      throw StateError('Not signed in to Google Drive');
    }
    final headers = await user.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  Future<String> _ensureBackupFolderId(drive.DriveApi api) async {
    final existing = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$_backupFolderName' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageSize: 1,
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }
    final created = await api.files.create(
      drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    return created.id!;
  }

  Future<void> uploadJson({required String filename, required Map<String, dynamic> json}) async {
    final api = await _getDriveApi();
    final folderId = await _ensureBackupFolderId(api);

    final mediaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    final media = drive.Media(Stream<List<int>>.value(mediaBytes), mediaBytes.length);

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
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
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


