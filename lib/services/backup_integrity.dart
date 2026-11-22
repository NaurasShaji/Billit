import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Adds and verifies integrity metadata for Billit JSON backups.
///
/// Backups created before integrity metadata was introduced remain readable,
/// but new backups must pass SHA-256 and record-count validation.
class BackupIntegrity {
  BackupIntegrity._();

  static const int currentFormatVersion = 1;
  static const String _algorithm = 'SHA-256';
  static const List<String> _recordCollections = [
    'users',
    'products',
    'sales',
    'expenses',
    'employees',
  ];

  static Map<String, dynamic> seal(Map<String, dynamic> payload) {
    final backup = _copyWithoutIntegrity(payload);
    final meta = Map<String, dynamic>.from(backup['meta'] as Map? ?? const {});
    meta['backupFormatVersion'] = currentFormatVersion;
    meta['recordCounts'] = {
      for (final key in _recordCollections)
        key: (backup[key] as List).length,
    };
    backup['meta'] = meta;
    final digest = _digest(backup);
    backup['integrity'] = {
      'algorithm': _algorithm,
      'checksum': digest,
    };
    validate(backup);
    return backup;
  }

  /// Throws [FormatException] before restore code mutates the database.
  /// Older backups without an integrity block are structurally validated.
  static void validate(Map<String, dynamic> payload) {
    final metaValue = payload['meta'];
    if (metaValue is! Map) {
      throw const FormatException('Backup metadata is missing or invalid.');
    }

    for (final key in [..._recordCollections, 'appSettings']) {
      if (!payload.containsKey(key)) {
        throw FormatException('Backup is missing required section: $key.');
      }
    }

    for (final key in _recordCollections) {
      final value = payload[key];
      if (value is! List) {
        throw FormatException('Backup section "$key" must be a list.');
      }
      final ids = <String>{};
      for (final item in value) {
        if (item is! Map || item['id'] is! String ||
            (item['id'] as String).trim().isEmpty) {
          throw FormatException('Backup section "$key" contains an invalid record.');
        }
        if (!ids.add(item['id'] as String)) {
          throw FormatException('Backup section "$key" contains duplicate IDs.');
        }
      }
    }

    if (payload['appSettings'] is! Map) {
      throw const FormatException('Backup app settings are invalid.');
    }

    final formatVersion = metaValue['backupFormatVersion'];
    if (formatVersion is num && formatVersion > currentFormatVersion) {
      throw FormatException(
        'This backup uses a newer format (version $formatVersion). Update Billit before restoring it.',
      );
    }

    final integrityValue = payload['integrity'];
    if (integrityValue == null) return; // Legacy backup.
    if (integrityValue is! Map ||
        integrityValue['algorithm'] != _algorithm ||
        integrityValue['checksum'] is! String) {
      throw const FormatException('Backup integrity information is invalid.');
    }

    final counts = metaValue['recordCounts'];
    if (counts is! Map) {
      throw const FormatException('Backup record counts are missing.');
    }
    for (final key in _recordCollections) {
      if (counts[key] != (payload[key] as List).length) {
        throw FormatException('Backup record count does not match "$key".');
      }
    }

    final expected = integrityValue['checksum'] as String;
    final actual = _digest(_copyWithoutIntegrity(payload));
    if (expected != actual) {
      throw const FormatException(
        'Backup integrity check failed. The file may be incomplete or modified.',
      );
    }
  }

  static Map<String, dynamic> _copyWithoutIntegrity(
      Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    copy.remove('integrity');
    return copy;
  }

  static String _digest(Map<String, dynamic> payload) =>
      sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}
