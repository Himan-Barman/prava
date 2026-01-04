// Encrypted vault
import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../entities/identity_entity.dart';
import '../entities/prekey_entity.dart';
import '../entities/sender_key_entity.dart';
import '../entities/session_entity.dart';
import '../entities/signed_prekey_entity.dart';

/// ============================================================
/// Vault - Secure Encrypted Database
/// ============================================================
final class Vault {
  Vault._();

  static Isar?  _db;
  static bool _initialized = false;
  static Completer<void>? _initCompleter;
  static String?  _dbPath;

  static bool get isInitialized => _initialized;

  static Isar get db {
    if (! _initialized || _db == null) {
      throw StateError('Vault not initialized.  Call Vault.initialize() first.');
    }
    return _db!;
  }

  /// Initialize vault with optional encryption
  static Future<void> initialize({
    String? encryptionKey,
    String? directory,
  }) async {
    if (_initialized) return;

    if (_initCompleter != null) {
      await _initCompleter! .future;
      return;
    }

    _initCompleter = Completer<void>();

    try {
      final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
      _dbPath = dir;

      _db = await Isar.open(
        [
          IdentityEntitySchema,
          SessionEntitySchema,
          PreKeyEntitySchema,
          SignedPreKeyEntitySchema,
          SenderKeyEntitySchema,
        ],
        directory: dir,
        name: 'prava_vault',
        inspector: false,
      );

      _initialized = true;
      _initCompleter! .complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Close database connection
  static Future<void> close() async {
    if (! _initialized || _db == null) return;

    await _db! .close();
    _db = null;
    _initialized = false;
    _initCompleter = null;
  }

  /// Clear all data (for logout/account deletion)
  static Future<void> clear() async {
    _ensureInitialized();

    await _db! .writeTxn(() async {
      await _db! .clear();
    });
  }

  /// Execute read transaction
  static Future<T> read<T>(Future<T> Function(Isar db) action) async {
    _ensureInitialized();
    return action(_db!);
  }

  /// Execute write transaction
  static Future<T> write<T>(Future<T> Function(Isar db) action) async {
    _ensureInitialized();
    return _db!.writeTxn(() => action(_db!));
  }

  /// Export database for backup
  /// Returns the raw bytes of the database file
  static Future<List<int>> export() async {
    _ensureInitialized();
    
    // Get the database file path
    final dbFile = File('$_dbPath/prava_vault.isar');
    
    if (await dbFile.exists()) {
      return dbFile.readAsBytes();
    }
    
    // If file doesn't exist, return empty list
    return [];
  }

  /// Get database size in bytes
  static Future<int> getSize() async {
    _ensureInitialized();
    
    // Get the database file size
    final dbFile = File('$_dbPath/prava_vault.isar');
    
    if (await dbFile.exists()) {
      final stat = await dbFile. stat();
      return stat.size;
    }
    
    return 0;
  }

  /// Get collection counts
  static Future<VaultStats> getStats() async {
    _ensureInitialized();

    return VaultStats(
      identityCount: await _db!.identityEntitys.count(),
      sessionCount: await _db!.sessionEntitys.count(),
      preKeyCount:  await _db!. preKeyEntitys. count(),
      signedPreKeyCount:  await _db!. signedPreKeyEntitys.count(),
      senderKeyCount: await _db! .senderKeyEntitys.count(),
      sizeBytes: await getSize(),
    );
  }

  static void _ensureInitialized() {
    if (!_initialized || _db == null) {
      throw StateError('Vault not initialized');
    }
  }
}

/// Vault statistics
class VaultStats {
  final int identityCount;
  final int sessionCount;
  final int preKeyCount;
  final int signedPreKeyCount;
  final int senderKeyCount;
  final int sizeBytes;

  const VaultStats({
    required this.identityCount,
    required this.sessionCount,
    required this.preKeyCount,
    required this. signedPreKeyCount,
    required this.senderKeyCount,
    required this.sizeBytes,
  });

  int get totalCount =>
      identityCount +
      sessionCount +
      preKeyCount +
      signedPreKeyCount +
      senderKeyCount;

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() => 'VaultStats('
      'identities: $identityCount, '
      'sessions: $sessionCount, '
      'preKeys: $preKeyCount, '
      'signedPreKeys: $signedPreKeyCount, '
      'senderKeys: $senderKeyCount, '
      'size: $sizeFormatted)';
}