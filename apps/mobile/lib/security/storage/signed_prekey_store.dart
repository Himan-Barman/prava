// Signed prekey storage
import 'dart:typed_data';

import 'package:isar/isar.dart';

import '../entities/signed_prekey_entity.dart';
import 'vault.dart';

/// ============================================================
/// Signed PreKey Store
/// ============================================================
/// Manages signed pre-key persistence:
///
/// • Current active signed pre-key
/// • Key rotation (weekly)
/// • Historical keys for pending sessions
/// ============================================================
final class SignedPreKeyStore {
  SignedPreKeyStore._();

  /// Rotation period in days
  static const int rotationPeriodDays = 7;

  /// Maximum age before deletion
  static const int maxAgeDays = 30;

  // ─────────────────────────────────────────────────────────
  // SignedPreKey CRUD
  // ─────────────────────────────────────────────────────────

  /// Get signed pre-key by ID
  static Future<SignedPreKeyEntity? > getSignedPreKey(int keyId) async {
    return Vault.read((db) async {
      return db.signedPreKeyEntitys
          .filter()
          .keyIdEqualTo(keyId)
          .findFirst();
    });
  }

  /// Get current active signed pre-key
  static Future<SignedPreKeyEntity? > getCurrentSignedPreKey() async {
    return Vault. read((db) async {
      return db.signedPreKeyEntitys
          . filter()
          .isActiveEqualTo(true)
          .findFirst();
    });
  }

  /// Save signed pre-key
  static Future<void> saveSignedPreKey({
    required int keyId,
    required Uint8List publicKey,
    required Uint8List privateKey,
    required Uint8List signature,
    bool isActive = true,
  }) async {
    // Deactivate previous active key
    if (isActive) {
      await Vault.write((db) async {
        final current = await db.signedPreKeyEntitys
            . filter()
            .isActiveEqualTo(true)
            .findFirst();

        if (current != null) {
          current.isActive = false;
          await db.signedPreKeyEntitys.put(current);
        }
      });
    }

    final entity = SignedPreKeyEntity()
      ..keyId = keyId
      ..publicKey = publicKey. toList()
      ..privateKey = privateKey.toList()
      ..signature = signature.toList()
      ..isActive = isActive
      ..createdAt = DateTime.now().millisecondsSinceEpoch;

    await Vault.write((db) async {
      await db.signedPreKeyEntitys.put(entity);
    });
  }

  /// Check if current key needs rotation
  static Future<bool> needsRotation() async {
    final current = await getCurrentSignedPreKey();
    if (current == null) return true;

    final age = DateTime.now().millisecondsSinceEpoch - current.createdAt;
    final ageDays = age ~/ (24 * 60 * 60 * 1000);

    return ageDays >= rotationPeriodDays;
  }

  /// Get next key ID
  static Future<int> getNextKeyId() async {
    return Vault.read((db) async {
      final maxKey = await db.signedPreKeyEntitys
          . where()
          .sortByKeyIdDesc()
          .findFirst();

      return (maxKey?.keyId ?? 0) + 1;
    });
  }

  /// Delete old signed pre-keys
  static Future<int> deleteOld() async {
    final cutoff = DateTime. now()
        .subtract(Duration(days: maxAgeDays))
        .millisecondsSinceEpoch;

    return Vault.write((db) async {
      return db.signedPreKeyEntitys
          .filter()
          .isActiveEqualTo(false)
          .and()
          .createdAtLessThan(cutoff)
          .deleteAll();
    });
  }

  /// Get all signed pre-keys
  static Future<List<SignedPreKeyEntity>> getAll() async {
    return Vault. read((db) async {
      return db.signedPreKeyEntitys. where().findAll();
    });
  }

  /// Delete all signed pre-keys
  static Future<void> deleteAll() async {
    await Vault.write((db) async {
      await db.signedPreKeyEntitys.clear();
    });
  }
}