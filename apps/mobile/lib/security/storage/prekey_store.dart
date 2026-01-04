// One-time prekey storage
import 'dart:typed_data';

import 'package:isar/isar.dart';

import '../entities/prekey_entity.dart';
import 'vault.dart';

/// ============================================================
/// PreKey Store
/// ============================================================
/// Manages one-time pre-key persistence:
///
/// • Generate and store pre-key batches
/// • Consume pre-keys on use
/// • Track uploaded status
/// • Replenish when low
/// ============================================================
final class PreKeyStore {
  PreKeyStore._();

  /// Default batch size for pre-key generation
  static const int defaultBatchSize = 100;

  /// Threshold for replenishment
  static const int replenishThreshold = 20;

  // ─────────────────────────────────────────────────────────
  // PreKey CRUD
  // ─────────────────────────────────────────────────────────

  /// Get pre-key by ID
  static Future<PreKeyEntity?> getPreKey(int keyId) async {
    return Vault. read((db) async {
      return db.preKeyEntitys
          .filter()
          .keyIdEqualTo(keyId)
          .findFirst();
    });
  }

  /// Save pre-key
  static Future<void> savePreKey({
    required int keyId,
    required Uint8List publicKey,
    required Uint8List privateKey,
  }) async {
    final entity = PreKeyEntity()
      ..keyId = keyId
      ..publicKey = publicKey.toList()
      ..privateKey = privateKey. toList()
      ..uploaded = false
      ..consumed = false
      ..createdAt = DateTime.now().millisecondsSinceEpoch;

    await Vault.write((db) async {
      await db.preKeyEntitys.put(entity);
    });
  }

  /// Save batch of pre-keys
  static Future<void> savePreKeyBatch(List<PreKeyData> preKeys) async {
    final entities = preKeys.map((pk) {
      return PreKeyEntity()
        ..keyId = pk.keyId
        ..publicKey = pk.publicKey. toList()
        ..privateKey = pk.privateKey.toList()
        ..uploaded = false
        ..consumed = false
        ..createdAt = DateTime.now().millisecondsSinceEpoch;
    }).toList();

    await Vault.write((db) async {
      await db.preKeyEntitys.putAll(entities);
    });
  }

  /// Consume pre-key (mark as used and return private key)
  static Future<Uint8List?> consumePreKey(int keyId) async {
    return Vault. write((db) async {
      final entity = await db.preKeyEntitys
          . filter()
          .keyIdEqualTo(keyId)
          .and()
          .consumedEqualTo(false)
          .findFirst();

      if (entity == null) return null;

      // Mark as consumed
      entity.consumed = true;
      entity.consumedAt = DateTime. now().millisecondsSinceEpoch;
      await db.preKeyEntitys.put(entity);

      return Uint8List.fromList(entity.privateKey);
    });
  }

  /// Mark pre-keys as uploaded
  static Future<void> markUploaded(List<int> keyIds) async {
    await Vault.write((db) async {
      for (final keyId in keyIds) {
        final entity = await db.preKeyEntitys
            .filter()
            .keyIdEqualTo(keyId)
            .findFirst();

        if (entity != null) {
          entity. uploaded = true;
          await db.preKeyEntitys.put(entity);
        }
      }
    });
  }

  /// Get available (not consumed) pre-keys
  static Future<List<PreKeyEntity>> getAvailablePreKeys() async {
    return Vault.read((db) async {
      return db.preKeyEntitys
          .filter()
          .consumedEqualTo(false)
          .findAll();
    });
  }

  /// Get pre-keys pending upload
  static Future<List<PreKeyEntity>> getPendingUpload() async {
    return Vault.read((db) async {
      return db. preKeyEntitys
          .filter()
          .uploadedEqualTo(false)
          .and()
          .consumedEqualTo(false)
          .findAll();
    });
  }

  /// Get count of available pre-keys
  static Future<int> getAvailableCount() async {
    return Vault.read((db) async {
      return db.preKeyEntitys
          .filter()
          .consumedEqualTo(false)
          .count();
    });
  }

  /// Check if pre-keys need replenishment
  static Future<bool> needsReplenishment() async {
    final count = await getAvailableCount();
    return count < replenishThreshold;
  }

  /// Get next available key ID
  static Future<int> getNextKeyId() async {
    return Vault.read((db) async {
      final maxKey = await db.preKeyEntitys
          .where()
          .sortByKeyIdDesc()
          .findFirst();

      return (maxKey?.keyId ?? 0) + 1;
    });
  }

  /// Delete consumed pre-keys older than X days
  static Future<int> deleteOldConsumed({int olderThanDays = 30}) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;

    return Vault. write((db) async {
      return db.preKeyEntitys
          .filter()
          .consumedEqualTo(true)
          .and()
          .consumedAtLessThan(cutoff)
          .deleteAll();
    });
  }

  /// Delete all pre-keys
  static Future<void> deleteAll() async {
    await Vault.write((db) async {
      await db.preKeyEntitys.clear();
    });
  }
}

/// Pre-key data for batch operations
class PreKeyData {
  final int keyId;
  final Uint8List publicKey;
  final Uint8List privateKey;

  const PreKeyData({
    required this.keyId,
    required this.publicKey,
    required this. privateKey,
  });
}