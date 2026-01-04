// Backup payload
import 'dart:convert';
import 'dart:typed_data';

/// ============================================================
/// Backup Payload
/// ============================================================
/// Complete account state for backup/restore: 
///
/// • Identity keys
/// • All session states
/// • Device information
/// • Pre-key state
///
/// Format:  JSON with version header
/// ============================================================
final class BackupPayload {
  /// Current payload version
  static const int currentVersion = 1;

  final int version;
  final Map<String, dynamic> identity;
  final List<Map<String, dynamic>> sessions;
  final Map<String, dynamic> preKeys;
  final Map<String, dynamic> signedPreKey;
  final List<Map<String, dynamic>> devices;
  final int createdAt;

  const BackupPayload({
    this.version = currentVersion,
    required this.identity,
    required this.sessions,
    required this.preKeys,
    required this.signedPreKey,
    required this.devices,
    required this.createdAt,
  });

  /// Create payload from current state
  factory BackupPayload.create({
    required Map<String, dynamic> identity,
    required List<Map<String, dynamic>> sessions,
    required Map<String, dynamic> preKeys,
    required Map<String, dynamic> signedPreKey,
    required List<Map<String, dynamic>> devices,
  }) {
    return BackupPayload(
      identity: identity,
      sessions: sessions,
      preKeys: preKeys,
      signedPreKey: signedPreKey,
      devices: devices,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'version': version,
        'identity':  identity,
        'sessions': sessions,
        'preKeys':  preKeys,
        'signedPreKey': signedPreKey,
        'devices': devices,
        'createdAt':  createdAt,
      };

  /// Deserialize from JSON
  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int?  ?? 1;

    if (version > currentVersion) {
      throw BackupVersionException(
        'Backup version $version is newer than supported ($currentVersion)',
      );
    }

    return BackupPayload(
      version: version,
      identity:  json['identity'] as Map<String, dynamic>,
      sessions:  (json['sessions'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      preKeys: json['preKeys'] as Map<String, dynamic>,
      signedPreKey: json['signedPreKey'] as Map<String, dynamic>,
      devices: (json['devices'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      createdAt:  json['createdAt'] as int,
    );
  }

  /// Encode to bytes
  Uint8List encode() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  /// Decode from bytes
  factory BackupPayload. decode(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return BackupPayload. fromJson(json);
  }

  /// Get creation date
  DateTime get createdAtDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  /// Session count
  int get sessionCount => sessions.length;

  /// Device count
  int get deviceCount => devices. length;
}

/// Backup version exception
class BackupVersionException implements Exception {
  final String message;

  BackupVersionException(this.message);

  @override
  String toString() => 'BackupVersionException: $message';
}